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

## 7. Next steps

1. Confirm methodology for the 3–5 mL discrepancy (§3).
2. `flutter create` scaffold + run the 7 tests (blocked locally today: sandbox shell unavailable; run `flutter test` on your machine).
3. Android `PromptAccessibilityService` for ChatGPT / Claude / Gemini packages + Chrome.
4. Browser extension content scripts (chatgpt.com, claude.ai, gemini.google.com).
5. Aggregate store, tracking UI, budget alerts, export.
