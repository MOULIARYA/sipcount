# Sipcount — open issues & feedback tracker

Status legend: **Open** · **In progress** · **Parked** (deliberately later) · **Done**. Newest changes at the top of each entry.

| # | Issue | Status | Notes / next step |
|---|-------|--------|-------------------|
| I-1 | **Gemini prompts not counted** (Android) | In progress | Builds 7, 11 missed. Build 13 adds the Google app package (`googlequicksearchbox`) — Gemini is hosted there on many phones — counting only when a "Gemini" label is on screen. Awaiting test. If still missed: identify the text box by hint text instead of the editable flag. |
| I-2 | **App update fails ("App not installed")**; must uninstall + reinstall | Parked (user: fix later) | Cause: each CI build signs with a fresh throw-away key. Fix is ready in the repo: run *Generate signing key* workflow once → add secrets `SIPCOUNT_KEYSTORE_B64` + `SIPCOUNT_KEYSTORE_PASSWORD` → re-run *Android APK*. One more uninstall after that, then never again. |
| I-3 | **Play Protect blocks sideloaded install** (India et al.); Accessibility toggle greyed ("restricted setting") | Open (documented) | Workarounds in `app/ANDROID-INSTALL.md`. Structural fix = Play Store publication (review whitelists the service) or a different detection method. Decide after detection is stable. |
| I-4 | Chrome (chatgpt.com / claude.ai / gemini.google.com) detection untested on phone | Open | Needs one test each. |
| I-5 | Per-prompt figure: **1.3 mL (2025 vendor data) vs 3–5 mL (PROJECT.txt / 2023 research)** | Open | Methodology decision; only changes `models.json`. Partner's feedback (I-10) pushes toward Li et al. 2023 framing — decide together. |
| I-6 | Sends via keyboard Enter key not detected | Open | Low priority on mobile; matters on Chrome desktop extension. |
| I-7 | Image *generation* not distinguished from a text prompt | Open | Needs a UI cue per app ("Create image" mode). |
| I-8 | Browser extension (Increment 2) never tested on live sites | Open | Selectors may need adjusting. |
| I-9 | Extension has canvas-drawn icon, no real PNG icons | Open | Needs a shell (sandbox still broken by Windows update). |
| I-10 | **Partner feedback — engine: regional presets + water-stress toggle** | Done in prototype v2 (2026-09-15) | 7 presets (US, ERCOT, EU, Nordic, India, Singapore, Japan) with per-field confidence; cooling-tech override; hydro incl/excl toggle; stress shown as context (Madhur's decision), not multiplied into the headline. Android port = I-16. |
| I-11 | **Partner feedback — age-adaptive visual metaphors & units** | Done in prototype v2 | 4 modes (Gamer / Everyday / Professional / Clear) with generic animated vessels (potion flask, ring + tumbler, mug, measuring cup) and real-volume units. Brand items (Minecraft, Stanley, Hydro Flask, Apple rings) deliberately not reproduced. |
| I-12 | **Partner feedback — senior accessibility** | Done in prototype v2 | Clear mode / "Large print" toggle: 19 px base, ≥48 px targets, measured contrast 9.9–17.7:1 (AAA ≥7:1). Flutter app still to do. |
| I-13 | Possible false positive: clearing a typed prompt with select-all + delete counts as a send | Open | Inherent to text-clear detection; measure frequency in testing before mitigating. |
| I-14 | GitHub MCP connector not available in Cowork (only "GitHub Integration" for Projects) | Open (process) | Ask Xebia admin to enable the GitHub connector; until then pushes go through Chrome web upload. |
| I-16 | Android `models.json` (PUE 1.15, 2 regions) out of sync with prototype v2 constants (PUE 1.17, 7 regions, hydro toggle) | Open | Port `SIPCOUNT_CONFIG.regions` to models.json; re-derive the 7 golden test values; add cooling/hydro settings to the Flutter Settings page. |
| I-17 | Partner deliverable 3 (micro-copy) is per-tier in the prototype but the Android app has none | Open | Port after I-16. |
| D-7 | **Release architecture approved 2026-09-15**: Android = network sensor (allowed-apps-only local VPN, MIT engine) + no-VPN coarse mode, **no AccessibilityService** in the Play build; **Google Play** is the Android target (direct APK for testing only); Android spike (SENSING-REVIEW §7, ~10 working days, written acceptance thresholds) precedes any sensor UI; iOS = four-layer design (SENSING-REVIEW §8) — individual Apple account for dev/test now, company entity + D-U-N-S + organisation account in parallel. | Decided | Increment 3 accessibility build = test harness only; no further heuristic work on it beyond keeping it usable. |
| I-22 | Android spike A–G per SENSING-REVIEW §7 (attribution, prompt signature, battery, DNS/ECH matrix, coexistence, Play dry run, coarse mode) | Open — next | Bare test app, not the Sipcount UI. Needs 3 test phones (Pixel on A17 beta, Samsung, budget MediaTek) — Madhur to source. |
| I-23 | Play readiness: target SDK 36, 16 KB page size for native libs, VpnService declaration + 2 videos, disclosure screen with decline path, listing text | Open | Draft text in `docs/store/`. |
| I-24 | iOS track: individual Apple Developer account; macOS CI (GitHub Actions) for iOS builds; Safari Web Extension port; company entity → D-U-N-S → org account | Open | Start after spike B shows the prompt signature works. |
| I-18 | Spike: bytes↔tokens and TTFB↔tier correlation via extension (prerequisite for the network sensor) | Open | Add a calibration mode to the extension that logs (model, chars in, chars out, request bytes, response bytes, TTFB) — counts only. |
| I-19 | Network sensor (Android VpnService) prototype: detect prompt to chatgpt.com / claude.ai / gemini hosts, emit PromptEvent with size + timing | Open | Depends on I-18. Cannot coexist with another VPN. |
| I-20 | "Keep constants fresh" toggle: fetch published `models.json` from GitHub Pages; ship constants in updates by default | Open | Adds INTERNET permission gated by user toggle; document in privacy text. |
| I-21 | iOS: Network Extension entitlement + Apple developer account | Parked | Needed for the doorman on iOS; $99/yr + approval time. |
| I-15 | Sandbox shell broken by Windows update (2026-09-08) → no local compile/test, no zip, no keytool | Open (environment) | All verification is by review + CI. |

## Direction decisions — mobile sensing (2026-09-15, Madhur)

| # | Item | Status | Notes |
|---|------|--------|-------|
| D-1 | **Layered sensor model for mobile** (iOS + Android, personal phones) | Decided | Primary: *network sensor* ("doorman") — local VPN service (Android) / Network Extension (iOS) sees only destination host + byte counts, never content; app-agnostic, covers browsers. Optional: accessibility screen-watcher (Android only) for model name. Optional: monthly export import ("receipts") for exact true-up — assume most users won't; design must not depend on it. |
| D-2 | **Model/tier inference without seeing the model** | Decided | Time-to-first-byte + reply size → tier (light / standard / reasoning); user's "usual model" setting as prior; receipts import corrects when available. Needs calibration (D-3). |
| D-3 | **Calibration pipeline: extension → published constants → app** | Decided (middle path) | The browser extension, which sees model name *and* traffic, produces aggregate coefficients (bytes/token per vendor, TTFB & size thresholds per tier, tier prevalence). Coefficients live in versioned `models.json`. **App ships constants in every update (no internet needed)**; a Settings toggle "keep constants fresh" additionally downloads the public file from GitHub Pages (read-only, nothing sent). Default = off, preserving the no-internet claim. |
| D-4 | QR-code personal pairing (extension → phone, offline) | Parked — flourish | Madhur to raise with partner. Zero servers; helps only users with both installed. |
| D-5 | In-chat "Sipcount" connector for ChatGPT/Claude ("how much water did this chat use?") | Parked — idea | Awareness/distribution, not measurement. Connected-apps direction is AI → app, so it cannot report usage. |
| D-6 | Competitive landscape check | Done | All comparable tools are desktop browser extensions (ByteThirst, AI ftPrint, AI Impact Tracker, chatgpt-co2-tracker, Bottle it Back); no mobile measurement app found. Bottle it Back's "donate the water back" angle worth discussing. |

**Pre-build review done 2026-09-15 → `docs/SENSING-REVIEW.md`** (blockers B1–B8, improvements, store checklist, UI-independent work P1–P6, 3 decisions pending). Headline: iOS network sensor not viable for v1 (Apple org account + 5.4 + no app attribution) → iOS v1 = Safari extension; Android must use per-app UID attribution because Encrypted Client Hello (Android 17) hides hostnames.

Open before building D-1: (a) half-day spike measuring bytes↔tokens and TTFB↔tier using the extension; (b) iOS Network Extension entitlement request to Apple (weeks); (c) VPN permission wording/UX; (d) finish & test the extension first (I-8) since it is the calibration instrument.

## Partner feedback round 9 (received 2026-09-19) — "Lifetime Footprint"; delivered as v6.3

All-time impact card below the 7-day chart: darker (#0C0C0C) muted card; total since install auto-scales mL → L (≥1,000 mL) → m³ (≥1,000 L); macro-metaphor subtext (largest unit with count ≥ 1: Olympic pools / fire trucks / bathtubs / standard water bottles); "Tracking since Sep 2026" from the earliest recorded day (kept on wipe of totals). **I-26 (open):** macro volumes are assumptions — bottle 500 mL, bathtub 150 L, fire truck 2,500 L, Olympic pool 2,500,000 L — confirm with partner alongside I-25.

## Partner feedback round 8 (received 2026-09-19, on v6.1) — accepted; delivered as v6.2

Cup milestone alerts and click-to-read facts now fire for **all** users (D-17 fully reversed; age now only gates group features for under-13s). Settings top card → "Age profile · 13–17 / 18+ / Under 13" with Change age; no "alerts off" wording anywhere; dashboard mode pill removed. Settings helper reads "Your water is shown in Boba cups (500 mL per unit)." and a "Cup intro" alert fires on selection ("🍵 Matchas equipped! Tracking in 240 mL units."). Her example volumes (10,000 / 250 mL) were illustrative (Madhur, 2026-09-19); config values stand. **I-25 (open):** confirm all eight metaphor volumes with the partner once, since they are now displayed explicitly — bucket 1,000 · milk glass 250 · boba cup 500 · milkshake 400 · smoothie 350 · matcha 240 · espresso 30 · coffee mug 240 mL.

## Partner feedback round 7 (received 2026-09-19, on v6) — accepted; delivered as v6.1

Metaphor subtext condensed to one muted, non-wrapping line "≈ 0.10 Smoothies" under the mL figure; baseline volume and formula removed from the frontend entirely (Settings helper text no longer shows volumes either; volumes remain in the config for the maths). Facts: timed text-heavy card → **persistent teaser** (icon + 3–5-word hook + "Tap to read ›", no auto-dismiss, one at a time) that opens a readable modal with the full fact, context and source link, plus Close. Redundant in-card "✓ Optimal" badge removed; the top-right pill remains the single status indicator (icon + label kept for colour-blind safety).

## Partner feedback round 6 (received 2026-09-19, on v5.1) — accepted; delivered as v6

Facts now for **all** users (revises D-17: cup milestone alerts stay Educational-only; educational facts universal); cards last 9 s, hover/press-and-hold pauses and expands to full context with a source link, ✕ dismiss. Metaphor units always two decimals with baseline footnote ("1 smoothie = 350 mL · units = mL ÷ 350") and animated counting. New **About** tab "Behind the Cloud" with the supplied copy verbatim + CTA; a one-line estimate disclaimer added beneath (not inside) the copy. Palette tightened (#000 / #141414 cards / #262626 borders / #333 tracks; green #00F076, amber #FFB800, red #FF3B30). Colour-blind-safe status: ✓ Optimal / ⚠ Elevated / ✖ **Limit Exceeded** labels + striped (amber) and cross-hatched (red) bar fills. Hierarchy unchanged from v5.1 (drop › plant › insights › chart).
**Accuracy flag raised with Madhur:** the About copy says "your *exact* AI water footprint … down to the milliliter"; our numbers are estimates with stated confidence. Madhur changed "exact" → "estimated" in the About copy (2026-09-19); disclaimer line retained. Partner to be informed.

## Roadmap decisions — 2026-09-18 (Madhur; to be raised with partner)

| # | Item | Status | Notes |
|---|------|--------|-------|
| D-20 | **Desktop apps (Windows + macOS) = Increment 5** | Decided (Madhur) | Tray/menu-bar monitor for ChatGPT/Claude/Copilot desktop apps + browsers. Easier than mobile: per-process network attribution is a normal OS query; accessibility APIs may read model names with permission; no store gatekeeping for direct download. Same `PromptEvent` → same engine → same dashboard. Also the calibration bench for the mobile doorman. Sequence: after the Android spike. Variant to settle with partner: consumer tray app vs enterprise/ESG aggregate reporting. |
| D-21 | **Optional sign-in for a 360° cross-device view** | Open — Madhur's proposal, not yet discussed with partner | Value: one believable total across phone, laptop, extension; identity for groups/leaderboard; ESG later. Cost: privacy promise shifts from "nothing leaves the device" to "only daily totals, only if you sign in"; account system, storage, support, GDPR + India DPDP (under-18 parental consent). **Recommended path:** (1) bring-your-own-cloud sync first — app writes its daily-totals file to the user's own Google Drive / iCloud app folder; Sipcount runs no server; (2) Sipcount account + aggregate backend only when groups/leaderboard are approved; (3) sign-in gated to Minimalist Mode (18+) at launch. |
| **Architecture directive (Madhur, 2026-09-18)** | Build everything from now on so D-21 can be added later with maximum reuse and low maintenance | Standing | See ARCHITECTURE.md §9 "Sync-ready architecture rules". |

## Partner feedback round 5 (received 2026-09-18, on prototype v5) — all accepted, no decisions needed

Traffic-light thresholds (<50 % green, 50–69 % amber, ≥70 % red) applied to drop fill, budget bar, status text, plant label, nudge; drop card dominant and the drop now **drains from full**; plant card compact; plant degrades **continuously** with 0–100 % (colour green→amber→red, posture droops), collapsing past 100 %; Insights moved above the 7-day chart. Delivered as v5.1 (constants 2026-09-18).

## Partner feedback round 4 (received 2026-09-17, on prototype v4)

**Spec:** performance-tracker aesthetic (true black, flat #1A1A1A cards, white metrics, neon green accent); scrap the native-tree engine → one standardised Dynamic Plant; bring back the age splash; split into Educational Mode (13–17: sourced water-fact toasts) and Minimalist Mode (18+: no toasts, data only).
**Decisions (Madhur, 2026-09-17):** D-16 dark-only (light mode removed) · D-17 adults keep Neutralize, Share, Grove; lose cup milestone alerts · D-18 under-13 → Educational Mode with social off (13+ rating stands) · D-19 facts: one on open + one every 5 prompts, max 3/day, no repeats per day.
**Delivered as prototype v5.** 16 facts, each figure read on its source page (USGS, WRI Aqueduct 4.0, WHO/UNICEF JMP 2023, NITI Aayog, FAO, UN WWDR 2022, LBNL 2024, Li et al. 2023, Google 2025, Water Footprint Network); the "less than 1 % accessible freshwater" line was rewritten to USGS's own phrasing (2.5 % fresh, 1.2 % of that surface water). Flora/endangered research from round 3 is retained in ARCHITECTURE.md §3b for possible later use.
**Note to partner:** rounds 3→4 reversed two round-3 decisions (onboarding, plant); each reversal ≈ a day. Suggest freezing the shell after v5 and iterating on copy/data.

## Partner feedback round 3 (received 2026-09-15, on prototype v3)

**Accepted as mandatory:**
1. Remove age onboarding; full metaphor library for everyone, chosen in Settings. Hero = standard water drop + raw mL. Remove the cup-chip row from Today.
2. Metaphors move to **milestone toasts** (Zomato/Swiggy-style slide-ins): "Woah, that's 1 Boba down! 🧋", "Another bucket bites the dust! 🪣", per-prompt variant when one prompt alone exceeds a unit.
3. Merge Trends into Today: 7-day chart under the daily summary; new **Insights card** naming the AI brands used (ChatGPT / Claude / Gemini …), the dominant model tier, and an efficiency line ("standard models handled 60 % of tasks, saving ~40 mL vs the heaviest tier").
4. **Contextual plant engine**: seasonality; regional/endemic flora (Neem for Delhi, Saguaro for US Southwest…); optional endangered-species mode tied to local water stress.
5. **"Neutralize my water footprint"** button → modal linking out to water-project platforms (Act4Water, Water.org) sized to the user's calculated usage.

**Implications / risks (Claude):**
- Dropping age also drops age-driven density; keep "Text size" in Settings (accessibility). Store audience stays 13+ (D-9); Grove visible to all.
- Insights need per-day counters by **vendor × tier** (new in the data model; extension and app sensors already know vendor). Midjourney is not tracked by any sensor yet — add as a web host later.
- Efficiency saving is a counterfactual (what the same prompts would have cost on the heaviest tier used that day, or reasoning if none) — label it "roughly", never as measured.
- Regional flora: we have **no location** (privacy) → derive from the existing region setting, plus a manual species picker. Seasonality from date + hemisphere of that region. Species artwork is the largest effort item; endangered-species facts must come from IUCN/regional red lists with citations — research task before drawing.
- Offsets: "water-positive credits" claims are contested; button can keep her label but modal copy must say "supports projects that restore water" and show the platform's own price per m³ as an estimate. Link-out only — no in-app payment (keeps us clear of store IAP rules). Verify Act4Water is a real, current platform before linking.
- Brand names (ChatGPT, Claude, Gemini) in insights are fine as factual references; keep model-tier language ours ("reasoning", "standard").

**Decisions (Madhur, 2026-09-15):** D-13 one species per region + generic flower; endangered mode for regions with a verified water-threatened species · D-14 no location: plant follows the region setting, manual species picker · D-15 offset feature keeps her label, honest copy, link-out only.

**Research outcomes (2026-09-15) → v4:** Act4Water is a B2B credit standard (no consumer checkout) → dropped from links. Link-outs: charity: water (≈1,100 L/$1 published), Water.org ($5/person), WaterAid India (INR, 80G), BEF Water Restoration Certificates ($4 = 3,785 L; labelled restoration, not offset). Flora corrections: Singapore → Tembusu (rain tree is Neotropical), US generic → Sugar maple (Saguaro is Sonoran-only), Japan → Yoshino cherry (cultivated hybrid, noted). Endangered species with documented water-abstraction threats: Huachuca water-umbel (US SW), Texas wild-rice, Doñana pond grass (EU/Spain), Kathalekan marsh nut (India), Bukit Timah cryptocoryne (Singapore); none verified yet for Nordics/Japan. Store rule: donations must open the charity's site in the browser; no amount/email collected in-app.

**Delivered as prototype v4:** no onboarding; water-drop hero; metaphors in Settings + milestone/per-prompt slide-in alerts; 7-day chart + Insights card (brand × tier, counterfactual saving labelled "roughly") on Today; contextual plant (species × season × health, endangered wetland mode); Neutralize modal. Data model now stores per-day vendor × tier counters (still counts only). Day buckets now use the local calendar day (was UTC).

## Partner feedback round 2 (received 2026-09-15) — vision & UI spec

**Vision (mandatory):** shareable consumer utility for Gen Alpha / Gen Z / tech-forward adults; scientific credibility + short-form virality (TikTok/Shorts/Reels) + campus gamification. Not an ESG calculator.

**Accepted as mandatory (UI/product):**
- System-driven theme via `prefers-color-scheme`, no manual toggle; AAA contrast in both light and dark.
- Single-input onboarding "What is your age?"; layout density adapts to age (larger targets/high contrast for older users; denser, gamified for younger).
- Metaphor library: Youth 10–17 = pixel-art water bucket, milk glass, boba cup, milkshake, smoothie; 18+ unlocks matcha, espresso cup, beer mug, classic coffee mug.
- Universal Dynamic Plant for all ages with health states (thriving → drooping/colour shift → cinematic wilt when limit exceeded).
- "Simulate Heavy Query" 3-second thriving→withered preview for screen recording.
- One-tap 9:16 story export with metaphor-based micro-copy and watermark "Sipcount • Track your AI footprint".
- Campus/Group "Digital Sobriety" leaderboard tab with a shared grove.

**Conflicts / risks needing Madhur's decision (see D-8…D-12 once decided):**
1. *Theme*: our founding constraint was "dark by default to save energy"; she wants system-driven with no toggle. Product owner wins unless Madhur objects; we can still surface an OLED-savings nudge.
2. *Age question*: asking an exact age is fine on-device if we **store only the derived tier, never the number**, and transmit nothing. Bigger issue: **declaring 10–12-year-olds as a target audience** triggers Google Play Families policy (stricter review, restrictions on data/APIs, and it would collide with the VpnService + leaderboard/social features) and India DPDP parental-consent rules if any data ever leaves the device. Recommendation: store rating 13+ ("Teen"); youth tier designed for 13–17; a user who types 10–12 still gets the youth visuals but no social features.
3. *Beer mug*: "alcohol references" in the content-rating questionnaire raise the rating (Teen → potentially 17+/Mature in some regions). Recommend gating behind 21+ or dropping; needs decision.
4. *Leaderboard*: a shared grove across users **requires a server** (or peer sync) — our architecture is zero-retention/no-backend. Options: (a) opt-in, pseudonymous, group-aggregate-only backend (daily mL totals + handle + group code; no prompt data; free tier e.g. Cloudflare Workers/Supabase) — keeps prompt privacy intact but is our first backend; (b) local "friends" leaderboard exchanged via QR/link — no server, clunky; (c) defer. Also: social features + minors ⇒ another reason for 13+.
5. *React/Tailwind deliverables (App.js, Dashboard.js, DynamicPlant.js, ShareModal.js)*: technical choice is ours; Flutter remains the real app. Recommendation: keep the single-file prototype on GitHub Pages (no build step) but structure it as those four named modules so her spec maps 1:1; port to Flutter after.

**Decisions (Madhur, 2026-09-15):** D-8 theme = system-driven, no toggle (product owner), OLED nudge in copy · D-9 official audience **13+**; youth tier 13–17; ages 10–12 typed → youth visuals, social features off; store tier only, never the age · D-10 **beer mug dropped** · D-11 leaderboard **mocked with sample data in v3**; backend decision after her review · D-12 prototype stays **single-file**, structured as App / Dashboard / DynamicPlant / ShareModal.

**Assumptions to confirm (volumes for metaphors, mL):** milk glass 250, boba cup 500, milkshake 400, smoothie 350, matcha 240, espresso 30, beer mug 500, coffee mug 240, pixel bucket = daily budget (fills to 100 %).
**Brand note:** "Minecraft graphic" → generic pixel-art bucket (cannot reproduce the game's assets).

## Partner feedback round 1 (received 2026-09-15) — summary

Target: the **web prototype** at mouliarya.github.io/sipcount (deliverables requested as HTML/Tailwind/JS or React, a JS config object, and micro-copy).

1. Engine — keep dual-scope formula, add regional presets that shift Scope 1 vs Scope 2 (cooling tech × grid mix), add water-stress contextualisation.
2. Visuals — replace static droplet + "sips" with an age-bracket selector that swaps the central visual and unit (potion charges / espresso shots / coffee mugs / 8-oz glasses…), with a senior-accessible mode.
3. Micro-copy — per-tier plain-language explanation of why electricity uses water.

Tracked as I-10, I-11, I-12. Open questions sent to Madhur before implementation.
