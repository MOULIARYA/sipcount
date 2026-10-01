# Calibration — the scripted run

*Twenty prompts, about twenty minutes. This is what replaces three guesses with three measurements.*

## What we are trying to learn

Three numbers in `engine.js` are placeholders, each flagged LOW confidence in the code:

| | Standing at | Why it matters |
|---|---|---|
| Output tokens cost **5×** input | central of a 3–10 range | decides almost the whole number |
| Unseen work runs at **90 tokens/second** | mid of a 70–125 range | your 5-minute research turn is 144 mL at 70 and 251 at 125 |
| Context costs **+5% per 1,000 tokens** | mid of a 3–8 range | decides what a long thread costs |

And one more: **characters per token**, which we approximate by script. English ≈ 4, Devanagari ≈ 3.2. Those are literature figures, not ours.

## How each one gets solved

**Characters per token** — the prompts below are fixed text, so I can tokenise them offline with the real tokenisers and compare against the character counts the extension recorded. No tokeniser needs to ship in the extension, which is why this protocol exists rather than a two-megabyte download on every page load.

**Tokens per second** — this is the clever one. On a plain chat turn with no tools, the model generates **only** what you see. So `rate × active time − visible output` should come out at **zero**. If our 90 is too high, those turns show phantom unseen work. The rate that drives them to zero is the real one. That is why ordinary prompts matter more than impressive ones.

**Context factor** — prompts 13–17 are the same question asked repeatedly in one thread. Identical question, identical kind of answer, steadily more history. Whatever the cost climbs by *is* the context factor.

**Output multiplier** — the hardest, because it needs energy we cannot measure. Prompts 6–9 at least pin the shape: same input, very different answer lengths.

---

## Before you start

1. Popup → **Calibration mode ON**
2. Popup → **Clear data** (so the run is clean — do this only if you don't mind losing today's total)
3. Use **one fresh conversation per numbered prompt**, unless it says otherwise. A new chat means no context, which keeps the early prompts clean.

Send each one exactly as written. If a model refuses or errors, note the number and skip it.

---

## The set

### A · Length, in English (fresh chat each time)

1. `What is the capital of Peru?`
2. `Name three rivers in Europe.`
3. `Explain photosynthesis in exactly two sentences.`
4. `Explain photosynthesis in about 300 words.`
5. `Explain photosynthesis in about 1200 words.`

### B · Same question, different answer lengths (fresh chat each time)

6. `Describe the water cycle. Answer in one sentence.`
7. `Describe the water cycle. Answer in one paragraph.`
8. `Describe the water cycle. Answer in about 800 words.`
9. `Describe the water cycle. Answer in about 2000 words.`

### C · Script (fresh chat each time)

10. `प्रकाश संश्लेषण कैसे काम करता है? लगभग 300 शब्दों में उत्तर दें।`
11. `Mujhe photosynthesis ke baare mein 300 words mein samjhao.`
12. `Write a Python function that reverses a string, with docstring and three tests.`

### D · Context — all five in ONE conversation, one after another

13. `List the planets of the solar system with one fact each.`
14. `Now do the same for the moons of Jupiter.`
15. `Now the same for notable asteroids.`
16. `Now the same for dwarf planets.`
17. `Now summarise everything above in about 300 words.`

### E · The heavy end (fresh chat each time)

18. `Research the current state of desalination technology and summarise the three most promising approaches with sources.`
19. `Create a table comparing the top five electric vehicles sold in India in 2025 by range, price and battery size.`
20. `Generate an image of a snow leopard on a rocky outcrop.`

---

## Then

Popup → **Copy CSV** → paste it to me.

Repeat on a second AI tool if you have the patience — differences between vendors are themselves a finding, and the engine currently assumes they behave identically.

## What you get back

`node tools/fit-calibration.js <your.csv>` reads the rows and prints what the numbers should be,
alongside what they are now, with the spread so we can see how confident to be. Anything it
proposes goes into `docs/constants.json`, which every product picks up — so the fitted numbers
reach installed apps without a release.

**Nothing in the CSV is text.** Counts, scripts and timings only, which is the same boundary the
product keeps everywhere else.
