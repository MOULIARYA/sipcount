/// Pure value objects for the Calculation Engine. No I/O, no Flutter imports.
library;

enum ModelTier { lightweight, standard, reasoning }

enum TaskType { text, code, longContext, image }

/// How much an input token counts against an output token.
///
/// Generating an answer is slower, hotter work than reading a question: the model emits output one
/// token at a time, while input is processed in parallel. We weight output 5x input (central of a
/// 3-10x research range) and re-normalise the per-1k figure by 400/320, so the calibrated reference
/// prompt (100 in + 300 out) is unchanged at 0.30 Wh on the standard tier. See
/// docs/TOKEN-ECONOMICS.md; the multiplier is a placeholder until the I-30 calibration measures it.
class TokenWeights {
  const TokenWeights({required this.input, required this.output});
  final double input;
  final double output;
  double weigh(int inputTokens, int outputTokens) => inputTokens * input + outputTokens * output;
}

/// Per-tier energy cost. Units: Wh per 1,000 *weighted* tokens (see [TokenWeights]).
class TierProfile {
  const TierProfile({
    required this.tier,
    required this.energyWhPer1kWeightedTokens,
    required this.confidence,
    required this.label,
  });
  final ModelTier tier;
  final double energyWhPer1kWeightedTokens;
  final String confidence;

  /// 'Light' / 'Standard' / 'Reasoning' — what the user is shown. It has been in the constants
  /// file all along; this class simply never carried it, so the phone had no way to name a tier
  /// without inventing its own word for it.
  final String label;
}

/// Per-task-type behaviour. Either token-scaled (text/code/longContext) or fixed per item (image).
class TaskProfile {
  const TaskProfile({
    required this.type,
    this.defaultOutputTokens = 0,
    this.energyMultiplier = 1.0,
    this.fixedEnergyWhPerItem,
  });
  final TaskType type;
  final int defaultOutputTokens;
  final double energyMultiplier;
  final double? fixedEnergyWhPerItem;
  bool get isFixedEnergy => fixedEnergyWhPerItem != null;
}

/// Data-centre region parameters. WUE in L/kWh (== mL/Wh).
class RegionProfile {
  const RegionProfile({
    required this.id,
    required this.pue,
    required this.wueSiteLPerKwh,
    required this.wueGridLPerKwh,
    this.wueGridExcludingHydroLPerKwh,
    required this.confidence,
  });
  final String id;
  final double pue;
  final double? wueSiteLPerKwh;

  /// Water evaporated generating this region's electricity, counting hydropower reservoirs.
  final double? wueGridLPerKwh;

  /// The same, with reservoir evaporation excluded — contested for cold climates (Bakken 2017),
  /// so it is a user setting rather than a decision we make for them.
  final double? wueGridExcludingHydroLPerKwh;
  final String confidence;

  double? gridFor({required bool includeHydro}) =>
      includeHydro ? wueGridLPerKwh : (wueGridExcludingHydroLPerKwh ?? wueGridLPerKwh);

  bool get isPlaceholder => wueSiteLPerKwh == null || wueGridLPerKwh == null || confidence == 'placeholder';
}

/// Resolved parameters used for one calculation. Kept so the UI can show "how we got this number".
class CalculationContext {
  const CalculationContext({required this.tier, required this.task, required this.region, required this.constantsVersion});
  final TierProfile tier;
  final TaskProfile task;
  final RegionProfile region;
  final String constantsVersion;
}
