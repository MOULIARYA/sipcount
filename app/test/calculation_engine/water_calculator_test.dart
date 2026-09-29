/// The Dart engine must agree with `engine.js` exactly — not approximately.
///
/// The expected numbers are NOT written here. They are read from `assets/calc/models.v2.json`,
/// which `tools/build-shared.js` generates from engine.js. So there is no hand-typed constant
/// anyone can quietly adjust to make a failing test pass: if Dart and the JavaScript engine ever
/// diverge, this fails, and the only way to fix it is to fix the maths.
///
/// Why this exists: for two weeks the web prototype's maths improved while this app stayed on the
/// 2026-09-14 constants. A heavy prompt came out 24% apart, and there was no India region at all,
/// so an Indian user would have been shown roughly half the real figure.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ai_water/features/calculation_engine/domain/model_profile.dart';
import 'package:ai_water/features/calculation_engine/domain/water_calculator.dart';

void main() {
  final raw = jsonDecode(File('assets/calc/models.v2.json').readAsStringSync()) as Map<String, dynamic>;
  final version = raw['constants_version'] as String;

  final weights = TokenWeights(
    input: (raw['token_weights']['input'] as num).toDouble(),
    output: (raw['token_weights']['output'] as num).toDouble(),
  );
  final calc = WaterCalculator(weights: weights);
  const eps = 1e-6;

  TierProfile tierOf(String id) {
    final m = raw['model_tiers'][id] as Map<String, dynamic>;
    return TierProfile(
      tier: ModelTier.values.byName(id),
      energyWhPer1kWeightedTokens: (m['energy_wh_per_1k_weighted_tokens'] as num).toDouble(),
      confidence: m['confidence'] as String,
    );
  }

  TaskProfile taskOf(String id) {
    final m = raw['task_profiles'][id] as Map<String, dynamic>;
    final type = switch (id) {
      'code' => TaskType.code,
      'long_context' => TaskType.longContext,
      'image' => TaskType.image,
      _ => TaskType.text,
    };
    return TaskProfile(
      type: type,
      defaultOutputTokens: (m['default_output_tokens'] as num?)?.toInt() ?? 0,
      energyMultiplier: (m['energy_multiplier'] as num?)?.toDouble() ?? 1.0,
      fixedEnergyWhPerItem: (m['fixed_energy_wh_per_item'] as num?)?.toDouble(),
    );
  }

  RegionProfile regionOf(String id) {
    final m = raw['regions'][id] as Map<String, dynamic>;
    return RegionProfile(
      id: id,
      pue: (m['pue'] as num).toDouble(),
      wueSiteLPerKwh: (m['wue_site_l_per_kwh'] as num?)?.toDouble(),
      wueGridLPerKwh: (m['wue_grid_l_per_kwh'] as num?)?.toDouble(),
      wueGridExcludingHydroLPerKwh: (m['wue_grid_l_per_kwh_excluding_hydro'] as num?)?.toDouble(),
      confidence: m['confidence'] as String,
    );
  }

  group('parity with engine.js', () {
    final golden = (raw['golden'] as List).cast<Map<String, dynamic>>();

    test('there are golden cases to check', () => expect(golden, isNotEmpty));

    for (final g in golden) {
      final region = g['region'] as String, tier = g['tier'] as String, task = g['task'] as String;
      test('$tier / $task / $region reproduces engine.js', () {
        final e = calc.estimate(
          ctx: CalculationContext(
            tier: tierOf(tier), task: taskOf(task), region: regionOf(region), constantsVersion: version),
          inputTokens: (g['inputTokens'] as num).toInt(),
          outputTokens: (g['outputTokens'] as num?)?.toInt(),
          itemCount: (g['items'] as num?)?.toInt() ?? 1,
        );
        expect(e.energyWh, closeTo((g['expect_energy_wh'] as num).toDouble(), eps));
        expect(e.scope1Ml, closeTo((g['expect_scope1_ml'] as num).toDouble(), eps));
        expect(e.scope2Ml, closeTo((g['expect_scope2_ml'] as num).toDouble(), eps));
        expect(e.totalMl, closeTo((g['expect_total_ml'] as num).toDouble(), eps));
      });
    }
  });

  group('the things that were wrong before', () {
    test('an output token costs five times an input token', () {
      final ctx = CalculationContext(
        tier: tierOf('standard'), task: taskOf('text'),
        region: regionOf('us_hyperscale'), constantsVersion: version);
      final allInput = calc.estimate(ctx: ctx, inputTokens: 400, outputTokens: 0);
      final allOutput = calc.estimate(ctx: ctx, inputTokens: 0, outputTokens: 400);
      expect(allOutput.totalMl / allInput.totalMl, closeTo(5.0, eps));
    });

    test('the calibrated reference prompt is unchanged at 0.30 Wh', () {
      final e = calc.estimate(
        ctx: CalculationContext(
          tier: tierOf('standard'), task: taskOf('text'),
          region: regionOf('us_hyperscale'), constantsVersion: version),
        inputTokens: 100, outputTokens: 300);
      expect(e.energyWh, closeTo(0.30, eps));
      expect(e.tokensUsed, 400);
    });

    test('India exists, and is not quietly the US figure', () {
      expect(raw['regions'].containsKey('india'), isTrue);
      double ml(String r) => calc
          .estimate(
            ctx: CalculationContext(
              tier: tierOf('standard'), task: taskOf('text'),
              region: regionOf(r), constantsVersion: version),
            inputTokens: 100, outputTokens: 300)
          .totalMl;
      expect(ml('india'), greaterThan(ml('us_hyperscale') * 1.5));
    });

    test('every region the constants carry can be built', () {
      for (final id in (raw['regions'] as Map<String, dynamic>).keys) {
        expect(regionOf(id).pue, greaterThan(1.0), reason: id);
      }
      expect((raw['regions'] as Map).length, 7);
    });

    test('an image spends no tokens', () {
      final e = calc.estimate(
        ctx: CalculationContext(
          tier: tierOf('standard'), task: taskOf('image'),
          region: regionOf('us_hyperscale'), constantsVersion: version),
        inputTokens: 5000);
      expect(e.tokensUsed, 0);
    });

    test('excluding hydro lowers the grid figure where it matters', () {
      final nordic = regionOf('nordic');
      expect(nordic.gridFor(includeHydro: false)!, lessThan(nordic.gridFor(includeHydro: true)!));
    });
  });
}
