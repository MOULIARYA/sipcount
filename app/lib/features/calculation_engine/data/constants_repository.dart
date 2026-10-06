/// Loads assets/calc/models.v2.json into domain profiles. That file is GENERATED from engine.js by
/// tools/build-shared.js — never hand-edit it. The only place in the
/// engine that touches Flutter (rootBundle). Everything downstream is pure Dart.
library;

import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

import '../domain/model_profile.dart';

/// The icon and word shown for a zone. Both come from the shared constants so the phone and the
/// prototype never disagree about what "amber" is called.
class ZoneLook {
  const ZoneLook({required this.icon, required this.label});
  final String icon;
  final String label;
}

/// One water fact, with the source it came from. Shown at most twice a day.
class WaterFact {
  const WaterFact({required this.emoji, required this.hook, required this.text,
                   required this.source, required this.url});
  final String emoji;
  final String hook;
  final String text;
  final String source;
  final String url;
}

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

  // ---- content published from engine.js, not retyped here ---------------------------------
  // The zone thresholds, the zone words, the brand names, the mascot frames and all eleven facts
  // come from the same file the prototype reads. Retyping them into Dart is how the two products
  // drifted three revisions apart; `parity.js` now asserts these match word for word.

  /// `{green: 0.5, amber: 0.7}` — the fraction of the budget at which each zone starts.
  Map<String, double> get zones =>
      {for (final e in (_raw['zones'] as Map).entries) e.key as String: (e.value as num).toDouble()};

  /// `{green: (icon: '✓', label: 'Optimal'), …}`
  Map<String, ZoneLook> get zoneUi => {
        for (final e in (_raw['zone_ui'] as Map).entries)
          e.key as String: ZoneLook(
            icon: (e.value as Map)['icon'] as String,
            label: (e.value as Map)['label'] as String,
          )
      };

  /// `{openai: 'ChatGPT', …}` — what each vendor is called in front of the user.
  Map<String, String> get brands => Map<String, String>.from(_raw['brands'] as Map);

  /// `{plant: ['plant-0.webp', …], …}` — five frames, 0 = pristine, 4 = at the limit.
  Map<String, List<String>> get characterFrames => {
        for (final e in (_raw['characters'] as Map).entries)
          e.key as String: List<String>.from(e.value as List)
      };

  List<WaterFact> get facts => [
        for (final f in (_raw['facts'] as List).cast<Map<String, dynamic>>())
          WaterFact(emoji: f['emoji'] as String, hook: f['hook'] as String, text: f['text'] as String,
                    source: f['source'] as String, url: f['url'] as String)
      ];

  /// How often a fact is allowed to interrupt. Quieter than it used to be, and never on open.
  int get factEveryPrompts => (_raw['fact_cadence']['every_prompts'] as num).toInt();
  int get factMaxPerDay => (_raw['fact_cadence']['max_per_day'] as num).toInt();

  // The two corrections that make a heavy turn honest. Absent before 2026-10-06, which is why the
  // phone was running a simpler engine than the extension.
  double get thinkingTokensPerSec => (_raw['thinking']['tokens_per_sec'] as num).toDouble();
  double get thinkingFloorSec => (_raw['thinking']['floor_sec'] as num).toDouble();
  double get thinkingMaxSec => (_raw['thinking']['max_sec'] as num).toDouble();
  double get contextPerThousand => (_raw['context']['per_thousand'] as num).toDouble();
  double get contextMax => (_raw['context']['max'] as num).toDouble();

  /// Which zone a fraction of the budget falls in. Same thresholds as the prototype's `zone()`.
  String zoneOf(double pct) {
    final z = zones;
    if (pct < z['green']!) return 'green';
    if (pct < z['amber']!) return 'amber';
    return 'red';
  }
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
