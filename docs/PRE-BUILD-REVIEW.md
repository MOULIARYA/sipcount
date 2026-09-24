# Sipcount — full review before we build

**Date:** 2026-09-23 · **Reviewed:** every screen, every string, every workflow in `sipcount.html` + `engine.js`
**Purpose:** Madhur's call — "most likely we are at the last leg of the UI and we will go to build, so I want to be sure."

---

## The verdict in one paragraph

The app is in good shape. The story-first dashboard works, the characters carry real emotional weight, the numbers are sourced and defensible, and the copy is mostly plain and warm. There are **two things that are actually wrong** (both fixed today), **six contradictions** where one part of the app argues with another, **a first-run experience that shows new users fake data**, and **one strategic risk that matters more than all of it**: the honest number is small, and a small number shown alone argues *against* caring. That last one is a product decision, not a bug, and it should be made on purpose before build starts.

---

## 1. Wrong, and fixed today

### 1.1 The privacy promise stopped being true

The age screen said *"nothing leaves this device"* and Settings said *"Nothing you type ever leaves this device. We keep daily totals and your preferences here, and nothing else."* Adding sync made both false for anyone who turns it on.

Fixed. The claim is now the narrow one, which is true for everybody and is the stronger claim anyway:

- Age screen: *"Nothing you type is ever stored, here or anywhere."*
- Settings → Privacy now says plainly what syncing sends (daily totals, encrypted, date is the finest time recorded, never prompts or email or age), that it's 18+, and that it's off until switched on.

Three regression assertions now guard this, so the promise can't quietly drift out of line with the feature again.

### 1.2 The LBNL figure was 3% low

The intro said 64 billion litres; LBNL's 2024 report says **66 billion**. Corrected, and the wording tightened from *"just to cool"* to *"consumed on-site"* — LBNL's 66 bn is direct consumption, and the report carries a much larger indirect figure for the electricity behind it. "Just to cool" invited a correction we'd have lost.

---

## 2. Contradictions — where the app argues with itself

### 2.1 "Neutralize My Footprint" — the button promises what the modal denies ⚠️ highest risk

The About page ends with a button labelled **Neutralize My Footprint**. Open it and the copy says the giving *"is **not** a scientific offset of your AI use."*

The label makes a claim the body immediately retracts. For an app whose entire value is honesty about numbers, this is the one screen that undercuts it — and "neutralize" is exactly the kind of wording advertising regulators have been taking apart in green claims.

**Recommendation:** rename to **"Put water back"** or **"Support water projects"**, and make the honesty the headline rather than the disclaimer. Nothing else about the feature needs to change.

### 2.2 New users are shown fake data

`loadSample()` fires whenever an install has no days recorded. So a brand-new user's very first screen shows a full week of prompts they never sent, a 12-day streak they never earned, and a character reacting to fiction. There is a small grey line saying it's sample data — under the hero number, in the smallest type on the page.

For a demo this is exactly right. Shipped, the first screen of a product built on "we'll tell you the truth about numbers" would be showing invented numbers.

**Recommendation:** sample data behind an explicit switch (`?demo=1` and the Settings button), never automatic. This also means the genuine empty state finally gets designed and tested — see 3.2.

### 2.3 "Try a prompt" is also a logger

The Simulate screen is framed as a what-if: the title is *Try a prompt*, the paste box says *"Measured, never saved."* Then the primary button is **Log it**, which permanently adds to today's real total.

In the shipped app prompts are counted automatically by the sensor. A manual button that inflates your real number is a different feature wearing the simulator's clothes, and it lets someone accidentally corrupt the one number the app exists to keep honest.

**Recommendation:** in the release build, Simulate estimates only. `Log it`, `+10 prompts` and `30-min session` become demo-mode affordances alongside the sample data.

### 2.4 A leftover three-stage character system

`plantState()` still returns `Thriving / Drooping / Wilting` from before the five-stage art landed, and its thresholds read backwards (50–70% is "Drooping", 70%+ is "Wilting"). It survives in one insight branch. The real system is `stageOf()` — one calculation driving both the picture and the words, five stages each.

