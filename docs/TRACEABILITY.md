# Requirement traceability

*Every agreed requirement, what state it is actually in, and the test that proves it. One line per
requirement. Updated at the end of every build — a requirement with no test in the last column is
**not done**, whatever anyone said in a chat.*

Last updated 2026-09-30.

**Why this exists:** on 2026-09-29 the extension was reported as "working" after it counted two real
prompts. Against its own written specification (`TOKEN-ECONOMICS.md` §4, I-18) it was doing about a
third of its job — the reply, which is ~99% of the number, was a fixed assumption. Nobody checked
the build against the spec, because nothing existed to check it against. On 2026-09-30 a build was
announced as started and then not written at all. Both are the same failure.

**Status key:** ✅ built and proven · 🟡 built, not proven · ⬜ not built · ⏸ deliberately deferred

---

## A. The number itself

| # | Requirement | Agreed | Status | Proof |
|---|---|---|---|---|
| N1 | One calculator shared by prototype, extension and phone app | I-16, 2026-09-27 | ✅ | `parity.js` — 252 combinations agree exactly |
| N2 | Generated files cannot drift from `engine.js` | 2026-09-27 | ✅ | `parity.js` regenerates and fails if stale |
| N3 | Seven regions everywhere, including India | I-16 | ✅ | `parity.js`; India 2.334 mL vs US 1.296 |
| N4 | Output tokens weighted above input | D-22 | ✅ | `parity.js`, `water_calculator_test.dart` |
| N5 | The 5× multiplier is replaceable in one line | D-22 | ✅ | `parity.js` — holds at 3× / 5× / 8× / 10× |
| N6 | **Measure what goes out** (prompt length) | TOKEN-ECONOMICS §4 | 🟡 | measured as characters; `extension.js`. **Not exact tokenisation — see N8** |
| N7 | **Measure what comes back** (reply length) | TOKEN-ECONOMICS §4, I-18 | ✅ | built 2026-09-30, `extension.js` 24 assertions. Live run found it finalising mid-answer (190 of 4,000 chars) — now waits on the stop control and reports cumulatively. **Verified live 2026-09-30**: a 5-minute research turn read 1.06 mL before and 120.59 mL after |
| N8 | Exact tokenisation, not characters ÷ 4 | TOKEN-ECONOMICS §2 | 🟡 | script-aware ratios shipped 2026-09-30 (`parity.js`): a Hindi answer was under-counted by **25%**, CJK by far more. Fully Romanised Hinglish still reads as English — only a real tokenizer fixes that |
| N9 | Timing → work that never reaches the screen | TOKEN-ECONOMICS §4 | ✅ | `hidden ≈ rate × active time − visible output`. Madhur's 5-minute research turn read **1 mL**; it is worth ~**176 mL**. `parity.js` (9), `simulate.js` §8. Duration, not TTFT — a research turn streams "Searching…" at once while working for minutes more |
| N10 | Context-length factor | TOKEN-ECONOMICS §3 | ✅ | built 2026-09-30, `parity.js` (7). Each output token re-reads the thread, so the same answer costs 1.4× at 8k of context and 2.5× at 30k. Fresh chats and the reference prompt are untouched. Capped at 4×, publishable, re-fittable. **Cached-history discount still ⬜** |
| N11 | Calibration: record, protocol and fitter | I-18 / I-30 §5 | ✅ | built 2026-09-30, `extension.js` (7). Off by default; a switch in the popup, one row per turn — counts, scripts and timings, capped at 500, no text. Export gives the CSV. `docs/calibration/PROTOCOL.md` is the 20-prompt scripted run; `tools/fit-calibration.js` reads the export and proposes the constants. `fit.js` (10) proves the fitter recovers rates it was never told, within 3.4% |
| N12 | Coefficients published so every app picks them up | I-20 | 🟡 | `docs/constants.json` + `applyConstants()`, `constants.js` (22). Numbers only, re-checked against physical bands, **fail closed**: wrong schema, unknown region/tier, NaN, Infinity, a string where a number belongs, or one bad value among good ones — all rejected whole. **Still to wire: the periodic fetch** in the phone and desktop builds (never at launch; bundled values as fallback; off for under-18). **Not in the extension** — that would need a host permission and cost the "no network permission" claim, and Chrome's auto-update already carries constants (D-31) |
| N13 | Model → tier from the on-screen label | — | ✅ | live-verified: Flash→light, Opus→standard, o3→reasoning |

## B. Browser extension

