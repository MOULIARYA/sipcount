/// Loads assets/calc/models.json into domain profiles. The only place in the
/// engine that touches Flutter (rootBundle). Everything downstream is pure Dart.
library;

import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

import '../domain/model_profile.dart';

class ConstantsRepository {
  ConstantsRepository._(this._raw);
  final Map<String, dynamic> _raw;

  static Future<ConstantsRepository> load({String asset = 'assets/calc/models.json'}) async {
    final json = jsonDecode(await rootBundle.loadString(asset)) as Map<String, dynamic>;
    return ConstantsRepository._(json);
  }

  String get constantsVersion => _raw['constants_version'] as String;
  double get charsPerToken => (_raw['token_estimation']['chars_per_token'] as num).toDouble();
  Map<String, num> get equivalentsMl => Map<String, num>.from(_raw['equivalents_ml'] as Map);

  TierProfile tier(ModelTier t) {
    final m = _raw['model_tiers'][t.name] as Map<String, dynamic>;
    return TierProfile(tier: t, energyWhPer1kTokens: (m['energy_wh_per_1k_tokens'] as num).toDouble(), confidence: m['confidence'] as String);
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
      confidence: m['confidence'] as String,
    );
  }

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
