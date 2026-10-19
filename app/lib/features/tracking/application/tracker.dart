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
import '../../prompt_listener/data/usage_channel.dart';
import '../../prompt_listener/domain/prompt_event.dart';

class Tracker extends ChangeNotifier {
  Tracker._(this._constants, this._store, this._channel, this._usage)
      : _tokens = TokenEstimator(charsPerToken: _constants.charsPerToken),
        equivalence = EquivalenceFormatter(_constants.equivalentsMl),
        // the token weights come from the constants file, not from code, so the app and engine.js
        // can never drift apart on how much an output token costs
        _calc = WaterCalculator(weights: _constants.tokenWeights);

  final ConstantsRepository _constants;
  final AggregateStore _store;
  final ListenerChannel _channel;
  final UsageChannel _usage;
  final TokenEstimator _tokens;
  final EquivalenceFormatter equivalence;
  final WaterCalculator _calc;

  StreamSubscription<ListenerMessage>? _sub;

  /// Turns whose answer may still be measured: enough to re-price them, nothing more — no text.
  /// In memory only and dropped after an hour, as the extension's `s.open` is. If the app is killed
  /// between a prompt and its answer, the assumed reply simply stands.
  final Map<String, _OpenTurn> _open = {};
  Map<String, DayTotals> _days = {};
  bool listenerEnabled = false;

  /// Estimate mode (I-73): Usage Access granted, so minutes in each AI app can be read.
  bool usageEnabled = false;
  WaterEstimate? lastEstimate;
  String? lastNudge;

  /// Session-only diagnostics for testing (never persisted).
  String? lastVendor;
  DateTime? lastEventAt;

  static Future<Tracker> start({ListenerChannel? channel, UsageChannel? usage}) async {
    final constants = await ConstantsRepository.load();
    final store = await AggregateStore.open(
      defaultBudgetMl: constants.defaultBudgetMl,
      defaultRegionId: constants.defaultRegionId,
      knownRegionIds: constants.regionIds.toSet(),
    );
    final t = Tracker._(constants, store, channel ?? ListenerChannel(), usage ?? UsageChannel());
    t._days = t._store.readAll();
    await store.setInstalledAtIfUnset(DateTime.now());
    /* THE RULE OF START-UP (I-74): nothing below this line may stop the app from drawing its
       first screen. Build 30 froze on the launch logo because a permission check through a new
       Android channel failed before `runApp` was ever reached. So every optional step is wrapped,
       and anything that talks to Android happens after the screen exists (see main.dart). */
    try {
      for (final m in await t._channel.drainPending()) {
        await t._onMessage(m);
      }
    } catch (e) {
      t.startupNotes.add('pending events: $e');
    }
    try {
      await t.checkUnlocks();
    } catch (e) {
      t.startupNotes.add('unlocks: $e');
    }
    try {
      t._sub = t._channel.events().listen(t._onMessage, onError: (_) {});
    } catch (e) {
      t.startupNotes.add('listener stream: $e');
    }
    return t;
  }

  /// What went wrong during start-up, if anything — shown on the Today screen in a test build
  /// rather than stopping the app. Empty on a healthy start.
  final List<String> startupNotes = [];

  // ---- estimate mode (I-73) ---------------------------------------------------------------

  /// Reads how long each AI app was open since the last read and adds the estimate, day by day
  /// and vendor by vendor. Idempotent: the window starts where the last one ended, sessions are
  /// clipped to it, and a vendor-day that has a measured prompt is left alone (measured wins).
  /// Nothing is stored finer than the calendar day except the one "last read" timestamp.
  Future<void>? _harvesting;

  /// One harvest at a time: the app can be resumed twice in quick succession, and two overlapping
  /// reads of the same window would add the same sessions twice.
  Future<void> harvestUsage() => _harvesting ??= _harvest().whenComplete(() => _harvesting = null);

