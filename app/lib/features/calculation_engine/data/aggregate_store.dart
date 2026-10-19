/// On-device aggregate counters. THE ONLY persisted state in the app.
///
/// Stored shape (JSON in SharedPreferences, key `sipcount.days.v1`):
/// {
///   "2026-09-14": { "n": 3, "s1": 0.57, "s2": 3.25, "wh": 0.9,
///                   "tiers": { "standard": 2.55, "lightweight": 1.27 },
///                   "tasks": { "text": 3.82 },
///                   "est": { "sec": {"google": 600}, "n": {"google": 5}, "ml": {"google": 6.48},
///                            "s1": 0.97, "s2": 5.51, "wh": 1.5 } }      // estimate mode (I-73)
/// }
/// Values are counts, seconds and millilitres. No prompt text, no model names beyond the tier
/// bucket, no timestamps finer than the calendar day — with one exception: the moment the usage
/// history was last read (`sipcount.usage_harvested_ms`), which is about Sipcount's own activity.
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/model_profile.dart';
import '../domain/water_estimate.dart';

class DayTotals {
  DayTotals();
  int promptCount = 0;
  double scope1Ml = 0;
  double scope2Ml = 0;
  double energyWh = 0;
  final Map<String, double> mlByTier = {};
  final Map<String, double> mlByTask = {};

  /// Which AI it was, by millilitres and by count. The insights card cannot say "you leaned on
  /// Claude" without this, and until 2026-10-06 the phone did not keep it at all — which is why
  /// the brand bars could never have been ported.
  final Map<String, double> mlByVendor = {};
  final Map<String, int> promptsByVendor = {};

  /// Estimate mode (I-73): what time spent in each AI app is *estimated* to have cost, kept apart
  /// from what was measured so the screen can say which is which, and so a measured day can
  /// replace an estimated one rather than add to it. Seconds, fractional prompts and millilitres
  /// per vendor — still nothing finer than the calendar day.
  final Map<String, double> estSecondsByVendor = {};
  final Map<String, double> estPromptsByVendor = {};
  final Map<String, double> estMlByVendor = {};
  double estScope1Ml = 0;
  double estScope2Ml = 0;
  double estEnergyWh = 0;

  double get measuredMl => scope1Ml + scope2Ml;
  double get estimatedMl => estScope1Ml + estScope2Ml;
  double get estimatedPrompts => estPromptsByVendor.values.fold(0.0, (a, b) => a + b);

  /// Measured plus estimated: the number on the drop. The eyebrow says when part of it is
  /// an estimate.
  double get totalMl => measuredMl + estimatedMl;

  Map<String, Object> toJson() => {
        'n': promptCount,
        's1': scope1Ml,
        's2': scope2Ml,
        'wh': energyWh,
        'tiers': mlByTier,
        'tasks': mlByTask,
        'vendors': mlByVendor,
        'vendorN': promptsByVendor,
        if (estSecondsByVendor.isNotEmpty) 'est': {
          'sec': estSecondsByVendor,
          'n': estPromptsByVendor,
          'ml': estMlByVendor,
          's1': estScope1Ml,
          's2': estScope2Ml,
          'wh': estEnergyWh,
        },
      };

  static DayTotals fromJson(Map<String, dynamic> j) {
    final d = DayTotals()
      ..promptCount = (j['n'] as num?)?.toInt() ?? 0
      ..scope1Ml = (j['s1'] as num?)?.toDouble() ?? 0
      ..scope2Ml = (j['s2'] as num?)?.toDouble() ?? 0
      ..energyWh = (j['wh'] as num?)?.toDouble() ?? 0;
    (j['tiers'] as Map?)?.forEach((k, v) => d.mlByTier[k as String] = (v as num).toDouble());
    (j['tasks'] as Map?)?.forEach((k, v) => d.mlByTask[k as String] = (v as num).toDouble());
    // Absent on days recorded before 2026-10-06, so the insights card simply has nothing to say
    // about those days rather than guessing a brand.
    (j['vendors'] as Map?)?.forEach((k, v) => d.mlByVendor[k as String] = (v as num).toDouble());
    (j['vendorN'] as Map?)?.forEach((k, v) => d.promptsByVendor[k as String] = (v as num).toInt());
    final est = j['est'] as Map?;
    if (est != null) {
      (est['sec'] as Map?)?.forEach((k, v) => d.estSecondsByVendor[k as String] = (v as num).toDouble());
      (est['n'] as Map?)?.forEach((k, v) => d.estPromptsByVendor[k as String] = (v as num).toDouble());
      (est['ml'] as Map?)?.forEach((k, v) => d.estMlByVendor[k as String] = (v as num).toDouble());
      d.estScope1Ml = (est['s1'] as num?)?.toDouble() ?? 0;
      d.estScope2Ml = (est['s2'] as num?)?.toDouble() ?? 0;
      d.estEnergyWh = (est['wh'] as num?)?.toDouble() ?? 0;
    }
    return d;
  }

