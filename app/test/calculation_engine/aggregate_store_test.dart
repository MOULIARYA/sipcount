import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ai_water/features/calculation_engine/data/aggregate_store.dart';
import 'package:ai_water/features/calculation_engine/domain/model_profile.dart';
import 'package:ai_water/features/calculation_engine/domain/water_estimate.dart';

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
}