  Future<void> _harvest() async {
    if (!usageEnabled) return;
    final now = DateTime.now();
    var since = _store.lastUsageHarvest;
    if (since == null || since.isAfter(now)) {
      // first run (or the clock went backwards): look back three days — the system keeps only a
      // few — but never before the day the app was installed, so nobody starts with a streak
      since = now.subtract(const Duration(days: 3));
      final installed = _store.installedAt;
      if (installed != null) {
        final floor = DateTime.parse('${installed}T00:00:00');
        if (floor.isAfter(since)) since = floor;
      }
    }
    if (!now.isAfter(since)) return;
    final sessions = await _usage.sessions(since, now);
    if (sessions == null) return; // the read failed: leave the cursor so the window is read next time
    final seconds = secondsByDayAndVendor(sessions, since, now);
    final estimates = <(String, String), (double, SessionEstimate)>{};
    for (final entry in seconds.entries) {
      estimates[entry.key] = (entry.value, _calc.estimateSession(
        ctx: _context(ModelTier.standard, TaskType.text),
        seconds: entry.value,
        promptsPerMinute: _constants.promptsPerMinute,
        referenceInputTokens: _constants.referenceInputTokens,
        referenceOutputTokens: _constants.referenceOutputTokens,
      ));
    }
    // one write for all of it, then the cursor — so being killed half-way can lose a window
    // but never double one
    await _store.addEstimates(estimates);
    await _store.setLastUsageHarvest(now);
    _days = _store.readAll();
  }

  /// Clips each session to [since, until), splits it at local midnight, and sums seconds per
  /// (day key, vendor). Pure, so a test can pin it. A session that crosses midnight is charged to
  /// both days by the time spent in each.
  static Map<(String, String), double> secondsByDayAndVendor(
      Iterable<UsageSession> sessions, DateTime since, DateTime until) {
    final out = <(String, String), double>{};
    for (final s in sessions) {
      var start = s.start.isBefore(since) ? since : s.start;
      final end = s.end.isAfter(until) ? until : s.end;
      while (start.isBefore(end)) {
        final local = start.toLocal();
        final nextMidnight = DateTime(local.year, local.month, local.day + 1);
        final stop = end.isBefore(nextMidnight) ? end : nextMidnight;
        final key = (AggregateStore.dayKey(start), s.vendor);
        out.update(key, (v) => v + stop.difference(start).inMilliseconds / 1000,
            ifAbsent: () => stop.difference(start).inMilliseconds / 1000);
        start = stop;
      }
    }
    return out;
  }

  Future<void> openUsageSettings() => _usage.openSettings();

  /// Today's number includes an estimate (so the screen says so).
  bool get todayHasEstimate => today.estimatedMl > 0;

  /// Neither sensor is available, so nothing is being counted at all.
  bool get nothingCounts => !listenerEnabled && !usageEnabled;

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

  /// Days *before today* with real use and under budget, counted back until the first day that
  /// reached the budget. Unlocks use this rather than [aliveDays] so nobody earns a character by
  /// not using the app.
  ///
  /// **A day with no counted prompts is skipped — it neither adds nor breaks** (Madhur,
  /// 2026-10-19). It used to break the streak, so a weekend off, a day the listener missed, or a
  /// day Accessibility was switched off for a banking app reset fifteen good days to zero.
  int get streakDays => streakFrom(_days, budgetMl, DateTime.now());

  /// The rule itself, pure so a test can pin it without a phone (same rule as the prototype's
  /// `streakDays()`, pinned there by `regression.js`).
  static int streakFrom(Map<String, DayTotals> days, int budgetMl, DateTime now) {
    var n = 0;
    for (var i = 1; i <= 90; i++) {
      final d = days[AggregateStore.dayKey(now.subtract(Duration(days: i)))];
      // estimated use is real use: half an estimated prompt is about a minute in an AI app
      if (d == null || (d.promptCount == 0 && d.estimatedPrompts < 0.5)) continue;
      if (d.totalMl >= budgetMl) break;
      n++;
    }
    return n;
  }

  /// The best streak ever reached. Unlocks are earned against this, so they are never taken back.
  int get bestStreak => streakDays > _store.bestStreak ? streakDays : _store.bestStreak;

  /// Records any newly earned characters. Called on start and after every counted prompt — the
  /// prototype's `checkUnlocks()`. Returns the ids unlocked by this call.
  Future<List<String>> checkUnlocks() async {
    final best = bestStreak;
    if (best > _store.bestStreak) await _store.setBestStreak(best);
    final have = {..._store.unlockedIds, 'plant'};
    final fresh = [
      for (final c in kCharacters)
        if (c.unlockDays <= best && !have.contains(c.id)) c.id
    ];
    if (fresh.isNotEmpty) await _store.setUnlockedIds([...have, ...fresh]);
    return fresh;
  }