No user-visible wrong text today, but it's a trap for whoever builds the Flutter version. Delete it and use `stageOf()`.

### 2.5 The age question does almost nothing

`isEdu()` and `S.social` are referenced in exactly one place in the whole app: a label in Settings. `S.social` exists to gate sharing for under-13s and **doesn't actually gate anything** — a 9-year-old can generate and share an image.

Until today the app asked every user a personal question on first launch and did nothing with the answer. It now genuinely earns its place through the 18+ sync gate — but the question should either do more or ask for less.

**Recommendation:** keep the question (it's now load-bearing, and it's good practice for a mass app), and make it pay for itself: actually gate Share under 13, and soften the character's distressed states for the youngest band.

### 2.6 Mixed spelling

The About page uses American spelling — *data centers, liters, Neutralize*. The rest of the app, including every fact and the new intro, uses British — *litres, centres*. Pick one and sweep. Given the audience and the existing weight of the app, British.

---

## 3. Workflow gaps

### 3.1 Nothing tells a new user how water gets counted

This is the biggest hole. After the intro and the age question, the user lands on a dashboard showing a number. Nothing anywhere explains **that the app watches for AI prompts and counts them automatically** — which is the entire product. In the prototype you can only make the number move by going to Simulate and pressing a button, so a first-time user's honest conclusion is "this is a calculator."

On Android this is worse, not better: the sensor needs an explicit permission, and permission screens that arrive without a reason get declined.

**Recommendation:** one card on the dashboard for the first run — *"Sipcount is watching for your prompts. Use ChatGPT, Claude or Gemini and come back."* On the real build that card is where the permission ask lives, with the reason attached.

### 3.2 The empty state has never been designed

Because sample data always loads, nobody has seen 0 mL, a pristine character and "nothing yet today". That's the state most users will be in for their first hours — the state that decides whether they come back. It needs to feel like a beginning, not an error.

### 3.3 The character says nothing for the first half of every day

`ecoLine` only renders at stage ≥ 2, i.e. above roughly 40% of budget. Below that the character has a status word and no sentence. That's precisely the window a new or careful user lives in — the people we most want to reward.

**Recommendation:** give stages 0 and 1 a line too. They don't have to be dramatic; *"Pip has everything it needs today"* is enough, and it makes restraint feel seen rather than ignored.

### 3.4 Four demo controls are in the shipped UI

`Unlock all`, `+10 prompts`, `30-min session`, `Load sample week`. All useful now, all need a single demo-mode gate before release rather than four separate deletions.

### 3.5 The widget card promises platform work that doesn't exist yet

The dashboard offers *"Add Sipcount to your home screen"* and Settings offers *"Add widget"*. On the web prototype both open a preview with instructions. If the Flutter widget slips out of v1, these two entry points have to go with it, or the app is advertising a feature it doesn't have.

---

## 4. Copy and tone

**The About page is in a different voice from the rest of the app.** Everywhere else Sipcount is plain, warm and short — *"See what your AI drinks"*, *"Pip is looking a little thirsty"*. About is title-cased and marketing-register: *"The Cloud is on the Ground"*, *"The Goal: Digital Sobriety"*, *"Stop guessing. Start tracking your sips."*

It reads well on its own. It doesn't read like the same product. And **"digital sobriety" is jargon** — for a mass audience it's an odd, faintly clinical phrase, and the app spends the rest of its copy carefully avoiding exactly this kind of language. It appears in the weekly report and a share caption too.

**Recommendation:** one pass to bring About into the app's own voice, and retire "digital sobriety" as a user-facing phrase. It's a good internal name for the idea. It isn't how a 19-year-old describes anything.

**Smaller:**
- Share captions mention *"finals week"* — a US college calendar reference, in an app aimed at a global audience with India as a core market.
- The status words are genuinely good across all five characters. Leave them alone.

---

## 5. Accessibility and polish

