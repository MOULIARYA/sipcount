import 'package:flutter_test/flutter_test.dart';
import 'package:ai_water/features/calculation_engine/domain/model_profile.dart';
import 'package:ai_water/features/calculation_engine/domain/token_estimator.dart';
import 'package:ai_water/features/calculation_engine/domain/water_calculator.dart';

// Golden values computed independently (IEEE-754 double) on 2026-09-14 from constants v2026-09-14.
// Formula: total_mL = E_Wh × PUE × (WUE_site + WUE_grid); US: PUE 1.15, site 0.55, grid 3.142.

const us = RegionProfile(id: 'us_default', pue: 1.15, wueSiteLPerKwh: 0.55, wueGridLPerKwh: 3.142, confidence: 'medium');
const standard = TierProfile(tier: ModelTier.standard, energyWhPer1kTokens: 0.75, confidence: 'medium');
const reasoning = TierProfile(tier: ModelTier.reasoning, energyWhPer1kTokens: 7.5, confidence: 'low');
const lightweight = TierProfile(tier: ModelTier.lightweight, energyWhPer1kTokens: 0.15, confidence: 'low');
const text = TaskProfile(type: TaskType.text, defaultOutputTokens: 300);
const code = TaskProfile(type: TaskType.code, defaultOutputTokens: 600);
const image = TaskProfile(type: TaskType.image, fixedEnergyWhPerItem: 2.9);

CalculationContext ctx(TierProfile t, TaskProfile k, [RegionProfile r = us]) =>
    CalculationContext(tier: t, task: k, region: r, constantsVersion: '2026-09-14');

void main() {
  const calc = WaterCalculator();
  const eps = 1e-9;

  test('standard text prompt, 100 input tokens → 0.30 Wh, 1.27374 mL', () {
    final e = calc.estimate(ctx: ctx(standard, text), inputTokens: 100);
    expect(e.tokensUsed, 400);
    expect(e.energyWh, closeTo(0.3, eps));
    expect(e.scope1Ml, closeTo(0.18975, eps));
    expect(e.scope2Ml, closeTo(1.08399, eps));
    expect(e.totalMl, closeTo(1.27374, eps));
    expect(e.confidence, 'medium');
  });

  test('reasoning tier is 10× standard → 12.7374 mL, confidence degrades to low', () {
    final e = calc.estimate(ctx: ctx(reasoning, text), inputTokens: 100);
    expect(e.energyWh, closeTo(3.0, eps));
    expect(e.totalMl, closeTo(12.7374, eps));
    expect(e.confidence, 'low');
  });

  test('image generation is fixed energy → 2.9 Wh, 12.31282 mL, tokens ignored', () {
    final e = calc.estimate(ctx: ctx(standard, image), inputTokens: 5000);
    expect(e.tokensUsed, 0);
    expect(e.scope1Ml, closeTo(1.83425, eps));
    expect(e.scope2Ml, closeTo(10.47857, eps));
    expect(e.totalMl, closeTo(12.31282, eps));
  });

  test('code task uses 600 default output tokens → 850 tokens, 2.7066975 mL', () {
    final tokens = const TokenEstimator().estimate(1000); // 250
    final e = calc.estimate(ctx: ctx(standard, code), inputTokens: tokens);
    expect(e.tokensUsed, 850);
    expect(e.totalMl, closeTo(2.7066975, eps));
  });

  test('routing suggestion: standard → lightweight saves 1.018992 mL', () {
    final s = calc.savingsIfSwitched(current: ctx(standard, text), alternative: lightweight, inputTokens: 100);
    expect(s, closeTo(1.018992, eps));
  });

  test('token estimator rounds up', () {
    const t = TokenEstimator();
    expect(t.estimate(1000), 250);
    expect(t.estimate(1001), 251);
    expect(t.estimate(0), 0);
  });

  test('placeholder regions are refused unless explicitly allowed', () {
    const eu = RegionProfile(id: 'eu_west', pue: 1.15, wueSiteLPerKwh: 0.55, wueGridLPerKwh: null, confidence: 'placeholder');
    expect(() => calc.estimate(ctx: ctx(standard, text, eu), inputTokens: 100), throwsA(isA<PlaceholderRegionException>()));
    final e = const WaterCalculator(allowPlaceholders: true).estimate(ctx: ctx(standard, text, eu), inputTokens: 100);
    expect(e.scope2Ml, 0);
  });
}
