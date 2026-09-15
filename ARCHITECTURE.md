# AI Meets Sustainability — Architecture (v0.1, 2026-09-14)

Source of truth for requirements: `Requirement/PROJECT.txt`. Decisions below reconcile that document with the project constraints (zero data retention, efficiency, 100% OSS).

## 1. Decisions

| # | Topic | Decision | Rationale |
|---|-------|----------|-----------|
| D1 | UI framework | **Flutter** (BSD-3), Dart AOT | Smallest footprint of the cross-platform options with a mature design toolkit; no JS bridge; largest community. RN rejected (JS runtime overhead for event-driven work); KMP viable but Compose-iOS maturity risk for a design-led app. |
| D2 | Interception surfaces | **Android `AccessibilityService`**, **iOS keyboard extension** (+ share extension fallback), **browser extension (MV3)** for desktop Chrome/Firefox/Edge | No mobile OS permits reading another app's traffic; "browser/API level" interception (PROJECT.txt) is only truly achievable via an extension. All three emit the same `PromptEvent`. |
| D3 | Retention | **On-device aggregate counters only** (mL by day × tier × task). No prompt text, no identifiers, no cloud. User-wipeable. | Daily/weekly/annual tracking and budgets are impossible with a literally stateless app; counters are not personal data. |
| D4 | ESG Reporting API | **Local export only** (CSV/JSON via share sheet, documented schema) | A backend contradicts zero retention and adds cost. Enterprise ingestion can consume the export. |
| D5 | Constants | Versioned `assets/calc/models.json` with citations and confidence levels; engine **refuses placeholder regions** | Per-query figures are estimates; the UI must be able to show provenance. |
| D6 | Model identification | Vendor from app package / hostname; tier from on-screen model label via substring patterns (`o3`→reasoning, `flash`→lightweight …) | Listener can see the model selector but not the API call. |
| D8 | Mobile sensing (2026-09-15) | **Layered**: network sensor (VpnService / iOS Network Extension; host + byte counts only) as primary, accessibility as optional model-name enhancer (Android), export import as optional true-up | Vendors expose no usage; the network layer is app- and browser-agnostic and identical on both platforms. See ISSUES.md D-1…D-6. |
| D9 | Tier inference | TTFB + reply size → tier; user "usual model" prior; corrected by exports when present | Model is inside TLS; tier (not model) is what the formula needs. |
| D10 | Calibration distribution | Extension measures → aggregate coefficients in versioned `models.json` → **shipped in app updates**; opt-in "keep constants fresh" download from GitHub Pages | Preserves the no-internet default while allowing fresh numbers. |
| D7 | Task profiling | `text` / `code` / `long_context` / `image` from UI cues (image-gen mode, attachments, code fences) | Drives output-token defaults and fixed energy for images. |

## 2. Requirement → module map

| PROJECT.txt item | Module | v1 status |
|---|---|---|
| Prompt Listener | `prompt_listener` (Dart) + `android/…/listener`, `ios/KeyboardExtension`, `browser_extension/` | contract done; native shells next |
| Model Identification | `ConstantsRepository.resolveTier` | done |
| Task Profiling | `PromptEvent.task`, `TaskProfile` | done (detection heuristics in native shells next) |
| Scope 1 / Scope 2 / Math Engine | `WaterCalculator` | done, unit-tested |
| Micro-Metric Display | `EquivalenceFormatter` | done (UI pending) |
| Cumulative Tracking | `WaterAggregate` + `session_aggregator` (Drift/sqlite counters) | next |
| Alternative Routing | `WaterCalculator.savingsIfSwitched` | done |
| ESG export | `export/` CSV/JSON | next |
| Threshold alerts | `budget/` + `flutter_local_notifications` | next |

## 3. Formula and constants (v2026-09-14)

```
total_mL = E_query(Wh) × PUE × (WUE_site + WUE_grid)        WUE in L/kWh ≡ mL/Wh
Scope 1  = E_query × PUE × WUE_site
Scope 2  = E_query × PUE × WUE_grid
E_query  = Wh/1k-tokens(tier) × (input + output tokens)/1000     (text, code, long_context)
         = 2.9 Wh × images                                         (image)
```

Defaults (US): PUE 1.15, WUE_site 0.55, WUE_grid 3.142 (Li et al. 2023). Standard tier 0.75 Wh/1k tokens (≈0.30 Wh per 100-in/300-out prompt; Epoch AI 2025, Google 2025, OpenAI 2025). Reasoning 10× (low confidence). Lightweight 0.2× (low confidence).

**Resulting golden values** (verified by executing the formula independently):

| Case | Energy | Scope 1 | Scope 2 | Total |
|---|---|---|---|---|
| Standard text, 100 input tokens | 0.30 Wh | 0.190 mL | 1.084 mL | **1.274 mL** |
| Reasoning, same prompt | 3.0 Wh | 1.898 mL | 10.840 mL | **12.737 mL** |
| One image | 2.9 Wh | 1.834 mL | 10.479 mL | **12.313 mL** |
| Standard → lightweight switch | — | — | — | saves **1.019 mL** |

