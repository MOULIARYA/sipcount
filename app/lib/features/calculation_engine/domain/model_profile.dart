/// Pure value objects for the Calculation Engine. No I/O, no Flutter imports.
library;

enum ModelTier { lightweight, standard, reasoning }

enum TaskType { text, code, longContext, image }

/// Per-tier energy cost. Units: Wh per 1,000 tokens (input + output).
class TierProfile {
  const TierProfile({required this.tier, required this.energyWhPer1kTokens, required this.confidence});
  final ModelTier tier;
  final double energyWhPer1kTokens;
  final String confidence;
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
    required this.confidence,
  });
  final String id;
  final double pue;
  final double? wueSiteLPerKwh;
  final double? wueGridLPerKwh;
  final String confidence;

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
