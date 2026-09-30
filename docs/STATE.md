# Sipcount — state of play

*The one page to read before starting work, and to update before finishing. If something important
is only in a chat, it does not exist. Last updated 2026-09-27.*

---

## How we work in parallel

Several tracks run at once, in separate sessions. They stay in step through the repo, not through
anyone remembering:

1. **Start** by reading this file and `ISSUES.md`. **Finish** by updating both.
2. **Anything two tracks share needs a test that fails when they drift.** `engine.js` has one
   (`docs/test/parity.js`). Copy that pattern for the next shared thing; do not rely on care.
3. **Before any push, on every track:** `node docs/test/regression.js` and `node docs/test/parity.js`.
   Report the counts. Neither has a layout engine, so neither replaces opening the thing on a device.
4. **Generated files are never hand-edited** — `browser_extension/engine.js` and
   `app/assets/calc/models.v2.json` come from `node tools/build-shared.js`.
5. **Business decisions come from Mouli**, and land here or in `ISSUES.md` with a date and a reason.

---

## Tracks

| # | Track | Status | Blocked on |
|---|---|---|---|
| **A** | **Browser extension** (Chrome/Edge) | Active | — |
| **B** | **Desktop** (Windows first, macOS next) | Ready to start | macOS only: the Apple account |
| C | **Android** | Waiting | Three test phones |
| D | **iPhone** | Waiting | $99 Apple account; full version also needs the company |
| **E** | **Company, accounts, compliance** | **Active — start now** | Nothing. Longest lead times in the programme. |
| S | **Shared** — engine, prototype UI, docs | Active | — |

Open a session per active track. Add C and D when their blockers clear, not before.

### A · Browser extension
**Counting is proven.** 2026-09-29: two real prompts on Claude and Gemini counted 1.5 mL against an
independent calculation of 1.47 mL, with the model tier read correctly on both (I-8). That is the
first evidence the product works at all, on any surface.

Next, in order — port the prototype's design into the popup (I-44: it is still the September blue
design with no character and an "≈ 0.1 of a sip" line); icons (I-9); privacy policy at a public URL;
store listing and the $5 account. Still unproven: ChatGPT logged in, click-to-send on Gemini,
double-counting under fast repeated sends.

### B · Desktop
Counter, not viewer (D-30). Per-process network byte counters as the primary signal, frontmost app
as support, local proxy held in reserve, UI reading rejected. Tauri. Copilot deferred — it has no
process of its own. Design in `docs/DESKTOP-SENSING.md`. **Also the calibration instrument for the
5× multiplier (D-25), which is why it earns priority over its user numbers.**

### C · Android
Sensor spike first (I-22, seven experiments, three phones), then the signing key (I-2 — a throwaway
key after release is unfixable), then port the interface to Flutter, then Play paperwork (I-23) and
the children's-app rules.

### D · iPhone
Lighter version on an individual account: Safari extension plus a Screen Time estimate. Full version
needs the traffic tunnel, which Apple only allows from an organisation account. `SENSING-REVIEW` §8.

### E · Company, accounts, compliance
Not code, and the critical path anyway — longest waits, least visible progress, easiest to neglect.
Full sequence, dependencies and costs in `docs/COMPANY-AND-COMPLIANCE.md`. Two things to know:
**a personal Play account needs no D-U-N-S**, so Android need not wait for the company — only the
full iPhone build genuinely does; and **buy OV code signing, not EV** (Microsoft removed EV's
instant SmartScreen trust in 2024, so both build reputation the same way).

### S · Shared
`engine.js` is the only place the maths lives. The prototype (`sipcount.html`) is the reference
design every product ports from. Docs and decisions live here.

---

## Waiting on Madhur

Track E has the full list. The four that cannot be started by anyone else:

- ⚖️ **Read the Xebia employment contract** before registering anything — IP and moonlighting
  clauses are far cheaper to resolve now than after a company exists and a product ships
- ⚖️ **Founders' agreement with Mouli** — several weeks into real work, clear division of labour,
  no document
- **Buy the $99 Apple account and the $5 Chrome Web Store account** — unblocks two surfaces today
- **Order three test phones** — Pixel, Samsung, budget MediaTek — gates track C

---

## Settled, do not re-argue

Full reasoning in `ISSUES.md`; this is the index.

| | |
|---|---|
| Rolling release | Five surfaces, each ships when ready. Nothing waits for the slowest. |
| v1 cuts | Charity feature out (D-1b); sync built but dark (1.1); demo controls behind `?demo=1` |
| Sync design | Pair code, no accounts; per-device day buckets that cannot overwrite each other; 18+ only |
| Sign-in | Google/Apple is Phase 2, recovery only — `docs/SYNC-AND-ACCOUNTS.md` |
| Desktop | Counter not viewer; Windows and macOS both (D-30) |
| Output tokens | 5× input is a **placeholder** until measured (D-22). One constant, everything derives from it, proven safe to swap at 3× / 5× / 8× / 10×. |
| Simulate | Never writes to today's total |
| Age | Under 18 no sync; under 13 no sharing and the character never reaches its worst state |

---

## Known risks worth re-reading before release

1. **Nothing counts anything yet in shipping form.** The interface is finished; the sensor is the
   product, and it is the least finished part. Track C's spike is the only thing that can still
   force a rethink.
2. **The personal number is small** — a few hundred millilitres — and a small number shown alone
   argues against caring. Carried by the characters, the facts, and the scale line.
   `PRE-BUILD-REVIEW.md` §7.
3. **Endpoint security** may block per-process network reads on managed laptops (track B).
4. **The Dart engine has never been run** by anyone here. Written and checked against the real
   numbers, but CI has to go green before it is trusted.
5. **Neither test suite sees pixels.** Every visual bug that reached Mouli this month was of a kind
   they cannot catch.
