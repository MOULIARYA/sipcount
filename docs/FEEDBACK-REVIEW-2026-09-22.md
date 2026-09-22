# Sipcount — review of the latest verbal feedback

*For the two of us to walk through before anything is changed · 2026-09-22*

Eleven points came through verbally. Eight are unambiguous and I can build them as stated. Three conflict with instructions given in the last two days, and a few others have a trade-off worth naming before we commit. Nothing below has been built yet.

---

## 1. The list, and where each one stands

| # | What you asked for | What I would change | Status |
|---|---|---|---|
| 1 | Facts notification overlays the screen — placement not right | Needs a decision, options in §3 | **Conflicts** — this placement was your instruction on 21 Sep |
| 2 | Showing % of quota, so drop the "100 mL left in the drop" line | Remove the right-hand line under the ring; keep "40% of 100 mL used" | Clear |
| 3 | Move "Add Widget" off the main screen into Settings; show it once on first install with a cross | First-run dismissible banner + a permanent entry in Settings | **Conflicts** — 5th change to this element |
| 4 | Drop the line "Your plant is plump and green" | Remove the sentence under the character | **Conflicts** — asked for explicitly on 22 Sep |
| 5 | Put the character's name before the status | "Pip · Thriving" instead of "Thriving" | Clear |
| 6 | Remove the green-zone box | Remove the green/amber/red advice card under the character | Clear — assumption to confirm, §4 Q3 |
| 7 | In Insights, no token information; keep the rest | Remove the sentence counting tokens in and out | Clear, with a knock-on, §4 Q4 |
| 8 | Detailed Analytics: keep Prompts today and mL, rename to "last 7 days"; move Days Alive up beside the character | Two metrics left; Days Alive moves to the character card | Clear — two questions, §4 Q5 and Q6 |
| 9 | Detailed Analytics: remove the 7-day bar chart | Remove it | Clear — trade-off in §3 |
| 10 | "Weekly review", not "Sunday review" | Change the label | Clear |
| 11 | "26 mL last 7 days", not "26 mL this week" | Change the heading, and the same wording everywhere else | Clear |

---

## 2. Three things that reverse a recent instruction

None of these are problems — you are allowed to change your mind, and the app is better for several of the earlier reversals. I am listing them only so we both see the pattern and decide deliberately this time, because each one costs a build cycle.

**Notifications (point 1).** On 21 Sep the instruction was to move them off the top edge, anchor them in the vertical centre, slide them in from the side and remove the auto-dismiss timer so they persist until the reader deals with them. That is exactly what produces the overlay you are now seeing. The placements so far: below the header (19 Sep) → below the header, shortened (21 Sep) → centre of the screen, persistent (21 Sep) → not convinced (today). Options in §3.

**Add Widget (point 3).** This element has now been designed five ways: a compact pill (19 Sep) → a prominent card in the feed, your words "highly prominent", with the blue glow (21 Sep) → kept between hero and insights (21 Sep) → compressed to a thin single line (22 Sep) → off the main screen entirely (today). Moving it to Settings is a sound call, but worth knowing: almost nobody visits Settings, so widget adoption will depend almost entirely on that one first-run banner.

**The sentence under the character (point 4).** Yesterday's brief was explicit: *"Completely remove all numbers... the text below the mascot must be a single, purely qualitative, emotional sentence... DO use: 'The ice wall is breaking apart.' or 'Your plant is wilting from the heat.'"* Removing it now is fine, but see §4 Q2 — there may be a version of this you actually want.

---

## 3. Notifications — what are the real options?

The facts are the one part of the app that teaches anything, so it is worth getting this right rather than just moving it again.

