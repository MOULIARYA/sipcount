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
    this.inputTokens = 0,
    this.outputTokens = 0,
    this.hiddenTokens = 0,
    this.weightedTokens = 0,
    this.weightedInputTokens = 0,
  });

  /// Kept separately because the split is the product's main insight: most of the water goes into
  /// the answer, not the question.
  final int inputTokens;
  final int outputTokens;

  /// Work that never reached the screen — searching, reading, calling tools. On an agentic turn
  /// this is most of the cost, and leaving it out undercounted by ~28× (I-18, N9).
  final int hiddenTokens;

  /// Input and output after weighting, which is what the energy figure is actually built from.
  final double weightedTokens;

  /// The question's share of that, already weighted. Carried rather than recomputed here: writing
  /// `inputTokens * 0.2` in this file would put the input weight in two places, and a constant in
  /// two places is a constant that will disagree with itself.
  final double weightedInputTokens;

  /// How much of the weighted work was reading your question. Drives the split bar.
  double get inputShare => weightedTokens <= 0 ? 0 : weightedInputTokens / weightedTokens;

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
