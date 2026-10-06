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
import '../../calculation_engine/domain/plain_words.dart';
import '../../calculation_engine/domain/water_estimate.dart';
import '../domain/character.dart';
import '../../prompt_listener/data/listener_channel.dart';
import '../../prompt_listener/domain/prompt_event.dart';

class Tracker extends ChangeNotifier {
  Tracker._(this._constants, this._store, this._channel)
      : _tokens = TokenEstimator(charsPerToken: _constants.charsPerToken),
        equivalence = EquivalenceFormatter(_constants.equivalentsMl),
        // the token weights come from the constants file, not from code, so the app and engine.js
        // can never drift apart on how much an output token costs
        _calc = WaterCalculator(weights: _constants.tokenWeights);

  final ConstantsRepository _constants;
  final AggregateStore _store;
  final ListenerChannel _channel;
  final TokenEstimator _tokens;
  final EquivalenceFormatter equivalence;
  final WaterCalculator _calc;

  StreamSubscription<PromptEvent>? _sub;
  Map<String, DayTotals> _days = {};
  bool listenerEnabled = false;
  WaterEstimate? lastEstimate;
  String? lastNudge;

  /// Session-only diagnostics for testing (never persisted).
  String? lastVendor;
  DateTime? lastEventAt;

  static Future<Tracker> start({ListenerChannel? channel}) async {
    final constants = await ConstantsRepository.load();
    final store = await AggregateStore.open(
      defaultBudgetMl: constants.defaultBudgetMl,
      defaultRegionId: constants.defaultRegionId,
      knownRegionIds: constants.regionIds.toSet(),
    );
    final t = Tracker._(constants, store, channel ?? ListenerChannel());
    t._days = t._store.readAll();
    await store.setInstalledAtIfUnset(DateTime.now());
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
  /// From the constants, not a literal. The hard-coded pair that used to live here outlived the
  /// seven-region migration by three weeks and would have offered the user two regions that no
  /// longer exist. A test now rejects any region id written literally in this file.
  List<String> get selectableRegions => _constants.regionIds;

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

  // ---- the dashboard's read side ------------------------------------------------------------

  ConstantsRepository get constants => _constants;

  /// Today as a fraction of the budget. Uncapped: 143% is a true thing to say.
  double get todayPct => budgetMl <= 0 ? 0 : today.totalMl / budgetMl;

  String get zone => _constants.zoneOf(todayPct);
  ZoneLook get zoneLook => _constants.zoneUi[zone]!;

  /// Every day ever recorded, summed. Not just the 7-day window.
  double get allTimeMl => _days.values.fold(0.0, (a, d) => a + d.totalMl);

  DateTime get trackingSince {
    final stored = _store.installedAt;
    final keys = _days.keys.toList()..sort();
    final first = stored ?? (keys.isNotEmpty ? keys.first : null);
    return first != null ? DateTime.parse('${first}T12:00:00') : DateTime.now();
  }

  /// Consecutive days ending today where the total never reached the budget. A day with no AI use
  /// counts as survived — the character is a pet, not a scoreboard.
  int get aliveDays {
    var n = 0;
    final floor = _store.installedAt;
    for (var i = 0; i < 180; i++) {
      final key = AggregateStore.dayKey(DateTime.now().subtract(Duration(days: i)));
      final d = _days[key];
      if (d != null && d.totalMl >= budgetMl) break;
      n++;
      if (floor != null && key == floor) break;
    }
    return n;
  }

  /// Consecutive days *before today* with real use and under budget. Unlocks use this rather than
  /// [aliveDays] so nobody earns a character by not using the app.
  int get streakDays {
    var n = 0;
    for (var i = 1; i <= 90; i++) {
      final d = _days[AggregateStore.dayKey(DateTime.now().subtract(Duration(days: i)))];
      if (d == null || d.promptCount == 0 || d.totalMl >= budgetMl) break;
      n++;
    }
    return n;
  }

  // ---- age tier ----------------------------------------------------------------------------
  // Only the derived tier is stored, never the number that was typed.

  int? get ageTier => _store.ageTier;
  bool get introSeen => _store.ageTier != null;
  bool get canShare => (_store.ageTier ?? 0) >= 13;
  bool get isAdult => (_store.ageTier ?? 0) >= 18;
  int get worstStage => canShare ? 4 : 3;

  Future<void> setAge(int age) async {
    // 13 and 18 are the only thresholds that matter, so they are the only thing kept.
    await _store.setAgeTier(age >= 18 ? 18 : (age >= 13 ? 13 : 12));
    await _store.setInstalledAtIfUnset(DateTime.now());
    notifyListeners();
  }

  // ---- the character -----------------------------------------------------------------------

  Character get mascot => characterById(_store.mascotId);
  int get mascotStage => stageOf(todayPct, worstStage: worstStage);

  /// The name you gave it, or what it is called when unnamed.
  String get mascotName => _store.mascotNames[mascot.id] ?? mascot.subject;

  /// Same, but for the state row, where the species reads better than 'Your plant'.
  String get mascotLabel => _store.mascotNames[mascot.id] ?? mascot.label;

  List<String> get unlockedCharacters =>
      [for (final c in kCharacters) if (c.unlockDays <= streakDays) c.id];

  Character? get nextLockedCharacter {
    for (final c in kCharacters) {
      if (c.unlockDays > streakDays) return c;
    }
    return null;
  }

  Future<void> setMascot(String id) async {
    await _store.setMascotId(id);
    notifyListeners();
  }

  Future<void> nameMascot(String name) async {
    await _store.setMascotName(mascot.id, name);
    notifyListeners();
  }

  // ---- cards you can dismiss ----------------------------------------------------------------

  bool get showWatchCard => !_store.watchSeen;
  bool get showWidgetCard => _store.watchSeen && !_store.widgetSeen;
  Future<void> dismissWatchCard() async { await _store.setWatchSeen(); notifyListeners(); }
  Future<void> dismissWidgetCard() async { await _store.setWidgetSeen(); notifyListeners(); }

  // ---- insights ----------------------------------------------------------------------------

  /// Today if today has prompts, otherwise the week — so the card is never blank on a quiet
  /// morning when there is a whole week to talk about.
  String get insightScope => today.promptCount > 0 ? 'today' : 'this week';

  List<DayTotals> get _insightDays => today.promptCount > 0 ? [today] : lastDays(7);

  /// mL per brand over the insight window, heaviest first.
  List<(String, double, int)> get brandBars {
    final ml = <String, double>{};
    final n = <String, int>{};
    for (final d in _insightDays) {
      d.mlByVendor.forEach((k, v) => ml[k] = (ml[k] ?? 0) + v);
      d.promptsByVendor.forEach((k, v) => n[k] = (n[k] ?? 0) + v);
    }
    final rows = [
      for (final e in ml.entries)
        (_constants.brands[e.key] ?? e.key, e.value, n[e.key] ?? 0)
    ]..sort((a, b) => b.$2.compareTo(a.$2));
    return rows;
  }

  /// The sentences on the insights card. Plain text — the prototype bolds parts of these, and the
  /// widget does the emphasis instead of embedding markup here.
  List<String> get insightLines {
    final days = _insightDays;
    final n = days.fold(0, (a, d) => a + d.promptCount);
    final ml = days.fold(0.0, (a, d) => a + d.totalMl);
    if (n == 0) return const ['Log a prompt and the insights appear here.'];
    if (ml <= 0) return const ['Nothing measurable yet — those prompts were too short to register.'];
    final bars = brandBars;
    if (bars.isEmpty) {
      return const ['Older data has no brand breakdown yet — new prompts will show which AI you used.'];
    }

    final out = <String>[];
    final top = bars.first;
    // the heaviest tier within the window, as a plain word
    final tierMl = <String, double>{};
    for (final d in days) {
      d.mlByTier.forEach((k, v) => tierMl[k] = (tierMl[k] ?? 0) + v);
    }
    final topTier = (tierMl.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
        .firstOrNull?.key ?? 'standard';
    final tierWord = _constants.tier(ModelTier.values.firstWhere((t) => t.name == topTier,
        orElse: () => ModelTier.standard)).label.toLowerCase();
    out.add('You leaned on ${top.$1} $insightScope — mostly its $tierWord model '
        '(${fmt(top.$2)} mL, ${(top.$2 / ml * 100).round()}% of your water).');

    if ((tierMl['reasoning'] ?? 0) > 0) {
      final light = days.fold(0.0, (a, d) => a + (d.mlByTier['lightweight'] ?? 0));
      if (light / ml < 0.5) {
        out.add('Most prompts hit a reasoning model (≈10× the water). Try a standard model first.');
      }
    }
    if (mascotStage == 0) out.add('Your ${mascot.label.toLowerCase()} holds steady.');
    return out;
  }

  // ---- the Simulate screen -------------------------------------------------------------------
  // A what-if only. Nothing here writes to a day total: there is no path from this screen to the
  // one number the app exists to keep honest.

  /// One estimate from the controls on the Simulate screen. [effortSeconds] is the plain-language
  /// effort choice — how long the model worked before the answer appeared — which becomes unseen
  /// tokens through the same rule the extension uses.
  WaterEstimate estimateFor({
    required ModelTier tier,
    required TaskType task,
    required int inputChars,
    required int outputTokens,
    required int effortSeconds,
  }) {
    final inTokens = _tokens.estimate(inputChars);
    // The answer itself takes time to write; the effort choice is added on top of it.
    final activeMs = (effortSeconds +
            outputTokens / _constants.thinkingTokensPerSec +
            _constants.thinkingFloorSec) *
        1000;
    final hidden = WaterCalculator.hiddenTokens(
      active: Duration(milliseconds: activeMs.round()),
      outputTokens: outputTokens,
      tier: tier,
      tokensPerSec: _constants.thinkingTokensPerSec,
      floorSec: _constants.thinkingFloorSec,
      maxSec: _constants.thinkingMaxSec,
    );
    return _calc.estimate(
      ctx: _context(tier, task),
      inputTokens: inTokens,
      outputTokens: task == TaskType.image ? null : outputTokens,
      hidden: hidden,
      contextTokens: inTokens,
      contextPerThousand: _constants.contextPerThousand,
      contextMax: _constants.contextMax,
    );
  }

  /// The single line of advice under the estimate. Order matters, and the rule that matters most
  /// is the second one: a turn that spent its effort off-screen was researching, and a lighter
  /// model could not have done it — so offering one would be bad advice.
  String simulateNudge(WaterEstimate e, ModelTier tier, TaskType task) {
    if (task == TaskType.image) {
      final reference = _calc.estimate(
        ctx: _context(ModelTier.standard, TaskType.text),
        inputTokens: 100,
        outputTokens: 300,
      );
      final n = reference.totalMl <= 0 ? 0 : (e.totalMl / reference.totalMl).round();
      return '🖼️ One picture ≈ $n ordinary questions.';
    }
    if (e.hiddenTokens > e.outputTokens) {
      final times = (e.hiddenTokens / (e.outputTokens <= 0 ? 1 : e.outputTokens)).round();
      return '🔎 Most of that is work you never see — searching, reading, writing files. '
          'Roughly ${times < 2 ? 2 : times}× as much as the answer in front of you.';
    }
    final alt = switch (tier) {
      ModelTier.reasoning => ModelTier.standard,
      ModelTier.standard => ModelTier.lightweight,
      ModelTier.lightweight => null,
    };
    final halve = e.totalMl * (1 - e.inputShare) / 2;
    if (alt == null) {
      return '✅ Lightest model already. Half the answer still saves '
          '${fmt(halve, halve < 10 ? 2 : 1)} mL.';
    }
    final altEst = _calc.estimate(
      ctx: _context(alt, task),
      inputTokens: e.inputTokens,
      outputTokens: e.outputTokens,
      hidden: e.hiddenTokens,
    );
    final saves = e.totalMl - altEst.totalMl;
    return '🔁 A ${_constants.tier(alt).label.toLowerCase()} model saves '
        '${fmt(saves, saves < 10 ? 2 : 1)} mL. Half the answer saves '
        '${fmt(halve, halve < 10 ? 2 : 1)} mL.';
  }

  // ---- facts -------------------------------------------------------------------------------

  /// One fact waits at a time, at most twice a day, and never when the app opens. Returns the
  /// fact to show, or null — the caller is the UI, so nothing is shown while a card is up.
  WaterFact? takeFactIfDue() {
    final day = AggregateStore.dayKey(DateTime.now());
    final st = _store.factState(day);
    final shown = List<int>.from((st['shown'] as List?) ?? const []);
    final prompts = (st['prompts'] as int?) ?? 0;
    if (shown.length >= _constants.factMaxPerDay) return null;
    if (prompts == 0 || prompts % _constants.factEveryPrompts != 0) return null;
    final facts = _constants.facts;
    final pool = [for (var i = 0; i < facts.length; i++) if (!shown.contains(i)) i];
    if (pool.isEmpty) return null;
    final pick = pool[DateTime.now().millisecondsSinceEpoch % pool.length];
    shown.add(pick);
    _store.setFactState(day, {'shown': shown, 'prompts': prompts});
    return facts[pick];
  }

  Future<void> _countPromptForFacts() async {
    final day = AggregateStore.dayKey(DateTime.now());
    final st = _store.factState(day);
    await _store.setFactState(day, {
      'shown': List<int>.from((st['shown'] as List?) ?? const []),
      'prompts': ((st['prompts'] as int?) ?? 0) + 1,
    });
  }

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
    await _store.add(e.timestamp, est, tier, e.task, vendor: e.vendor);
    await _countPromptForFacts();
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