| Item | Finding |
|---|---|
| `--dim: #6E6E6E` on `#070707` | **3.9 : 1** — below the 4.5 : 1 AA minimum. Used for "15 DAYS ALIVE" and the intro's source line, both ~10–12px. Lighten to about `#8A8A8A` (≈ 6 : 1). |
| `--muted: #A6A6A6` | 8.3 : 1 — fine. |
| Intro overlay | Cards are `aria-hidden` with a full narration on the dialog, which is right. Focus should move to **Skip** when it opens. |
| Colour-blind safety | Already handled — `ZONE_UI` pairs every colour with an icon. Good. |
| Reduced motion | Handled throughout, including the new intro, which keeps the content and drops the animation. Good. |
| Large-print mode | `--muted` lightens at `data-size="large"`; `--dim` does not. Should. |

---

## 6. What ships in the first release

The instinct to cut is right. Every feature is a surface that has to be supported, explained and defended.

| Feature | Call | Why |
|---|---|---|
| Intro sequence | **Ship** | 8 seconds, skippable, sets the stakes before asking for anything. |
| Age question | **Ship** | Now load-bearing for the 18+ sync rule. Make it gate Share too. |
| Dashboard: drop + character + one line | **Ship** | This is the product. |
| **Automatic prompt counting** | **Ship — it *is* the product** | Everything else is decoration around this. It's also the least finished part. |
| Facts | **Ship** | The cheapest "make them think" mechanism we have, and it's sourced. |
| Character roster + unlocks + healing | **Ship** | The retention engine, and she signed off on it. |
| Naming your character | **Ship** | One input, big attachment payoff. |
| Weekly report | **Ship** | The reflection moment; the number only means something over a week. |
| Detailed analytics | **Ship** | One tap, hidden by default, costs nothing. |
| CSV export | **Ship** | Tiny, and it proves we're not hoarding anything. |
| Simulate | **Ship, estimate-only** | The best "make them think" tool in the app — once it stops writing to real totals. |
| Share | **Ship, gated under 13** | The growth engine for this audience. Don't ship it ungated. |
| Home-screen widget | **Ship only if the real widget ships** | Otherwise remove both entry points. |
| **Sync across devices** | **Defer to 1.1** | Built and tested, but it needs a hosted relay, a privacy policy and a support story, and it serves the minority with two devices. Ship it dark. It costs nothing to wait and a lot to launch half-done. |
| **Neutralize / charity links** | **Cut from v1** | Highest legal and reputational exposure, lowest launch value. It sends users to third parties for money on the strength of a claim we then retract. Bring it back when someone owns the relationships. |
| Groups / Grove | **Stay parked** | Already decided. But see §7 — something has to do its job. |
| Five characters | **Consider three for v1** | Leopard stages 2 and 3 are hard to tell apart (logged as I-31), and every character is five pieces of art to maintain. Plant, bear and glacier cover the range. |

---

## 7. The strategic risk — worth more attention than everything above

**The honest number is small, and a small number shown alone argues against caring.**

A heavy day of AI use is a few hundred millilitres. The app's default budget is 100 mL. The opportunity-cost line will often say something like *"enough to fill one drinking glass."*

A thoughtful user does the maths in three seconds and concludes: *a glass of water. Who cares.* And they'd be right about their own glass. The concern only becomes real at aggregate — the 66 billion litres in the intro, 41 billion for one company in one year, the hall of servers. The app opens on that scale and then spends every subsequent session on a number too small to alarm anyone.

That gap is the product's central tension, and right now three things carry it, none of them deliberately:

1. **The characters** — they make a small number *feel* like consequence. This is the strongest asset and the reason the mascot work was worth it.
2. **The facts** — they reintroduce scale, twice a day, at most.
3. **The parked group feature** — which was the one mechanism that showed a user they're part of something bigger.

**This needs a decision before build, not after.** Three honest options:

- **Own the small number.** The point isn't that your glass matters; it's that you now *know*, and knowing changes prompting habits. Honest, quiet, and it risks being forgettable.
- **Bridge to scale in the app.** One line on the dashboard that does the multiplication: *"If everyone in your city prompted like you today: 4.2 million litres."* One sentence, no new screen, no social features, no server. This is the cheapest version of what Grove was for, and it's the one I'd build.
- **Bring groups back.** Most powerful, most expensive, and it reopens the privacy story we just spent a week tightening.

