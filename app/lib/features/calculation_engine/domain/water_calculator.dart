/// Real-time math engine.
///
/// Formula (per requirements doc):
///   total_mL = E_query(Wh) × PUE × (WUE_site + WUE_grid)     [WUE in L/kWh == mL/Wh]
///   Scope 1  = E_query × PUE × WUE_site   (on-site cooling evaporation)
///   Scope 2  = E_query × PUE × WUE_grid   (off-site electricity generation)
///
/// E_query:
///   token-scaled tasks : energyWhPer1kWeightedTokens × weighted(in, out) / 1000 × taskMultiplier
///   fixed tasks (image): fixedEnergyWhPerItem × itemCount
///
/// weighted(in, out) = in × 0.20 + out × 1.00 — an output token costs about five times an input
/// token, because the answer is generated one token at a time while the question is read in
/// parallel. Mirrors engine.js exactly; docs/test/parity.js fails if the two ever disagree.
library;

import 'model_profile.dart';
import 'water_estimate.dart';

class PlaceholderRegionException implements Exception {
  PlaceholderRegionException(this.regionId);
  final String regionId;
  @override
  String toString() => 'Region "$regionId" has unsourced placeholder constants.';
}

class WaterCalculator {
  const WaterCalculator({required this.weights, this.allowPlaceholders = false, this.includeHydro = true});
  final TokenWeights weights;
  final bool allowPlaceholders;

  /// Counting hydropower reservoir evaporation is contested for cold climates, so it is a setting.
  final bool includeHydro;

  WaterEstimate estimate({
    required CalculationContext ctx,
    required int inputTokens,
    int? outputTokens,
    int itemCount = 1,
  }) {
    final region = ctx.region;
    if (region.isPlaceholder && !allowPlaceholders) {
      throw PlaceholderRegionException(region.id);
    }
    final wueSite = region.wueSiteLPerKwh ?? 0;
    final wueGrid = region.gridFor(includeHydro: includeHydro) ?? 0;

    double energyWh;
    int tokensUsed;
    if (ctx.task.isFixedEnergy) {
      // An image spends no text tokens — report zero either side so day totals stay honest.
      energyWh = ctx.task.fixedEnergyWhPerItem! * itemCount;
      tokensUsed = 0;
    } else {
      final outTokens = outputTokens ?? ctx.task.defaultOutputTokens;
      tokensUsed = inputTokens + outTokens;
      final weighted = weights.weigh(inputTokens, outTokens);
      energyWh = ctx.tier.energyWhPer1kWeightedTokens * weighted / 1000 * ctx.task.energyMultiplier;
    }

    final facilityWh = energyWh * region.pue;
    return WaterEstimate(
      energyWh: energyWh,
      scope1Ml: facilityWh * wueSite,
      scope2Ml: facilityWh * wueGrid,
      tokensUsed: tokensUsed,
      confidence: _weakest([ctx.tier.confidence, region.confidence]),
      constantsVersion: ctx.constantsVersion,
    );
  }

  /// "Switching this task to <tier> saves X mL" — same inputs, different tier.
  double savingsIfSwitched({
    required CalculationContext current,
    required TierProfile alternative,
    required int inputTokens,
    int? outputTokens,
  }) {
    final now = estimate(ctx: current, inputTokens: inputTokens, outputTokens: outputTokens);
    final alt = estimate(
      ctx: CalculationContext(tier: alternative, task: current.task, region: current.region, constantsVersion: current.constantsVersion),
      inputTokens: inputTokens,
      outputTokens: outputTokens,
    );
    return now.totalMl - alt.totalMl;
  }

  static const _rank = {'placeholder': 0, 'low': 1, 'medium': 2, 'high': 3};
  static String _weakest(List<String> levels) =>
      levels.reduce((a, b) => (_rank[a] ?? 0) <= (_rank[b] ?? 0) ? a : b);
}
