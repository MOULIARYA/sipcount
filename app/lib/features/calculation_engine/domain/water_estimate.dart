/// Result of one water estimate. All water values in millilitres, energy in Wh.
library;

class WaterEstimate {
  const WaterEstimate({
    required this.energyWh,
    required this.scope1Ml,
    required this.scope2Ml,
    required this.tokensUsed,
    required this.confidence,
    required this.constantsVersion,
  });

  /// Energy attributed to the query before PUE overhead.
  final double energyWh;

  /// Scope 1 — on-site evaporative cooling water: energyWh * PUE * WUE_site.
  final double scope1Ml;

  /// Scope 2 — off-site water for electricity generation: energyWh * PUE * WUE_grid.
  final double scope2Ml;

  /// Total tokens (input + estimated output) used in the calculation; 0 for fixed-energy tasks.
  final int tokensUsed;

  /// Weakest confidence among the inputs ('low' | 'medium' | 'high').
  final String confidence;

  final String constantsVersion;

  double get totalMl => scope1Ml + scope2Ml;

  Map<String, Object> toJson() => {
        'energy_wh': energyWh,
        'scope1_ml': scope1Ml,
        'scope2_ml': scope2Ml,
        'total_ml': totalMl,
        'tokens_used': tokensUsed,
        'confidence': confidence,
        'constants_version': constantsVersion,
      };
}

/// Aggregate over a period. Stores counters only — never prompt content.
class WaterAggregate {
  WaterAggregate();
  int promptCount = 0;
  double scope1Ml = 0;
  double scope2Ml = 0;
  double energyWh = 0;
  double get totalMl => scope1Ml + scope2Ml;

  void add(WaterEstimate e) {
    promptCount += 1;
    scope1Ml += e.scope1Ml;
    scope2Ml += e.scope2Ml;
    energyWh += e.energyWh;
  }
}