  /// Drops one vendor's estimate for this day — called when a measured prompt lands for that
  /// vendor, because measured beats estimated for the same vendor-day (never both).
  void clearEstimate(String vendor) {
    estSecondsByVendor.remove(vendor);
    estPromptsByVendor.remove(vendor);
    final ml = estMlByVendor.remove(vendor);
    if (ml == null) return;
    // the scope split and energy are kept per day, not per vendor: rebuild them from what is left
    final remaining = estMlByVendor.values.fold(0.0, (a, b) => a + b);
    if (estMlByVendor.isEmpty || remaining + ml <= 0) {
      estScope1Ml = 0;
      estScope2Ml = 0;
      estEnergyWh = 0;
    } else {
      final share = remaining / (remaining + ml);
      estScope1Ml *= share;
      estScope2Ml *= share;
      estEnergyWh *= share;
    }
  }
}

class AggregateStore {
  AggregateStore(this._prefs, {
    required this.defaultBudgetMl,
    required this.defaultRegionId,
    required Set<String> knownRegionIds,
  }) : _knownRegionIds = knownRegionIds;

  final SharedPreferences _prefs;

  /// Defaults come from the shared constants, never from literals here. Both values used to be
  /// invented in this file, and both went stale: the budget stayed at 100 mL after we agreed 500,
  /// and the region stayed at `us_default` after that id ceased to exist.
  final int defaultBudgetMl;
  final String defaultRegionId;
  final Set<String> _knownRegionIds;

  static const _daysKey = 'sipcount.days.v1';
  static const _budgetKey = 'sipcount.budget_ml';
  static const _regionKey = 'sipcount.region';
  static const _keepDays = 400; // ~13 months for the annual view; older buckets are dropped.

  static Future<AggregateStore> open({
    required int defaultBudgetMl,
    required String defaultRegionId,
    required Set<String> knownRegionIds,
  }) async =>
      AggregateStore(await SharedPreferences.getInstance(),
          defaultBudgetMl: defaultBudgetMl,
          defaultRegionId: defaultRegionId,
          knownRegionIds: knownRegionIds);

  /// yyyy-mm-dd in the device's local time zone.
  static String dayKey(DateTime t) {
    final l = t.toLocal();
    return '${l.year.toString().padLeft(4, '0')}-${l.month.toString().padLeft(2, '0')}-${l.day.toString().padLeft(2, '0')}';
  }

  Map<String, DayTotals> readAll() {
    final raw = _prefs.getString(_daysKey);
    if (raw == null) return {};
    final j = jsonDecode(raw) as Map<String, dynamic>;
    return j.map((k, v) => MapEntry(k, DayTotals.fromJson(v as Map<String, dynamic>)));
  }

  Future<void> add(DateTime when, WaterEstimate e, ModelTier tier, TaskType task, {String? vendor}) async {
    final all = readAll();
    final key = dayKey(when);
    final d = all.putIfAbsent(key, DayTotals.new);
    d.promptCount += 1;
    d.scope1Ml += e.scope1Ml;
    d.scope2Ml += e.scope2Ml;
    d.energyWh += e.energyWh;
    d.mlByTier.update(tier.name, (v) => v + e.totalMl, ifAbsent: () => e.totalMl);
    d.mlByTask.update(task.name, (v) => v + e.totalMl, ifAbsent: () => e.totalMl);
    if (vendor != null) {
      d.mlByVendor.update(vendor, (v) => v + e.totalMl, ifAbsent: () => e.totalMl);
      d.promptsByVendor.update(vendor, (v) => v + 1, ifAbsent: () => 1);
      d.clearEstimate(vendor); // measured beats estimated for the same vendor-day (I-73)
    }
    await _write(all);
  }

