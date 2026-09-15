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

Open before building D-1: (a) half-day spike measuring bytes↔tokens and TTFB↔tier using the extension; (b) iOS Network Extension entitlement request to Apple (weeks); (c) VPN permission wording/UX; (d) finish & test the extension first (I-8) since it is the calibration instrument.

## Partner feedback (received 2026-09-15) — summary

Target: the **web prototype** at mouliarya.github.io/sipcount (deliverables requested as HTML/Tailwind/JS or React, a JS config object, and micro-copy).

1. Engine — keep dual-scope formula, add regional presets that shift Scope 1 vs Scope 2 (cooling tech × grid mix), add water-stress contextualisation.
2. Visuals — replace static droplet + "sips" with an age-bracket selector that swaps the central visual and unit (potion charges / espresso shots / coffee mugs / 8-oz glasses…), with a senior-accessible mode.
3. Micro-copy — per-tier plain-language explanation of why electricity uses water.

Tracked as I-10, I-11, I-12. Open questions sent to Madhur before implementation.
