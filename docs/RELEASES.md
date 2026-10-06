# Released versions, and what each one carries

*Every artefact that has left this repository, and exactly which constants, prototype contract and
sensing method it holds. So that when something changes we can answer, in one look, **which builds
in the wild are affected and what has to happen to them**.*

Last updated 2026-10-06.

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
| unpacked dev | 2026-09-30 → | 2026-09-30 | DOM: prompt + reply + unseen work | 🟢 | Reloaded by hand. Per D-31 the extension **never fetches constants** — Chrome's auto-update is the delivery channel, so a re-fitted coefficient needs a version bump, not a server |

**Compatibility note that will matter at launch:** because the extension cannot fetch, every
constants change is a store release. That is a deliberate trade — "declares no network permission"
is the centre of the privacy claim — but it means the field can lag by however long review takes.

---

## Android

| Build | Released | Constants | Prototype contract | Sensing | Status | Notes |
|---|---|---|---|---|---|---|
| APK #18 | 2026-09-30 | 2026-09-30 | 11 | accessibility listener | 🔴 | **Class C.** Budget defaulted to 100 mL (agreed 500) and region defaulted to `us_default`, an id that no longer exists — so the first prompt counted would have thrown (I-59). Superseded; do not use |
| APK #19, #20 | 2026-10-01 | — | — | — | ⚫ | Never built: compile errors (I-53) |
| next APK | pending | 2026-09-30 | **15** | accessibility listener + probe spike | 🟡 | **The port (I-63).** Four screens, the draining drop, the characters on Mouli's art, insights, analytics, fact cards, the Simulate estimator, the About copy, the intro age band. Also fixes I-59, raises the budget to 500, retires the Scope 1/2 wording, gates the demo row and the probe behind `SIPCOUNT_DEMO`, and brings the phone's calculator up to the shared engine (I-62). **Class B for anyone on APK #18**: their stored totals are fine and carry forward, but a day recorded before this build has no brand breakdown, so the insights card simply says so rather than guessing |

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
