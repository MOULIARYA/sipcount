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
| I-10 | **Partner feedback — engine: regional presets (EU, Nordic hydro, US-ERCOT, India, APAC) + water-stress (WRI Aqueduct) toggle** | Open — questions pending | Formula already is Li et al. dual-scope (Scope 1 = E×PUE×WUE_site, Scope 2 = E×PUE×EWIF). Missing: sourced regional constants, cooling-tech variants, stress index. Several regional EWIFs are not published at grid level → will carry "low confidence" labels. |
| I-11 | **Partner feedback — age-adaptive visual metaphors & units (10–17 / 18–35 / 36–59 / 60–100)** | Open — questions pending | Brand-specific visuals (Minecraft, Stanley, Hydro Flask, Apple Health rings) cannot be reproduced; generic equivalents proposed (pixel bucket, big tumbler, insulated bottle, progress ring). |
| I-12 | **Partner feedback — senior accessibility: large print, WCAG 2.1 AAA contrast, ≥48 px touch targets, no jargon** | Open | Applies to prototype first, Flutter app after. |
| I-13 | Possible false positive: clearing a typed prompt with select-all + delete counts as a send | Open | Inherent to text-clear detection; measure frequency in testing before mitigating. |
| I-14 | GitHub MCP connector not available in Cowork (only "GitHub Integration" for Projects) | Open (process) | Ask Xebia admin to enable the GitHub connector; until then pushes go through Chrome web upload. |
| I-15 | Sandbox shell broken by Windows update (2026-09-08) → no local compile/test, no zip, no keytool | Open (environment) | All verification is by review + CI. |

## Partner feedback (received 2026-09-15) — summary

Target: the **web prototype** at mouliarya.github.io/sipcount (deliverables requested as HTML/Tailwind/JS or React, a JS config object, and micro-copy).

1. Engine — keep dual-scope formula, add regional presets that shift Scope 1 vs Scope 2 (cooling tech × grid mix), add water-stress contextualisation.
2. Visuals — replace static droplet + "sips" with an age-bracket selector that swaps the central visual and unit (potion charges / espresso shots / coffee mugs / 8-oz glasses…), with a senior-accessible mode.
3. Micro-copy — per-tier plain-language explanation of why electricity uses water.

Tracked as I-10, I-11, I-12. Open questions sent to Madhur before implementation.