  /// Estimate mode (I-73): adds what [seconds] in [vendor]'s app is estimated to have cost on
  /// [dayKey]. Skipped when that vendor-day already has a measured prompt — measured wins, and
  /// counting both would charge the same chat twice.
  Future<void> addEstimate(String dayKey, String vendor, double seconds, SessionEstimate e) =>
      addEstimates({(dayKey, vendor): (seconds, e)});

  /// Several (day, vendor) estimates in one write, so a harvest is all-or-nothing on disk.
  Future<void> addEstimates(Map<(String, String), (double, SessionEstimate)> batch) async {
    if (batch.isEmpty) return;
    final all = readAll();
    var changed = false;
    for (final entry in batch.entries) {
      final (dayKey, vendor) = entry.key;
      final (seconds, e) = entry.value;
      if (seconds <= 0) continue;
      final d = all.putIfAbsent(dayKey, DayTotals.new);
      if ((d.promptsByVendor[vendor] ?? 0) > 0) continue; // measured wins
      d.estSecondsByVendor.update(vendor, (v) => v + seconds, ifAbsent: () => seconds);
      d.estPromptsByVendor.update(vendor, (v) => v + e.prompts, ifAbsent: () => e.prompts);
      d.estMlByVendor.update(vendor, (v) => v + e.totalMl, ifAbsent: () => e.totalMl);
      d.estScope1Ml += e.scope1Ml;
      d.estScope2Ml += e.scope2Ml;
      d.estEnergyWh += e.energyWh;
      changed = true;
    }
    if (changed) await _write(all);
  }

  // ---- estimate-mode bookkeeping ---------------------------------------------------------
  // One timestamp: when the usage history was last read, so the next read starts there and
  // nothing is counted twice. It is about Sipcount's own activity, not the user's.

  static const _harvestKey = 'sipcount.usage_harvested_ms';
  DateTime? get lastUsageHarvest {
    final ms = _prefs.getInt(_harvestKey);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }
  Future<void> setLastUsageHarvest(DateTime t) => _prefs.setInt(_harvestKey, t.millisecondsSinceEpoch);

  /// Replaces one turn's first estimate with a better one, on the day it was counted: adds
  /// `fresh − before` everywhere and leaves the prompt count alone (the turn is already counted).
  /// Used when the measured answer replaces the assumed one (I-70) — the extension's
  /// `handleReply()` does exactly this.
  Future<void> adjust(String dayKey, WaterEstimate before, WaterEstimate fresh, ModelTier tier, TaskType task,
      {String? vendor}) async {
    final all = readAll();
    final d = all[dayKey];
    if (d == null) return; // the day was wiped in between: nothing to correct
    final dMl = fresh.totalMl - before.totalMl;
    d.scope1Ml += fresh.scope1Ml - before.scope1Ml;
    d.scope2Ml += fresh.scope2Ml - before.scope2Ml;
    d.energyWh += fresh.energyWh - before.energyWh;
    d.mlByTier.update(tier.name, (v) => v + dMl, ifAbsent: () => dMl);
    d.mlByTask.update(task.name, (v) => v + dMl, ifAbsent: () => dMl);
    if (vendor != null) d.mlByVendor.update(vendor, (v) => v + dMl, ifAbsent: () => dMl);
    await _write(all);
  }

  Future<void> wipe() async {
    await _prefs.remove(_daysKey);
  }

  int get budgetMl => _prefs.getInt(_budgetKey) ?? defaultBudgetMl;
  Future<void> setBudgetMl(int v) => _prefs.setInt(_budgetKey, v.clamp(10, 100000).toInt());

  /// A stored id that the constants no longer carry is treated as absent. The prototype's store has
  /// always done this (`if(!C.regions[s.region]) s.region=defaults.region`); this side had not, so a
  /// region that was renamed under an existing install became a crash rather than a fallback.
  // ---- small preferences ------------------------------------------------------------------
  // Still only counts and choices: which character you picked, what you named it, which cards
  // you have dismissed, and which facts have already been shown today. No prompt content, no
  // times finer than the calendar day.