| # | Requirement | Status | Proof |
|---|---|---|---|
| E1 | Installs and the service worker starts | ✅ | `parity.js` loads engine + background in one scope (I-43) |
| E2 | Detects a send on all three sites | ✅ | live: Claude ✅, Gemini ✅, **ChatGPT ✅ 2026-09-30** — the site that counted nothing at all until 29 Sep |
| E3 | Counts the right amount | ✅ | live 2026-09-29: 1.5 mL vs 1.47 mL predicted |
| E4 | Region selectable, India included | ✅ | live-verified in the popup |
| E5 | One send = one count under fast repeated use | ✅ | three prompts in quick succession on ChatGPT counted exactly three, 2026-09-30. Also covered in `simulate.js` §4 |
| E6 | Never captures prompt or reply text | ✅ | `extension.js`; manifest declares no network permission |
| E7 | Popup carries the agreed design | ✅ | rebuilt 2026-09-30 in the app's language — true black, one green, the draining drop, the app's own opportunity-cost line instead of "4.1 espressos", colour-blind zone pills. Checked visually at both a normal day and an over-budget day |
| E8 | Icons | ✅ | 16/32/48/128 generated from the app's drop; declared in the manifest. Flat fill at 16 and 32 — a highlight turns to mush at that size. Checked at true size, not just as files |
| E9 | Privacy policy at a public URL | ✅ | live and confirmed 2026-09-30 at `mouliarya.github.io/sipcount/privacy.html`, linked from the popup |

## C. Phone and desktop

| # | Requirement | Status | Proof |
|---|---|---|---|
| P1 | Android counts prompts in shipping form | ⬜ | I-22 spike not run; needs test phones |
| P2 | Dart engine agrees with `engine.js` | ✅ | **verified by CI 2026-09-30.** `flutter analyze` + `flutter test` green against golden values generated from `engine.js`. The Dart was written without ever being executed, so this was the one claim in the project made on trust; it is now made by machine |
| P3 | iPhone (lighter: Safari + Screen Time) | ⬜ | needs the $99 account |
| P4 | iPhone (full: traffic tunnel) | ⏸ | needs the company |
| P5 | Desktop counts the native apps | ⬜ | design agreed, `DESKTOP-SENSING.md` |
| P6 | Day totals sync across devices | ⏸ | built, shipped dark until 1.1 |

## D. Product decisions from the pre-build review

All fifteen are in `PRE-BUILD-REVIEW.md` §8 and all are ✅, each with an assertion in
`regression.js` — charity cut, demo gate, simulate estimate-only, share gated under 13, softened
states, British spelling, first-run card, stage 0–1 lines, widget logged, About rewritten, captions,
scale line, contrast, dead code, sync dark.

---

## The three suites

Run all three before any push. Anything below that is not a check.

```
node docs/test/regression.js   # 120 — the prototype: screens, copy, behaviour
node docs/test/parity.js       #  51 — one calculator; scripts; unseen work; context; the extension starts
node docs/test/extension.js    #  40 — counting, correction, calibration, midnight, tabs, unknown models
node docs/test/simulate.js     #  17 — a whole conversation: streaming, pauses, agentic turns
node docs/test/constants.js    #  22 — a published coefficient reaches apps; a bad file cannot
node docs/test/fit.js          #  10 — the calibration fitter recovers a rate it was never told

`docs/STORE-LISTING.md` holds every field the Chrome Web Store submission asks for.
```

`simulate.js` runs the real `content.js` and `background.js` against a jsdom page where an answer
streams in chunk by chunk with pauses, so the faults that only appear in a live conversation —
finalising during a pause, Gemini's cumulative chunks, the engine missing from the page — now have
a test each. Timers run 50× faster, so the whole conversation suite takes seconds.

**None of them sees pixels, and none of them visits a real website.** Live behaviour is checked by
driving Chrome against the three sites — that is how E2, E3 and N13 were proven, and it is the only
way N7 will be. `browser_extension/TESTING.md` is the manual version.

## Open at the top of the list

2. **N8** — Romanised Hinglish still reads as English; the scripted run now solves this offline, no tokenizer in the extension
1. **The rate is a placeholder.** 90 tokens/s, from a 70–125 range — the second guess after the 5×, and the same calibration (I-30) replaces both. A research turn is worth 144 mL at 70 and 251 mL at 125.
3. **E5** — double counting under fast repeated sends
4. **N12 fetch** — the periodic pickup in each product; the file and its validation exist, nothing downloads it yet
5. **P2** — run the Dart tests in CI; they have never executed
