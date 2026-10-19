# Released versions, and what each one carries

*Every artefact that has left this repository, and exactly which constants, prototype contract and
sensing method it holds. So that when something changes we can answer, in one look, **which builds
in the wild are affected and what has to happen to them**.*

Last updated 2026-10-19.

**Why this exists.** On 2026-10-05 Madhur asked whether all released versions stay compatible when
things change, and I could not answer a basic version of that question: *which builds are out there
carrying the old 100 mL budget?* We tracked requirements and we tracked tests, but nothing tracked
what was actually in people's hands. A release register is the difference between "we fixed it" and
"we fixed it for everyone who has it".

**Status key:** 🟢 current · 🟡 superseded but still installed somewhere · 🔴 broken in the field,
needs a forced update · ⚫ withdrawn

---

## The rule this file exists to enforce

Every change is classified before it merges:

| Class | Meaning | What it obliges |
|---|---|---|
| **A — forward only** | new behaviour, old builds keep working correctly | nothing; next release carries it |
| **B — old builds now under-report** | the number in the field is wrong but not absurd | a release, and a note here; no user action |
| **C — old builds are blind or badly wrong** | a site redesign, a renamed constant, a dead region id | a release **plus** the in-product alarm so the user knows before we do |
| **D — old builds cannot be fixed by a release** | a store policy change, an API withdrawal | a decision recorded in `ISSUES.md` and a migration path, before the change lands |

The budget and region faults (I-58, I-59) were **class C** and we had neither the register nor the
alarm. That is now what the extension's health card and this file are for.

---

## Browser extension (Chrome)

Nothing is in the Chrome Web Store yet — submission is parked pending the account decision with
Mouli (see `STORE-LISTING.md`). The only copies in the field are unpacked developer loads on
Madhur's machine, so the only compatibility question today is between his loaded copy and `main`.

| Version | Released | Constants | Sensing | Status | Notes |
|---|---|---|---|---|---|
| unpacked dev **0.4.0** | working tree 2026-10-19, not pushed | 2026-09-30 | DOM: prompt + reply + unseen work | — | **Rel 1.4 (Chrome only, per Madhur).** I-69 interim thinking-level rule; `resolveTier` now lives in `engine.js`; the model check accepts level labels (High / Medium / Low / Instant / Argon). Reload the unpacked extension after pulling. Class B → fixed for ChatGPT/Gemini High turns |
| unpacked dev **0.3.0** | 2026-09-30 → (last extension change on `main`: `a32e883`, 2026-10-06) | 2026-09-30 | DOM: prompt + reply + unseen work | 🟢 | Confirmed 2026-10-19: `manifest.json` 0.3.0 on `main` (`b9fa1f7`); no extension change since. Any copy loaded or reloaded after 2026-10-06 is current; one loaded earlier is not (the version number was not bumped, so `chrome://extensions` cannot tell them apart). Reloaded by hand. Per D-31 the extension **never fetches constants** — Chrome's auto-update is the delivery channel, so a re-fitted coefficient needs a version bump, not a server. **Class B since 2026-10-07 (I-69):** ChatGPT's GPT-6 Thinking levels (Medium / High / Extra High) are priced as standard and pass the model check, so H4 does not warn — a silent under-count of thinking turns ("Pro" is priced correctly; re-scoped 2026-10-13). **Widened 2026-10-19:** Gemini's High thinking level on Pro/Argon is priced as standard too (default Low is correct); still class B. The fix ships with the next reload |

**Compatibility note that will matter at launch:** because the extension cannot fetch, every
constants change is a store release. That is a deliberate trade — "declares no network permission"
is the centre of the privacy claim — but it means the field can lag by however long review takes.

---

## Android