**Flag:** PROJECT.txt cites "3–5 mL per standard prompt". Current constants give ~1.3 mL. The 3–5 mL figure matches GPT-3-era estimates (Li et al. 2023: ~10–50 mL per response); 2025 vendor disclosures are lower (0.26–0.32 mL, though those exclude grid water). Decide which methodology to adopt — it only changes `models.json`, not code.

### 3a. Regional constants (prototype v2, constants 2026-09-15)

Formula unchanged: Scope 1 = E × PUE × WUE_site; Scope 2 = E × PUE × EWIF_grid (WRI 2020 method; Li et al. 2023). Confidence: **H** published for exactly this quantity · **M** published, adapted · **L** derived from published components.

| Preset | PUE | WUE_site L/kWh | EWIF incl. hydro | EWIF excl. hydro | Aqueduct stress | Main sources |
|---|---|---|---|---|---|---|
| US hyperscale | 1.17 H | 0.55 H | 3.142 H | 1.67 L | Low–medium M | Li et al. Table 1 (Microsoft US); WRI 2020 App. 2/4/6 |
| US Texas (ERCOT) | 1.28 H | 0.25 H | 1.287 H | 1.22 L | High L | Li et al.; WRI eGRID ERCT |
| EU average | 1.16 H | 0.03 H | 3.95 L | 1.9 L | Medium–high M (varies by country) | Microsoft EMEA FY25; WRI country factors, generation-weighted |
| Nordic | 1.12 H | 0.05 H | 6.00 L | 1.12 L | Low M | Li et al. (MS Sweden/Finland); WRI NO/SE/FI; Bakken 2017 |
| India | 1.43 M | 2.0 L | 3.44 H | 2.25 L | Extremely high M | WRI India; CSE 2021 (CEA norms); Microsoft India |
| Singapore | 1.28 H | 2.2 M | 0.75 L | 0.40 L | Extremely high H | EMA fuel mix; Macknick NGCC; IMDA 2024 |
| Japan | 1.10 H | 0.32 L | 2.31 H | 1.50 L | not verified | WRI Japan; Google Inzai PUE |

Cooling overrides (WUE_site): towers 1.8 (M), adiabatic 0.32 (H, LBNL 2024), dry/free-air 0.03 (H). Water stress is context only: the headline mL never changes; the "weighted" line uses an illustrative multiplier (band midpoint ÷ 20 %).

### 3b. Contextual plant — flora & endangered species (prototype v4, verified 2026-09-15)

| Region | Mascot (native confirmed) | Seasonality | Endangered species shown in "water stress" mode | Threat (source) |
|---|---|---|---|---|
| US | Sugar maple *Acer saccharum* | deciduous; blooms Apr–May; red autumn | Huachuca water-umbel *Lilaeopsis schaffneriana recurva* — ESA Endangered | groundwater pumping, drought (US FWS) |
| Texas | Live oak *Quercus virginiana* | evergreen; catkins Mar–Apr | Texas wild-rice *Zizania texana* — ESA Endangered | reduced spring flow from Edwards Aquifer pumping (US FWS) |
| EU | Pedunculate oak *Quercus robur* | deciduous; blooms Apr–May; brown autumn | Doñana pond grass *Micropyropsis tuberosa* — IUCN EN | pond desiccation from groundwater abstraction (Nature Ecol. Evol. 2022) |
| Nordics | Silver birch *Betula pendula* | deciduous; golden autumn | — not yet verified | |
| India | Neem *Azadirachta indica* | evergreen; flowers Mar–May | Kathalekan marsh nut *Semecarpus kathalekanensis* — IUCN CR | swamp water diverted for agriculture (IUCN 2021) |
| Singapore | Tembusu *Cyrtophyllum fragrans* | evergreen; flowers May–Jun & Oct–Nov | Bukit Timah cryptocoryne *Cryptocoryne × timahensis* — nationally CR | single pool, hydrology-dependent |
| Japan | Yoshino cherry *Prunus × yedoensis* (cultivated hybrid) | deciduous; blooms late Mar–early Apr | — not yet verified | |

Season is derived from the device date and the region (all Northern hemisphere; Singapore treated as aseasonal). No location is collected.

**Known divergence:** `app/assets/calc/models.json` still uses PUE 1.15 for `us_default`; the prototype uses Li's 1.170. Golden tests must be re-derived when models.json is synced (ISSUES I-16).

**Methodological caveats to surface in any report:** WRI EWIFs reflect ~2016 mixes and allocate 100 % of gross reservoir evaporation to hydropower; Google's 0.26 mL/prompt is on-site only, Mistral's 45 mL is full life-cycle, OpenAI's 0.32 mL has no stated scope — not comparable.

## 4. Privacy boundary

`PromptEvent` is the only type allowed across the native→Dart boundary. It contains `char_count`, `vendor`, `model_hint`, `task`, `attachment_count`, `ts`. `PromptEvent.fromJson` fails closed if any text-bearing key is present. Native shells must discard text before serialising. The iOS keyboard extension runs **without** the Full Access entitlement (no network possible by construction).

