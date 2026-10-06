/// On-device aggregate counters. THE ONLY persisted state in the app.
///
/// Stored shape (JSON in SharedPreferences, key `sipcount.days.v1`):
/// {
///   "2026-09-14": { "n": 3, "s1": 0.57, "s2": 3.25, "wh": 0.9,
///                   "tiers": { "standard": 2.55, "lightweight": 1.27 },
///                   "tasks": { "text": 3.82 } }
/// }
/// Values are counts and millilitres. No prompt text, no model names beyond
/// the tier bucket, no timestamps finer than the calendar day.
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

  double get totalMl => scope1Ml + scope2Ml;

  Map<String, Object> toJson() => {
        'n': promptCount,
        's1': scope1Ml,
        's2': scope2Ml,
        'wh': energyWh,
        'tiers': mlByTier,
        'tasks': mlByTask,
      };

  static DayTotals fromJson(Map<String, dynamic> j) {
    final d = DayTotals()
      ..promptCount = (j['n'] as num?)?.toInt() ?? 0
      ..scope1Ml = (j['s1'] as num?)?.toDouble() ?? 0
      ..scope2Ml = (j['s2'] as num?)?.toDouble() ?? 0
      ..energyWh = (j['wh'] as num?)?.toDouble() ?? 0;
    (j['tiers'] as Map?)?.forEach((k, v) => d.mlByTier[k as String] = (v as num).toDouble());
    (j['tasks'] as Map?)?.forEach((k, v) => d.mlByTask[k as String] = (v as num).toDouble());
    return d;
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

  Future<void> add(DateTime when, WaterEstimate e, ModelTier tier, TaskType task) async {
    final all = readAll();
    final key = dayKey(when);
    final d = all.putIfAbsent(key, DayTotals.new);
    d.promptCount += 1;
    d.scope1Ml += e.scope1Ml;
    d.scope2Ml += e.scope2Ml;
    d.energyWh += e.energyWh;
    d.mlByTier.update(tier.name, (v) => v + e.totalMl, ifAbsent: () => e.totalMl);
    d.mlByTask.update(task.name, (v) => v + e.totalMl, ifAbsent: () => e.totalMl);
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
