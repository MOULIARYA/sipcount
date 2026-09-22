# Sipcount — making the mascot playable

*Proposal for the product owner · 2026-09-22 · prepared by Madhur*

## What we're deciding

Whether the mascot should become something people interact with, rather than a picture that only reacts to yesterday's usage.

Today the character does one thing: it degrades as the day's water is spent. There is nothing to do with it, and no reason to open the app unless you want to check a number. The proposal is to make it closer to a virtual pet — it responds to touch, it can be played with, and looking after it well is rewarded.

Everything below is buildable with the characters we already have. What we need from you is whether the direction is right, how far it should go, and what it should feel like. The decisions we need are listed at the end.

## Where this comes from

The ⚡ Simulate button on the mascot card, which you asked for as a three-second preview for screen recording.

It works, but it is a one-shot demo rather than something anyone would play with. Three things about it are worth knowing before deciding what to do next.

It starts from wherever you are, not from a healthy character. If you are already halfway through your daily water, the preview only shows the second half of the decline — and the most readable part of the story, healthy turning to distressed, is the part that gets skipped.

The drop does not move during the preview. The whole point of the mascot card is cause and effect: the drop drains, the ecosystem suffers with it. In the preview only the character changes, so someone watching a screen recording sees a bear melting for no visible reason.

And the words change instantly while the picture takes a couple of seconds to catch up, so for a moment the card says one thing and shows another.

None of that is hard to fix. The bigger question is whether this should stay a demo button at all, or become the thing people come back for.

## The risk worth naming first

The obvious version of "playful" would reward the behaviour we are trying to reduce.

Talking Tom works because the pet is always available and always delighted — you poke it, it reacts, you poke it again. Our character is different: its state decays with real AI use. If the melt becomes the entertaining part, people will spend water on purpose to watch it happen. Teenagers certainly will. We would have built an engagement loop that runs against the entire premise of the app.

The closer reference is a Tamagotchi: care, neglect, consequence. That reframes the five characters as pets you keep alive rather than skins you choose between.

The principle we would design to, and the first thing worth your agreement or disagreement: **the character is fun to keep alive, never fun to kill.** Interaction and reward sit on the healthy side. Degradation stays a consequence — never celebrated, never scored, never triggered as a toy.

## The proposal

Five changes, in the order we would build them. The first three are small and self-contained; the last two change what the app rewards, which is why they need your call rather than ours.

| # | Feature | What it does | Why | Build |
| --- | --- | --- | --- | --- |
| 1 | Tap to react | Tapping the character makes it respond — the bear waves, the axolotl blows a bubble, the plant perks up, the glacier shivers. Tap it while it is struggling and the response is weaker and sadder. Three or four random idle animations (a blink, a yawn, a stretch) play every twenty seconds or so. | This is the Talking Tom moment, and the cheapest thing on the list. It also teaches the character's state without a word of copy. | Small |
| 2 | Drag the day forward | The ⚡ Simulate button becomes a scrubber. Drag and the day moves: the drop drains, the number climbs, the status changes, the character declines — and dragging back reverses all of it. An auto-play button still produces the three-second clip for recording. | Makes cause and effect obvious in a way no sentence can, and is genuinely playable. It delivers the original brief better than the button does. | Small–medium |
| 3 | React to real prompts | When a prompt is logged the character flinches — a small gulp or recoil, bigger for a heavier prompt. | Makes the app feel alive during actual use rather than only in a demo, and the reaction is honest: it was caused by something you really did. | Small |
| 4 | Care pays off | End a day under budget and the character visibly recovers overnight — a new leaf, thicker ice, the tank refilling. Streaks start to mean something. | Right now the arrow only points one way: things can get worse, never better. Recovery is what gives anyone a reason to come back tomorrow. | Medium |
| 5 | Earn the roster | Start with the plant. The axolotl unlocks at a three-day streak under budget, the snow leopard at seven, and so on. Plus naming your character, stored only on the device. | Turns the five characters from a settings preference into a reason to use less AI — the product thesis expressed as a game mechanic. "Pip is wilting" lands differently from "your plant is wilting". | Medium |

Items 1 to 3 we can build and show you inside the prototype quickly. Items 4 and 5 change what Settings means and what the app is asking of people, so we would want your decision before writing them.

## What we would leave out for now

Three things that look tempting and we would not do yet.

Sound. Apps that make noise get muted, and it sits awkwardly with an app whose argument is that computing wastes energy. Light haptics on Android are fine.

Exporting the melt as a short video. A lovely thing to share, but producing video on the phone is real engineering work. Worth doing later as its own piece, not bundled into this.

Any score, badge or leaderboard attached to degradation. Competing on whose glacier melted fastest is the failure mode of this whole idea.

## Guardrails we would keep either way

Animation costs battery, which is an uncomfortable thing for an app that argues about wasted energy. Idle movement pauses whenever the card is off screen or the app is in the background, and stops entirely for anyone who has asked their phone to reduce motion.

Playing never changes your real numbers. The scrubber and the reactions run on a preview copy, exactly as the current button does, and nothing is written to the day's total.

Distress stays cute-sad and always recoverable. Our audience starts at thirteen. A wilting plant with worried eyes is the right register; anything that reads as an animal genuinely suffering is not.

Nothing about play needs data to leave the phone. Names, streaks and unlocks all live on the device, which keeps the privacy promise exactly as it stands.

## What we need from you

Six decisions. Answer as briefly as you like — a yes, a no or a different idea on each is enough to unblock the build.

1. **The principle.** Fun to keep alive, never fun to kill — is that the right line to hold?
2. **How far.** Is this a light touch (items 1 to 3: the character responds, the day can be dragged) or a real pet with care and consequences (items 4 and 5)?
3. **The roster.** Should all five characters be freely choosable, as they are now, or earned through days under budget? Earning them is the stronger hook but it means a new user starts with one.
4. **Recovery.** Should a good day visibly heal the character overnight? It is the thing that gives people a reason to return, but it softens the message that spent water does not come back.
5. **Tone.** How distressed is too distressed? We would like a line from you on where cute-sad ends.
6. **Naming.** The card says ⚡ Simulate, two taps from a whole tab called Simulate that does something else. "Preview" or "Demo" instead?

One more thing worth your view: if items 4 and 5 go ahead, the five characters stop being a style choice and become the progression system. That is a bigger product statement than it looks, and it is yours to make.
