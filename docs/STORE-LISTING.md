# Chrome Web Store — everything the submission asks for

*Copy and paste. Written 2026-09-30 against the listing form's actual fields and limits.*

Developer account: **$5, one-off** — Madhur is setting it up. Everything below is ready for it.

---

## The fields

**Name** (45 characters max)
```
Sipcount — see what your AI drinks
```
*(33 characters.)*

**Short description** (132 characters max — this is what people read in search results)
```
Counts the water your AI prompts use. Counts only: it never reads, stores or sends a word of what you type.
```
*(106 characters. The privacy claim goes here deliberately — it is the reason to install.)*

**Category:** Productivity
**Language:** English (United Kingdom)

---

## Detailed description

```
Every prompt you send has a physical cost. The servers that answer it run hot, and the cheapest
way to cool them is to evaporate fresh water.

Sipcount puts a number on yours.

It sits quietly in your browser and counts what you use on ChatGPT, Claude and Gemini. Not
guesses from an average — your prompts, your models, your day.


WHAT IT SHOWS

· Water used today, and how it compares to a budget you set
· Where it went: which AI tool, and which class of model
· The last seven days at a glance
· Work you never see — a research prompt that takes five minutes is doing far more than the
  paragraphs it shows you, and Sipcount counts that too


IT COUNTS. IT DOES NOT READ.

Sipcount measures how LONG your prompt and the reply are. It never sees what they say.

The extension asks for no network permission at all — you can check this on the extensions page.
Without it, nothing can be sent anywhere: no analytics, no telemetry, no account, no server.
Everything stays in your browser, and a button in the popup hands you a copy of everything it
holds about you.


HONEST ABOUT BEING AN ESTIMATE

Nobody outside the AI companies can measure this exactly, and Sipcount does not pretend to. Every
figure is built from published research — Li et al. 2023, WRI 2020, Lawrence Berkeley National
Laboratory 2024, and the vendors' own 2025 disclosures — and the app shows the range as well as
the number.

Water cost depends enormously on where the servers are. Sipcount ships seven regions, from Texas
to Singapore, and India's figure is nearly twice America's. Pick yours in the popup.


FREE, OPEN SOURCE, NO ACCOUNT

github.com/mouliarya/sipcount
```

---

## Privacy tab

**Single purpose** (they check this closely)
```
Sipcount estimates the water used by the AI prompts you send, and shows you the total.
```

**Permission justifications**

| Permission | Justification to paste |
|---|---|
| `storage` | Stores your daily water total, your budget and your region in your own browser. Nothing is sent anywhere — the extension declares no network permission. |
| Host access to chatgpt.com, claude.ai, gemini.google.com | The extension measures how many characters your prompt and the reply contain, in order to estimate the energy and water used. It reads length only; the text is measured and discarded, never copied, stored or transmitted. |

**Remote code:** No.
**Privacy policy URL:** `https://mouliarya.github.io/sipcount/privacy.html`

**Data usage — tick nothing.** Sipcount collects none of the listed categories. Then certify:
- Not being sold to third parties ✔
- Not used or transferred for purposes unrelated to the single purpose ✔
- Not used or transferred to determine creditworthiness or for lending ✔

---

## Images still to make

The listing cannot be submitted without these, and they are the one part I cannot generate.

| Asset | Size | Required | Notes |
|---|---|---|---|
| Store icon | 128×128 PNG | **Yes** | Done — `browser_extension/icons/128.png` |
| Screenshot | 1280×800 or 640×400 | **Yes, at least one** | Up to five. See shot list below. |
| Small promo tile | 440×280 | No | Only needed for featuring |

**Shot list** — take these at 1280×800 with the popup open:

1. **A normal day.** Popup open over a ChatGPT conversation, a few hundred millilitres, drop part-full, green. This is the hero shot.
2. **A heavy prompt just landed.** The last-prompt line showing a research turn and the unseen work. This is the thing no other tool does.
3. **Over budget.** Red pill, drained drop, so the mechanic is visible.
4. **Region set to India** with the "a typical prompt ≈ 2.33 mL" line showing — proof it is not a US-only number.
5. **Optional:** `chrome://extensions` details showing storage as the only permission. Unusual, and it makes the privacy claim checkable rather than asserted.

---

## Before submitting — check each one

- [ ] Version bumped in `manifest.json` (currently `0.3.0`)
- [ ] `node docs/test/regression.js · parity.js · extension.js · simulate.js · constants.js` all green
- [ ] **Remove the test bridge**, or confirm it stays gated behind `?sipcount_debug=1` — it is gated today, and it should be a deliberate decision, not an oversight
- [ ] Calibration mode defaults to off
- [ ] `privacy.html` actually live at the URL above (push, then open it)
- [ ] Load the packed `.zip` unpacked one last time and send a real prompt
- [ ] Zip `browser_extension/` **without** `TESTING.md` and `INSTALL.md`

## What review will probably ask about

**The host permissions.** Three AI sites, with a content script reading page text, in an extension
claiming it reads nothing. The justification above answers it directly: length only, discarded
immediately. Having no network permission is the strong part of the argument — an extension that
cannot reach a server cannot exfiltrate anything, and that is checkable rather than promised.

**Turnaround** is usually days rather than weeks for a small extension with no remote code, but a
first submission from a new account is often slower. Expect a fortnight and be pleased if it is less.