| Build | Released | Constants | Prototype contract | Sensing | Status | Notes |
|---|---|---|---|---|---|---|
| APK #18 | 2026-09-30 | 2026-09-30 | 11 | accessibility listener | 🔴 | **Class C.** Budget defaulted to 100 mL (agreed 500) and region defaulted to `us_default`, an id that no longer exists — so the first prompt counted would have thrown (I-59). Superseded; do not use |
| APK #19, #20 | 2026-10-01 | — | — | — | ⚫ | Never built: compile errors (I-53) |
| **next APK (#33) — "Rel 1.4b"** | pending (working tree 2026-10-19, not pushed) | 2026-09-30 | 15 | as #30 | — | **I-76:** run 32 built the APK but its boot check failed on a `sh`/bash mismatch before launching anything, so nothing was published (correct behaviour of the gate, wrong script). Script moved to a file; pipeline now checked by `ci.js`. **I-75:** storage plugin pinned back to the version build 29 shipped (`shared_preferences_android` 2.4.28); the APK is boot-checked on an emulator before publishing. Installs over #31 and keeps all data. **Check on the phone: the app opens.** |
| **APK #31 — "Rel 1.4a"** | 2026-10-19 | 2026-09-30 | 15 | as #30 | 🔴 | **I-74 fix worked — the error screen appeared instead of a frozen logo — and named the real fault: `NoSuchMethodError` inside `shared_preferences_android` 2.5.0, a dependency that moved under us (I-75). Class C: the app does not open. Superseded by #32; do not use #31.** The screen comes first, Android checks after; 8 start-up tests in CI. |
| **APK #30 — "Rel 1.4"** | 2026-10-19 | 2026-09-30 | 15 | **estimate mode (Usage Access, default) + accessibility listener (optional): prompt + reply + active time** | 🔴 | **Froze on the launch logo on Madhur's phone (I-74) — the start-up chain awaited an Android call before drawing anything. Class C: the app does not open. Superseded by #31, which fixes it and installs over the top; do not use #30.** — **I-73:** estimate mode — minutes in ChatGPT/Claude/Gemini become estimated prompts at a published placeholder rate (0.5/min), kept apart from measured counts, the Today card says *includes an estimate*; needs the Usage Access permission; works next to banking apps (I-72). **I-70:** the listener measures the answer's length and how long the model worked, and corrects the turn — the extension's rule. **I-71:** earned characters are stored and a day with no counted prompts no longer breaks the unlock run. **I-69 interim:** High/Extra High thinking levels price as reasoning. **Class A** for anyone on #29: stored days carry forward, earned characters are recomputed from history on first launch; the manifest gains `PACKAGE_USAGE_STATS`, which Play Protect does not flag. **Unverified until CI is green, ten minutes of Gemini shows ~5 estimated prompts, and one long answer per app is checked on Madhur's phone** |
| **APK #29** | **2026-10-07** (commit `b9fa1f7`, CI pre-release `android-latest`, "Sipcount Android — build 29") | 2026-09-30 | **15** | accessibility listener: **prompt only** | 🟢 | Confirmed 2026-10-19 from the GitHub release record — this row was still saying "pending" twelve days after it shipped. Carries the port described below. **Class B in the field:** every reply is priced at the assumed 300 tokens, so long answers under-read (I-70); characters are taken back when a streak breaks and a quiet day breaks it (I-71); Accessibility conflicts with banking apps (I-72) |
| *(the port, as built into #29)* | — | 2026-09-30 | **15** | accessibility listener | — | **The port (I-63).** Four screens, the draining drop, the characters on Mouli's art, insights, analytics, fact cards, the Simulate estimator, the About copy, the intro age band. Also fixes I-59, raises the budget to 500, retires the Scope 1/2 wording, gates the demo row and the probe behind `SIPCOUNT_DEMO`, and brings the phone's calculator up to the shared engine (I-62). **Class B for anyone on APK #18**: their stored totals are fine and carry forward, but a day recorded before this build has no brand breakdown, so the insights card simply says so rather than guessing |

**Distribution:** sideloaded APK only, and that channel is now effectively closed in India — Play
Protect blocks sideloaded apps declaring `ACCESSIBILITY` (I-57). Testing moves to the Play internal
testing track, which needs the developer account.

---

## iOS, Windows, macOS

Nothing released. iOS cannot use the Android sensing design at all — no accessibility equivalent
exists — and shipping a tunnel there requires an Organization developer enrolment under ASRG 5.4
(I-60). See `PLATFORM-RESEARCH-LOG.md`.

---

## Web prototype

| Version | Released | Contract | Status | Notes |
|---|---|---|---|---|
| GitHub Pages, `main` | continuous | 15 | 🟢 | mouliarya.github.io/sipcount — the reference design. Mouli reviews here, so this is always ahead of the apps; the gap is tracked by the contract stamp in `app/lib/app/ui_contract.dart` and enforced by `parity.js` |

---

## What a release has to do

1. Classify the change (A–D above).
2. Bump the artefact version and record it here, with its constants version and prototype contract.
3. If class C or D, say in the row what the field needs — and check the in-product alarm covers it.
4. Run every suite in `docs/TRACEABILITY.md`, including `traceability.js`, which will fail if this
   file or the matrix has fallen behind.
