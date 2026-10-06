/// Loads assets/calc/models.v2.json into domain profiles. That file is GENERATED from engine.js by
/// tools/build-shared.js — never hand-edit it. The only place in the
/// engine that touches Flutter (rootBundle). Everything downstream is pure Dart.
library;

import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

import '../domain/model_profile.dart';

class ConstantsRepository {
  ConstantsRepository._(this._raw);
  final Map<String, dynamic> _raw;

  static Future<ConstantsRepository> load({String asset = 'assets/calc/models.v2.json'}) async {
    final json = jsonDecode(await rootBundle.loadString(asset)) as Map<String, dynamic>;
    return ConstantsRepository._(json);
  }

  String get constantsVersion => _raw['constants_version'] as String;

  /// The agreed daily budget, from the shared constants rather than a number invented here.
  /// No `??` fallback on purpose: a missing key means the generated file is stale, and that should
  /// fail loudly instead of silently restoring the 100 mL this app used to make up for itself.
  int get defaultBudgetMl => (_raw['default_budget_ml'] as num).toInt();

  /// Likewise the starting region. This app used to default to `us_default`, an id that stopped
  /// existing at the seven-region migration, so a fresh install looked up a region that was not
  /// there and threw on the first prompt it counted.
  String get defaultRegionId => _raw['default_region_id'] as String;
  double get charsPerToken => (_raw['token_estimation']['chars_per_token'] as num).toDouble();
  Map<String, num> get equivalentsMl => Map<String, num>.from(_raw['equivalents_ml'] as Map);

  /// Output tokens cost more than input tokens. See [TokenWeights].
  TokenWeights get tokenWeights {
    final m = _raw['token_weights'] as Map<String, dynamic>;
    return TokenWeights(input: (m['input'] as num).toDouble(), output: (m['output'] as num).toDouble());
  }

  TierProfile tier(ModelTier t) {
    final m = _raw['model_tiers'][t.name] as Map<String, dynamic>;
    // Deliberately the weighted key: a build still reading the old `energy_wh_per_1k_tokens` should
    // fail here rather than quietly produce a figure ~24% out on heavy prompts.
    return TierProfile(
      tier: t,
      energyWhPer1kWeightedTokens: (m['energy_wh_per_1k_weighted_tokens'] as num).toDouble(),
      confidence: m['confidence'] as String,
    );
  }

  TaskProfile task(TaskType t) {
    final key = switch (t) { TaskType.longContext => 'long_context', _ => t.name };
    final m = _raw['task_profiles'][key] as Map<String, dynamic>;
    return TaskProfile(
      type: t,
      defaultOutputTokens: (m['default_output_tokens'] as num?)?.toInt() ?? 0,
      energyMultiplier: (m['energy_multiplier'] as num?)?.toDouble() ?? 1.0,
      fixedEnergyWhPerItem: (m['fixed_energy_wh_per_item'] as num?)?.toDouble(),
    );
  }

  RegionProfile region(String id) {
    final m = _raw['regions'][id] as Map<String, dynamic>;
    return RegionProfile(
      id: id,
      pue: (m['pue'] as num).toDouble(),
      wueSiteLPerKwh: (m['wue_site_l_per_kwh'] as num?)?.toDouble(),
      wueGridLPerKwh: (m['wue_grid_l_per_kwh'] as num?)?.toDouble(),
      wueGridExcludingHydroLPerKwh: (m['wue_grid_l_per_kwh_excluding_hydro'] as num?)?.toDouble(),
      confidence: m['confidence'] as String,
    );
  }

  /// Every region id the constants carry, so the UI never hard-codes the list.
  List<String> get regionIds => (_raw['regions'] as Map<String, dynamic>).keys.toList();

  /// Vendor + model-name hint (e.g. 'openai', 'o3-mini') → tier via substring patterns.
  /// Longest matching pattern wins so 'flash-lite' beats 'flash'.
  ModelTier resolveTier(String vendor, String? modelHint) {
    final v = (_raw['vendor_model_map'][vendor] ?? _raw['vendor_model_map']['unknown']) as Map<String, dynamic>;
    final patterns = Map<String, String>.from(v['patterns'] as Map);
    final hint = (modelHint ?? '').toLowerCase();
    String? best;
    for (final p in patterns.keys) {
      if (hint.contains(p) && (best == null || p.length > best.length)) best = p;
    }
    return ModelTier.values.byName(best != null ? patterns[best]! : v['default_tier'] as String);
  }
}