## 5. Folder structure

```
app/
├─ lib/
│  ├─ main.dart
│  ├─ app/                              theme (dark default), router
│  ├─ core/                             shared widgets, formatting, DI (Riverpod)
│  └─ features/
│     ├─ prompt_listener/
│     │  ├─ domain/prompt_event.dart    ✔ privacy boundary contract
│     │  ├─ data/listener_channel.dart  ✔ EventChannel bridge
│     │  ├─ data/permission_service.dart
│     │  └─ presentation/               enable-listener onboarding
│     ├─ calculation_engine/
│     │  ├─ domain/model_profile.dart          ✔
│     │  ├─ domain/water_estimate.dart         ✔ (+ WaterAggregate)
│     │  ├─ domain/token_estimator.dart        ✔
│     │  ├─ domain/water_calculator.dart       ✔ Scope1/Scope2/routing
│     │  ├─ domain/equivalence_formatter.dart  ✔
│     │  ├─ data/constants_repository.dart     ✔ loads models.json
│     │  └─ data/aggregate_store.dart          counters only (Drift)
│     ├─ tracking/                       daily/weekly/annual views, spikes
│     ├─ budget/                         thresholds + local notifications
│     └─ export/                         CSV/JSON ESG export
├─ assets/calc/models.json               ✔ versioned, cited constants
├─ android/app/src/main/kotlin/…/listener/
│  ├─ PromptAccessibilityService.kt      detect send, count chars, drop text
│  └─ ListenerStreamHandler.kt
├─ ios/
│  ├─ Runner/Listener/ListenerStreamHandler.swift
│  ├─ KeyboardExtension/                 no Full Access; App Group for counters
│  └─ ShareExtension/
└─ test/calculation_engine/water_calculator_test.dart  ✔ 7 golden tests
browser_extension/                        MV3; content scripts per vendor host; same PromptEvent JSON
```

## 6. Dependencies (all permissive OSS)

Flutter (BSD-3), flutter_riverpod (MIT), drift (MIT, sqlite counters), flutter_local_notifications (BSD-3), share_plus (BSD-3). No analytics, no crash reporting, no network permission in v1.

## 7. Increment log

| Inc | Delivered | Where |
|---|---|---|
| 1 | Web prototype (standalone HTML) | `prototype/sipcount.html` → https://mouliarya.github.io/sipcount/sipcount.html |
| 2 | Chrome MV3 extension (no network permission) | `browser_extension/` |
| 3 | Android app: Flutter shell (Today + Settings, dark), `PromptAccessibilityService`, pending-event queue, aggregate counters, CI-built APK | `app/`, `.github/workflows/android-apk.yml` → release tag `android-latest` |
| 3b | Prototype v2 (partner feedback 2026-09-15): 7 regional presets with confidence labels, cooling-tech and hydro toggles, water-stress context, 4 age-adaptive metaphor modes with generic animated vessels, senior large-print/AAA mode, per-tier micro-copy, editable `SIPCOUNT_CONFIG` | `prototype/sipcount.html` → live link |

### Increment 3 decisions (2026-09-14)

- **Detection = AccessibilityService** (chosen over custom keyboard / share sheet): zero friction after a one-time toggle. Scope is the narrowest the platform allows: 4 packages, 3 event types, bounded 300-node window scans, labels ≤ 40 chars only. Play Store review risk accepted for now (distribution is direct APK).
- **Counters store = `shared_preferences`** (BSD-3) instead of Drift: no code-gen step in CI, and the data is a JSON map of day → {n, s1, s2, wh, by-tier, by-task}. Migrate to Drift only if per-hour views are needed.
- **Offline capture**: when the Flutter engine is not running, the service appends PromptEvent JSON (counts only) to an app-private `pending_prompt_events.jsonl` (max 2000 lines); Dart drains it on launch. Calculation therefore always happens in Dart — one engine, one set of golden tests.
- **No INTERNET permission** in the manifest; backups and device transfer excluded via `data_extraction_rules.xml`.
- **CI**: only hand-written Android files are in git. The workflow runs `flutter create --platforms=android` (never overwrites) to generate Gradle/wrapper/icons, then `analyze → test → build apk --release` (debug-key signed) and publishes to the `android-latest` pre-release.
- **Demo mode**: "Try it" buttons on the Today screen inject synthetic PromptEvents through the real pipeline, so the app can be shown before the permission is granted.

## 8. Next steps

1. User test on a real phone (ChatGPT / Claude / Gemini apps + Chrome); tune send-button and model-label heuristics from feedback.
2. Confirm methodology for the 3–5 mL discrepancy (§3).
3. Detect keyboard-Enter sends; distinguish image generation; whitelist Firefox / Samsung Internet.
4. Budget alerts (`flutter_local_notifications`), weekly/annual views, CSV/JSON export.
5. Increment 4: iOS (keyboard + share extension) — needs Apple developer account.