My recommendation is the middle one. It costs a line of arithmetic and it's the difference between an app that reports and an app that makes someone think — which is the brief.

---

## 8. Decisions — signed off 2026-09-24

Mouli answered every point in the review; Madhur took the three scope calls she hadn't covered. **This is the locked scope for the first release.**

| # | Decision | By |
|---|---|---|
| 1 | "Neutralize My Footprint" → **"Support water projects"** | Mouli |
| 1b | …but **cut from v1 entirely**. Highest legal exposure, lowest launch value, and nobody owns the charity relationships yet. The renamed version returns in 1.1. | Madhur |
| 2 | Sample data **behind an explicit switch** (`?demo=1` + the Settings button), never automatic. The real empty state gets designed. | Mouli |
| 3 | Simulate **never writes to today's totals**. It is a what-if only: *if I sent this prompt, this happens*. | Mouli |
| 4 | Keep the age question and make it earn its place: **gate Share under 13**, and soften the character's distressed states for the youngest band. | Mouli |
| 5 | **British spelling** throughout. | Mouli |
| 6 | A **first-run card on the dashboard**: *"Sipcount is watching for your prompts. Use ChatGPT, Claude or Gemini and come back."* On the real build this is where the permission ask lives, with its reason attached. | Mouli |
| 7 | **Stages 0 and 1 get a line too** — restraint should feel seen, not ignored. | Mouli |
| 8 | All four demo controls behind **one demo-mode gate**, not four deletions. | Mouli |
| 9 | **Widget ships** — on both the app and the extension. | Mouli |
| 10 | About rewritten in the app's own voice; **"digital sobriety" retired** as user-facing language. | Mouli |
| 11 | "Finals week" out of the share captions. Character status words unchanged — they're right. | Mouli |
| 12 | **Bridge-to-scale line ships**, but must not clutter the dashboard. | Mouli |
| 13 | **Sync deferred to 1.1**, code ships dark. Needs a relay, a privacy policy and a support story; serves the two-device minority. | Madhur |
| 14 | **Keep the snow leopard** — regenerate its middle stages with a better prompt rather than dropping it. | Madhur |
| 15 | Accessibility and dead-code fixes proceed without further sign-off (`--dim` contrast, `plantState()` removal). | Madhur |

### A correction to §7, found while costing decision 12

The illustrative figure in the original review ("4.2 million litres") does not survive checking. Run against the engine at the US default region:

| | per day | per year |
|---|---|---|
| Typical user (25 prompts/day) | 32 mL | 11.8 L |
| 1,000 people | 32 L | 11,800 L |
| 1,000,000 people | **32,000 L** | **11.8 million L** |

A million people for a single day is 32,000 litres — a swimming pool, and not alarming. **Population alone does not rescue the small number; population × time does.** The line must therefore multiply by a year.

Two honest forms, the second preferred because it reuses a figure the user met eight seconds into the app and so closes a loop instead of opening one:

- *"A million people prompting like you for a year: 11.8 million litres."*
- **"A million people with your habits would evaporate another GPT-3 training run — 700,000 litres — every three weeks."** ← recommended (16.9 runs/year = one every 21.6 days)

**Placement:** it shares the existing single line under the character (`#oppCost`), alternating with the opportunity-cost text. No new element, no added height — which is what "must not clutter the main page" requires.

## 9. Changed today

- Intro rebuilt in vanilla CSS/JS into the launch slot: two verified figures (700,000 L · 66 bn L), then the wordmark, the drop and *"Now see your share."* ≈ 8.2 s, skippable, tap to advance, progress bars, reduced-motion aware, ~3 KB, no dependencies. The Google 41 bn figure moved into the fact library rather than being lost.
- The privacy copy on the age screen and in Settings corrected to match what sync actually does.
- **Regression: 85 passing, 0 failing, 0 console errors.** It has no layout engine, so it never replaces opening the app on a phone.
