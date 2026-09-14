/// Wires listener → engine → counters. One instance for the app lifetime.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../calculation_engine/data/aggregate_store.dart';
import '../../calculation_engine/data/constants_repository.dart';
import '../../calculation_engine/domain/equivalence_formatter.dart';
import '../../calculation_engine/domain/model_profile.dart';
import '../../calculation_engine/domain/token_estimator.dart';
import '../../calculation_engine/domain/water_calculator.dart';
import '../../calculation_engine/domain/water_estimate.dart';
import '../../prompt_listener/data/listener_channel.dart';
import '../../prompt_listener/domain/prompt_event.dart';

class Tracker extends ChangeNotifier {
  Tracker._(this._constants, this._store, this._channel)
      : _tokens = TokenEstimator(charsPerToken: _constants.charsPerToken),
        equivalence = EquivalenceFormatter(_constants.equivalentsMl);

  final ConstantsRepository _constants;
  final AggregateStore _store;
  final ListenerChannel _channel;
  final TokenEstimator _tokens;
  final EquivalenceFormatter equivalence;
  static const _calc = WaterCalculator();

  StreamSubscription<PromptEvent>? _sub;
  Map<String, DayTotals> _days = {};
  bool listenerEnabled = false;
  WaterEstimate? lastEstimate;
  String? lastNudge;

  /// Session-only diagnostics for testing (never persisted).
  String? lastVendor;
  DateTime? lastEventAt;

  static Future<Tracker> start({ListenerChannel? channel}) async {
    final t = Tracker._(await ConstantsRepository.load(), await AggregateStore.open(), channel ?? ListenerChannel());
    t._days = t._store.readAll();
    await t.refreshListenerState();
    for (final e in await t._channel.drainPending()) {
      await t._record(e);
    }
    t._sub = t._channel.events().listen(t._record, onError: (_) {});
    return t;
  }

  // ---- read side -----------------------------------------------------------

  String get constantsVersion => _constants.constantsVersion;
  int get budgetMl => _store.budgetMl;
  String get regionId => _store.regionId;
  List<String> get selectableRegions => const ['us_default', 'colo_average'];

  DayTotals get today => _days[AggregateStore.dayKey(DateTime.now())] ?? DayTotals();

  /// Last [n] days, oldest first, including today.
  List<DayTotals> lastDays(int n) {
    final now = DateTime.now();
    return List.generate(n, (i) {
      final d = now.subtract(Duration(days: n - 1 - i));
      return _days[AggregateStore.dayKey(d)] ?? DayTotals();
    });
  }

  double sumMl(int days) => lastDays(days).fold(0, (a, d) => a + d.totalMl);
  int sumPrompts(int days) => lastDays(days).fold(0, (a, d) => a + d.promptCount);

  /// What a standard-tier prompt of [inputChars] would have cost on the lightweight tier — for the nudge.
  double lightweightSavingsMl(int inputChars) => _calc.savingsIfSwitched(
        current: _context(ModelTier.standard, TaskType.text),
        alternative: _constants.tier(ModelTier.lightweight),
        inputTokens: _tokens.estimate(inputChars),
      );

  // ---- write side ----------------------------------------------------------

  Future<void> refreshListenerState() async {
    listenerEnabled = await _channel.isEnabled();
    notifyListeners();
  }

  Future<void> openEnableSettings() => _channel.openEnableSettings();

  Future<void> setBudgetMl(int v) async {
    await _store.setBudgetMl(v);
    notifyListeners();
  }

  Future<void> setRegionId(String v) async {
    await _store.setRegionId(v);
    notifyListeners();
  }

  Future<void> wipe() async {
    await _store.wipe();
    _days = {};
    lastEstimate = null;
    lastNudge = null;
    notifyListeners();
  }

  /// Demo hook: behaves exactly like an event from the listener.
  Future<void> simulate({String vendor = 'openai', String? modelHint, TaskType task = TaskType.text, int charCount = 400}) =>
      _record(PromptEvent(
        source: ListenerSource.androidA11y,
        vendor: vendor,
        modelHint: modelHint,
        task: task,
        charCount: charCount,
        attachmentCount: 0,
        timestamp: DateTime.now().toUtc(),
      ));

  Future<void> _record(PromptEvent e) async {
    final tier = _constants.resolveTier(e.vendor, e.modelHint);
    final est = _calc.estimate(
      ctx: _context(tier, e.task),
      inputTokens: _tokens.estimate(e.charCount),
      itemCount: e.task == TaskType.image ? (e.attachmentCount > 0 ? e.attachmentCount : 1) : 1,
    );
    await _store.add(e.timestamp, est, tier, e.task);
    _days = _store.readAll();
    lastEstimate = est;
    lastNudge = _nudgeFor(tier, e);
    lastVendor = switch (e.vendor) { 'openai' => 'ChatGPT', 'anthropic' => 'Claude', 'google' => 'Gemini', _ => e.vendor };
    lastEventAt = DateTime.now();
    notifyListeners();
  }

  String? _nudgeFor(ModelTier tier, PromptEvent e) {
    if (tier == ModelTier.reasoning) return 'That was a reasoning model — roughly 10× the water of a standard one. Save it for hard problems.';
    if (tier == ModelTier.standard && e.charCount < 200 && e.task == TaskType.text) {
      final s = lightweightSavingsMl(e.charCount);
      return 'Short question? A lighter model would have used about ${s.toStringAsFixed(1)} mL less.';
    }
    if (today.totalMl > budgetMl) return "You're over today's budget. Batch your questions or switch to a lighter model.";
    return null;
  }

  CalculationContext _context(ModelTier tier, TaskType task) => CalculationContext(
        tier: _constants.tier(tier),
        task: _constants.task(task),
        region: _constants.region(_store.regionId),
        constantsVersion: _constants.constantsVersion,
      );

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