  // ---- age tier ----------------------------------------------------------------------------
  // Only the derived tier is stored, never the number that was typed.

  int? get ageTier => _store.ageTier;

  /// Set by [replayIntro] so the opening can be reviewed without destroying anything. An app
  /// update keeps stored preferences, so once the age is answered the intro never shows again —
  /// which left no way to look at it short of clearing all app data.
  bool _replayIntro = false;

  bool get introSeen => !_replayIntro && _store.ageTier != null;

  /// Test builds only. Shows the opening again; the stored tier is untouched until the age screen
  /// is answered, so nothing is lost by looking.
  void replayIntro() {
    _replayIntro = true;
    notifyListeners();
  }
  bool get canShare => (_store.ageTier ?? 0) >= 13;
  bool get isAdult => (_store.ageTier ?? 0) >= 18;
  int get worstStage => canShare ? 4 : 3;

  Future<void> setAge(int age) async {
    // 13 and 18 are the only thresholds that matter, so they are the only thing kept.
    await _store.setAgeTier(age >= 18 ? 18 : (age >= 13 ? 13 : 12));
    await _store.setInstalledAtIfUnset(DateTime.now());
    _replayIntro = false;
    notifyListeners();
  }

  // ---- the character -----------------------------------------------------------------------

  Character get mascot => characterById(_store.mascotId);
  int get mascotStage => stageOf(todayPct, worstStage: worstStage);

  /// The name you gave it, or what it is called when unnamed.
  String get mascotName => _store.mascotNames[mascot.id] ?? mascot.subject;

  /// Same, but for the state row, where the species reads better than 'Your plant'.
  String get mascotLabel => _store.mascotNames[mascot.id] ?? mascot.label;

  /// Stored unlocks plus anything the best streak already covers, so the list is right even in
  /// the moment before [checkUnlocks] has written it.
  List<String> get unlockedCharacters {
    final have = _store.unlockedIds.toSet();
    final best = bestStreak;
    return [for (final c in kCharacters) if (c.unlockDays == 0 || have.contains(c.id) || c.unlockDays <= best) c.id];
  }