| Option | How it behaves | Good for | Cost |
|---|---|---|---|
| A · Inline in the feed | The fact sits as a card in the scroll, between the character and the insights. Never covers anything. | Zero interruption; it is read when the eye reaches it | Easy to ignore entirely |
| B · Bottom sheet | Slides up from above the tab bar, about a fifth of the screen, dismissed by swiping down | Familiar phone pattern; leaves the number and character visible | Still covers the bottom of the feed |
| C · A "did you know" dot | A small dot on a tab; facts collect in a list the user opens when curious | Never interrupts; the facts become a place rather than an event | Most people will never open it |
| D · Keep the centre card, bring the timer back | As now, but it leaves by itself after about eight seconds | Keeps the impact of the current design | Back to what you disliked on 21 Sep: people miss it |

My recommendation is **B**, with the fact appearing at most twice a day and only after a prompt is logged — it keeps the drama of something arriving without covering the number or the character. **A** is the safest if the priority is that nothing is ever in the way.

---

## 4. Questions I need answered before building

1. **Facts** — which option above, and should facts interrupt at all, or only appear when the user goes looking?
2. **The character's sentence** — remove it in every state, or only when things are fine? "Pip · Thriving" alone reads well when all is well; "Pip · Breaking apart" with nothing else may feel thin at the moment we most want people to feel something.
3. **"Green zone box"** — I am assuming this is the advice card under the character that currently reads *"Green zone — 60 mL left today. Nothing you type is ever stored — only the count."* Correct? Or did you mean the green status pill at the top right?
4. **Tokens** — you want them out of Insights. The Weekly Review also has a "Questions vs answers" panel built from token counts, which you asked for on 21 Sep. Should that go too, be reworded without the word "token", or stay as it is?
5. **Images today** — you listed Prompts today and mL last 7 days as the metrics we need. Should "Images today" disappear? Image generation is the single heaviest thing we measure, so it is the one number that changes behaviour fastest.
6. **Days alive** — with the new unlock system there are now two possible meanings: days the character has survived without hitting the limit, or days in a row under budget (which is what unlocks the next character). Which one do you want beside the character?
7. **Trend** — removing the 7-day chart leaves the main screen with no sense of direction at all; the only trend left is inside the Weekly Review. Is that intended, or should something small survive, such as a one-line "higher than last week" sentence?

---

## 5. Decisions taken (22 Sep) and built

| Question | Her answer | Built as |
|---|---|---|
| Notifications | Option B | A sheet that rises from the bottom, above the tab bar; swipe down or ✕ to dismiss; still no timer. All notifications use it, not just facts. Facts are quieter now: never on opening the app, at most two a day, only after a prompt. |
| The character's sentence | Remove only when things are fine | Hidden below 50 % of budget; appears the moment the character starts to struggle. |
| Green-zone box | Yes, the advice card | Removed. |
| Tokens | Remove from the Weekly Review too | No token counts anywhere. The questions-versus-answers bar stays, labelled "Your questions / The answers", with the percentage. |
| Images today | Remove | Gone from the metrics. The "1 image ≈ 10 ordinary questions" line stays in Insights. |
| Days alive | Days survived without hitting the limit | Consecutive days ending today under the limit, days with no AI use included. Shown beside the character as "12d alive". Kept separate from the unlock streak, which still requires real usage. |
| Trend | Remove, no lines | The 7-day chart and the spike pill are gone from the dashboard. The chart stays inside the Weekly Review. |

Also done in the same pass: the "mL left in the drop" line removed; the character's name now leads the status ("Pip · Thriving", falling back to "Plant · Thriving" when unnamed); Add Widget moved off the feed into Settings, with a one-time dismissible banner on first run; "Weekly review" replaces "Sunday review"; "last 7 days" replaces "this week" throughout.

## 6. What I would build the moment we agree

Points 2, 5, 6, 10 and 11 are unambiguous and independent of everything above — about half a day's work together. Points 3, 7, 8 and 9 follow as soon as the questions in §4 are answered. Point 1 is the only one that needs a design decision rather than an instruction.

Two small things I will do at the same time unless you object: the character's name will fall back to its type when no name has been set ("Plant · Thriving"), and the "last 7 days" wording will be applied everywhere those words appear, not just on the two screens you mentioned.