  static const _mascotKey = 'sipcount.mascot';
  static const _namesKey = 'sipcount.names';
  static const _watchKey = 'sipcount.watch_seen';
  static const _widgetKey = 'sipcount.widget_seen';
  static const _installedKey = 'sipcount.installed_at';
  static const _ageKey = 'sipcount.age_tier';
  static const _factsKey = 'sipcount.facts';

  static const _unlockedKey = 'sipcount.unlocked';
  static const _bestStreakKey = 'sipcount.best_streak';

  /// Characters earned so far. Kept, not recomputed: until 2026-10-19 the phone derived unlocks
  /// from the *current* streak, so one bad day took back every character already earned. The
  /// prototype has always stored them (`S.unlocked`), and so does this now.
  List<String> get unlockedIds => _prefs.getStringList(_unlockedKey) ?? const ['plant'];
  Future<void> setUnlockedIds(List<String> ids) => _prefs.setStringList(_unlockedKey, ids);

  /// The longest unlock streak ever reached (the prototype's `S.bestStreak`).
  int get bestStreak => _prefs.getInt(_bestStreakKey) ?? 0;
  Future<void> setBestStreak(int v) => _prefs.setInt(_bestStreakKey, v);

  String get mascotId => _prefs.getString(_mascotKey) ?? 'plant';
  Future<void> setMascotId(String v) => _prefs.setString(_mascotKey, v);

  Map<String, String> get mascotNames {
    final raw = _prefs.getString(_namesKey);
    if (raw == null) return {};
    try {
      return Map<String, String>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return {};
    }
  }

  Future<void> setMascotName(String id, String name) async {
    final all = mascotNames;
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      all.remove(id);
    } else {
      all[id] = trimmed.length > 16 ? trimmed.substring(0, 16) : trimmed;
    }
    await _prefs.setString(_namesKey, jsonEncode(all));
  }

  bool get watchSeen => _prefs.getBool(_watchKey) ?? false;
  Future<void> setWatchSeen() => _prefs.setBool(_watchKey, true);

  bool get widgetSeen => _prefs.getBool(_widgetKey) ?? false;
  Future<void> setWidgetSeen() => _prefs.setBool(_widgetKey, true);

  /// The day the app first ran, so "Tracking since" and the alive-day count have a floor. Set
  /// once; a reinstall legitimately starts again because nothing left the device.
  String? get installedAt => _prefs.getString(_installedKey);
  Future<void> setInstalledAtIfUnset(DateTime t) async {
    if (_prefs.getString(_installedKey) == null) await _prefs.setString(_installedKey, dayKey(t));
  }

  /// The derived tier only — never the age that was typed. 13 gates sharing and the worst
  /// character stage; 18 gates sync.
  int? get ageTier => _prefs.getInt(_ageKey);
  Future<void> setAgeTier(int v) => _prefs.setInt(_ageKey, v);

  /// `{dayKey: {"shown": [indices], "prompts": n}}`, kept for today only.
  Map<String, dynamic> factState(String day) {
    try {
      final all = jsonDecode(_prefs.getString(_factsKey) ?? '{}') as Map<String, dynamic>;
      return (all[day] as Map<String, dynamic>?) ?? {'shown': <int>[], 'prompts': 0};
    } catch (_) {
      return {'shown': <int>[], 'prompts': 0};
    }
  }

  Future<void> setFactState(String day, Map<String, dynamic> v) async {
    // only today is kept: yesterday's fact history is of no use to anyone
    await _prefs.setString(_factsKey, jsonEncode({day: v}));
  }

  String get regionId {
    final stored = _prefs.getString(_regionKey);
    return (stored != null && _knownRegionIds.contains(stored)) ? stored : defaultRegionId;
  }
  Future<void> setRegionId(String v) => _prefs.setString(_regionKey, v);

  Future<void> _write(Map<String, DayTotals> all) async {
    final keys = all.keys.toList()..sort();
    if (keys.length > _keepDays) {
      for (final k in keys.take(keys.length - _keepDays)) {
        all.remove(k);
      }
    }
    await _prefs.setString(_daysKey, jsonEncode(all.map((k, v) => MapEntry(k, v.toJson()))));
  }
}