  Character? get nextLockedCharacter {
    final have = unlockedCharacters;
    for (final c in kCharacters) {
      if (!have.contains(c.id)) return c;
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
  bool get _todayHasUse => today.promptCount > 0 || today.estimatedMl > 0;
  String get insightScope => _todayHasUse ? 'today' : 'this week';

  List<DayTotals> get _insightDays => _todayHasUse ? [today] : lastDays(7);

  /// mL per brand over the insight window, heaviest first.
  List<(String, double, int)> get brandBars {
    final ml = <String, double>{};
    final n = <String, int>{};
    for (final d in _insightDays) {
      d.mlByVendor.forEach((k, v) => ml[k] = (ml[k] ?? 0) + v);
      d.promptsByVendor.forEach((k, v) => n[k] = (n[k] ?? 0) + v);
      // estimated use shows in the brand bars too; a vendor-day is never both (I-73)
      d.estMlByVendor.forEach((k, v) => ml[k] = (ml[k] ?? 0) + v);
      d.estPromptsByVendor.forEach((k, v) => n[k] = (n[k] ?? 0) + v.round());
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
    final n = days.fold(0, (a, d) => a + d.promptCount + d.estimatedPrompts.round());
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
    // Plain dart:core only — `firstOrNull` lives in package:collection, which this app does not
    // depend on and is not worth a dependency for one line.
    final byMl = tierMl.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final topTier = byMl.isEmpty ? 'standard' : byMl.first.key;
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

  /// Called on start and whenever the app comes back to the foreground: re-reads both
  /// permissions, pulls in any time spent in AI apps since last time, and re-checks unlocks.
  ///
  /// Every step is guarded on its own: a failing Android call must never take the others, or the
  /// screen, down with it (I-74).
  Future<void> refreshListenerState() async {
    try {
      listenerEnabled = await _channel.isEnabled();
    } catch (e) {
      listenerEnabled = false;
      startupNotes.add('accessibility check: $e');
    }
    try {
      usageEnabled = await _usage.hasPermission();
    } catch (e) {
      usageEnabled = false;
      startupNotes.add('usage access check: $e');
    }
    try {
      await harvestUsage();
    } catch (e) {
      startupNotes.add('usage harvest: $e');
    }
    try {
      await checkUnlocks();
    } catch (e) {
      startupNotes.add('unlocks: $e');
    }
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
    _open.clear(); // an answer arriving after a wipe must not correct a day that no longer exists
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

  Future<void> _onMessage(ListenerMessage m) async {
    if (m is PromptEvent) {
      await _record(m);
    } else if (m is ReplyEvent) {
      await _applyReply(m);
    }
  }

  /// The answer has been measured, so replace the assumed reply with the real one — the same
  /// correction the extension's `handleReply()` makes (I-70). Idempotent: reports arrive
  /// repeatedly as the answer grows, and each applies only the difference from the last.
  Future<void> _applyReply(ReplyEvent r) async {
    final o = _open[r.turnId];
    if (o == null) return; // unknown or expired turn: leave what we have
    final outTokens = _tokens.estimate(r.replyChars);
    final hidden = WaterCalculator.hiddenTokens(
      active: Duration(milliseconds: r.activeMs),
      outputTokens: outTokens,
      tier: o.tier,
      tokensPerSec: _constants.thinkingTokensPerSec,
      floorSec: _constants.thinkingFloorSec,
      maxSec: _constants.thinkingMaxSec,
    );
    final fresh = _calc.estimate(
      ctx: _context(o.tier, o.task),
      inputTokens: o.inputTokens,
      outputTokens: outTokens,
      hidden: hidden,
      contextTokens: o.contextTokens,
      contextPerThousand: _constants.contextPerThousand,
      contextMax: _constants.contextMax,
    );
    await _store.adjust(o.day, o.last, fresh, o.tier, o.task, vendor: o.vendor);
    // the "last counted" line follows the turn it shows, and no other
    if (identical(lastEstimate, o.last)) lastEstimate = fresh;
    o.last = fresh;
    _days = _store.readAll();
    await checkUnlocks();
    notifyListeners();
  }

  Future<void> _record(PromptEvent e) async {
    final tier = _constants.resolveTier(e.vendor, e.modelHint);
    final inputTokens = _tokens.estimate(e.charCount);
    // The conversation the model must re-read, counted the same way at first estimate and at
    // correction (as the extension does), so the number only moves because of the answer.
    final contextTokens = e.turnId == null ? 0 : _tokens.estimate(e.contextChars + e.charCount);
    final est = _calc.estimate(
      ctx: _context(tier, e.task),
      inputTokens: inputTokens,
      itemCount: e.task == TaskType.image ? (e.attachmentCount > 0 ? e.attachmentCount : 1) : 1,
      contextTokens: contextTokens,
      contextPerThousand: _constants.contextPerThousand,
      contextMax: _constants.contextMax,
    );
    // Registered before the first await, so an answer that arrives while the day is being
    // written still finds its turn.
    final id = e.turnId;
    if (id != null && e.task != TaskType.image) {
      final now = DateTime.now();
      _open.removeWhere((_, t) => now.difference(t.at) > const Duration(hours: 1));
      _open[id] = _OpenTurn(
        day: AggregateStore.dayKey(e.timestamp),
        tier: tier,
        task: e.task,
        vendor: e.vendor,
        inputTokens: inputTokens,
        contextTokens: contextTokens,
        last: est,
        at: now,
      );
    }
    await _store.add(e.timestamp, est, tier, e.task, vendor: e.vendor);
    await _countPromptForFacts();
    _days = _store.readAll();
    await checkUnlocks();
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

/// One counted turn whose answer may still arrive. Counts only.
class _OpenTurn {
  _OpenTurn({
    required this.day,
    required this.tier,
    required this.task,
    required this.vendor,
    required this.inputTokens,
    required this.contextTokens,
    required this.last,
    required this.at,
  });

  final String day;
  final ModelTier tier;
  final TaskType task;
  final String vendor;
  final int inputTokens;
  final int contextTokens;
  WaterEstimate last; // what is currently recorded for this turn
  final DateTime at;
}
