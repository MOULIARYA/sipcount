import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ai_water/features/calculation_engine/data/aggregate_store.dart';
import 'package:ai_water/features/calculation_engine/domain/model_profile.dart';
import 'package:ai_water/features/calculation_engine/domain/water_estimate.dart';
import 'package:ai_water/features/prompt_listener/data/usage_channel.dart';
import 'package:ai_water/features/tracking/application/tracker.dart';

void main() {
  // Defaults the store no longer invents for itself; the real app passes these from the shared
  // constants, so the test states them rather than relying on hidden literals.
  Future<AggregateStore> openStore() async => AggregateStore.open(
        defaultBudgetMl: 500,
        defaultRegionId: 'us_hyperscale',
        knownRegionIds: const {'us_hyperscale', 'india'},
      );

  const e = WaterEstimate(energyWh: 0.3, scope1Ml: 0.18975, scope2Ml: 1.08399, tokensUsed: 400, confidence: 'medium', constantsVersion: 't');

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('adds into the local calendar-day bucket and round-trips through JSON', () async {
    final s = await openStore();
    final when = DateTime(2026, 9, 14, 23, 30);
    await s.add(when, e, ModelTier.standard, TaskType.text);
    await s.add(when, e, ModelTier.lightweight, TaskType.code);

    final all = AggregateStore(await SharedPreferences.getInstance(),
            defaultBudgetMl: 500, defaultRegionId: 'us_hyperscale',
            knownRegionIds: const {'us_hyperscale'}).readAll();
    final d = all['2026-09-14']!;
    expect(d.promptCount, 2);
    expect(d.totalMl, closeTo(2.54748, 1e-9));
    expect(d.mlByTier['standard'], closeTo(1.27374, 1e-9));
    expect(d.mlByTier['lightweight'], closeTo(1.27374, 1e-9));
    expect(d.mlByTask['code'], closeTo(1.27374, 1e-9));
  });

  test('wipe removes every bucket but keeps the budget preference', () async {
    final s = await openStore();
    await s.setBudgetMl(60);
    await s.add(DateTime.now(), e, ModelTier.standard, TaskType.text);
    await s.wipe();
    expect(s.readAll(), isEmpty);
    expect(s.budgetMl, 60);
  });

  test('a measured answer replaces the assumed one without counting the prompt twice', () async {
    // I-70: the first estimate assumes a reply; when the real one is measured, only the
    // difference is applied — and applying the same correction again changes nothing.
    final s = await openStore();
    final when = DateTime(2026, 10, 19, 10);
    await s.add(when, e, ModelTier.standard, TaskType.text, vendor: 'openai');
    const fresh = WaterEstimate(energyWh: 0.9, scope1Ml: 0.6, scope2Ml: 3.2, tokensUsed: 1200, confidence: 'medium', constantsVersion: 't');
    final key = AggregateStore.dayKey(when);
    await s.adjust(key, e, fresh, ModelTier.standard, TaskType.text, vendor: 'openai');
    var d = s.readAll()[key]!;
    expect(d.promptCount, 1);
    expect(d.totalMl, closeTo(3.8, 1e-9));
    expect(d.mlByVendor['openai'], closeTo(3.8, 1e-9));
    await s.adjust(key, fresh, fresh, ModelTier.standard, TaskType.text, vendor: 'openai');
    d = s.readAll()[key]!;
    expect(d.totalMl, closeTo(3.8, 1e-9));
  });

  test('budget is clamped to a sane range', () async {
    final s = await openStore();
    await s.setBudgetMl(1);
    expect(s.budgetMl, 10);
  });

  test('a fresh install starts on the agreed budget, not one invented here', () async {
    expect((await openStore()).budgetMl, 500);
  });

  test('a region id the constants no longer carry falls back instead of being handed on', () async {
    // The real bug: an install made before the seven-region migration kept its stored id, the
    // constants had no such region, and the first prompt counted threw on the missing entry.
    SharedPreferences.setMockInitialValues({'sipcount.region': 'us_default'});
    expect((await openStore()).regionId, 'us_hyperscale');
  });

  test('a region id the constants do carry is kept', () async {
    SharedPreferences.setMockInitialValues({'sipcount.region': 'india'});
    expect((await openStore()).regionId, 'india');
  });

  // ---- character unlocks (2026-10-19) ------------------------------------------------------
  // Madhur stayed under budget for ~15 days and could not pick the bear. Two faults: unlocks were
  // recomputed from the current streak (so one bad day took them back), and a day with no counted
  // prompts broke the streak. Same rule as the prototype's streakDays(), pinned in regression.js.

  final now = DateTime(2026, 10, 19, 12);
  Map<String, DayTotals> daysFrom(List<(int, int, double)> spec) => {
        for (final (ago, n, ml) in spec)
          AggregateStore.dayKey(now.subtract(Duration(days: ago))): DayTotals()
            ..promptCount = n
            ..scope1Ml = ml
      };

  test('streak: 15 under-budget days with quiet days in between still counts 15', () {
    final spec = [
      for (var i = 1; i <= 17; i++) (i, (i == 5 || i == 10) ? 0 : 3, (i == 5 || i == 10) ? 0.0 : 100.0)
    ];
    expect(Tracker.streakFrom(daysFrom(spec), 500, now), 15);
  });

  test('streak: a day with no record is skipped, not a break', () {
    expect(Tracker.streakFrom(daysFrom([(1, 2, 50.0), (2, 2, 50.0), (6, 2, 50.0)]), 500, now), 3);
  });

  test('streak: an over-budget day still ends it', () {
    expect(Tracker.streakFrom(daysFrom([(1, 2, 50.0), (2, 9, 501.0), (3, 2, 50.0)]), 500, now), 1);
  });

  test('streak: nobody earns a character by not using AI', () {
    expect(Tracker.streakFrom({}, 500, now), 0);
  });

  // ---- estimate mode (I-73) ------------------------------------------------------------------
  const est = SessionEstimate(prompts: 2.5, energyWh: 0.75, scope1Ml: 0.48, scope2Ml: 2.76);

  test('time in an AI app is added as an estimate, apart from measured prompts', () async {
    final s = await openStore();
    await s.addEstimate('2026-10-19', 'google', 300, est);
    final d = s.readAll()['2026-10-19']!;
    expect(d.promptCount, 0);
    expect(d.estimatedPrompts, closeTo(2.5, 1e-9));
    expect(d.estimatedMl, closeTo(3.24, 1e-9));
    expect(d.totalMl, closeTo(3.24, 1e-9));
    expect(d.estSecondsByVendor['google'], 300);
    expect(d.measuredMl, 0);
  });

  test('a measured prompt for that AI on that day replaces its estimate — never both', () async {
    final s = await openStore();
    await s.addEstimate('2026-10-19', 'google', 300, est);
    await s.addEstimate('2026-10-19', 'openai', 120, est);
    await s.add(DateTime(2026, 10, 19, 15), e, ModelTier.standard, TaskType.text, vendor: 'google');
    var d = s.readAll()['2026-10-19']!;
    expect(d.estMlByVendor.containsKey('google'), isFalse);
    expect(d.estMlByVendor['openai'], closeTo(3.24, 1e-9));
    expect(d.estimatedMl, closeTo(3.24, 1e-9)); // the day's estimate split was rebuilt, not left doubled
    expect(d.totalMl, closeTo(3.24 + e.totalMl, 1e-9));
    // and a later estimate for the measured vendor-day is refused
    await s.addEstimate('2026-10-19', 'google', 600, est);
    d = s.readAll()['2026-10-19']!;
    expect(d.estMlByVendor.containsKey('google'), isFalse);
  });

  test('estimates round-trip through JSON', () async {
    final s = await openStore();
    await s.addEstimate('2026-10-18', 'anthropic', 45, est);
    final d = (await openStore()).readAll()['2026-10-18']!;
    expect(d.estPromptsByVendor['anthropic'], closeTo(2.5, 1e-9));
    expect(d.estEnergyWh, closeTo(0.75, 1e-9));
  });

  group('sessions are clipped to the window and split at midnight', () {
    // 23:30 → 00:30 local on the night of 18/19 Oct
    final sessions = [
      UsageSession(vendor: 'openai', start: DateTime(2026, 10, 18, 23, 30), end: DateTime(2026, 10, 19, 0, 30)),
      UsageSession(vendor: 'google', start: DateTime(2026, 10, 19, 9), end: DateTime(2026, 10, 19, 9, 10)),
    ];
    test('a session across midnight is charged to both days by the time in each', () {
      final out = Tracker.secondsByDayAndVendor(sessions, DateTime(2026, 10, 18), DateTime(2026, 10, 19, 12));
      expect(out[('2026-10-18', 'openai')], 1800);
      expect(out[('2026-10-19', 'openai')], 1800);
      expect(out[('2026-10-19', 'google')], 600);
    });
    test('the part before the window is not counted again', () {
      final out = Tracker.secondsByDayAndVendor(sessions, DateTime(2026, 10, 19, 0, 15), DateTime(2026, 10, 19, 12));
      expect(out.containsKey(('2026-10-18', 'openai')), isFalse);
      expect(out[('2026-10-19', 'openai')], 900);
    });
    test('a session still open at the end of the window stops there', () {
      final out = Tracker.secondsByDayAndVendor(sessions, DateTime(2026, 10, 19), DateTime(2026, 10, 19, 9, 4));
      expect(out[('2026-10-19', 'google')], 240);
    });
  });

  test('earned characters and the best streak are stored, so they survive a bad day', () async {
    final s = await openStore();
    expect(s.unlockedIds, ['plant']);
    expect(s.bestStreak, 0);
    await s.setUnlockedIds(['plant', 'bear']);
    await s.setBestStreak(4);
    final again = await openStore();
    expect(again.unlockedIds, ['plant', 'bear']);
    expect(again.bestStreak, 4);
  });
}
