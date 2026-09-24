# Sipcount — the five stages, per character

*2026-09-22. The four healthy characters are approved and key out cleanly. This is the decline: four more images each, sixteen in all.*

## How to run them

**One character per chat.** Open the finished healthy image, then run stage 1. Take **the result of stage 1** and run stage 2 on it, and so on — each stage edits the one before it, so the decline is continuous rather than four separate drawings.

Every prompt below starts with the same paragraph. It is not padding — it is the part that keeps the character from drifting, resizing or wandering around the frame between stages, which is what makes a cross-fade look like a mistake.

> Keep the same character, the same drawing style, the same line weight, the same colours and the same framing. The character must stay exactly the same size and in exactly the same position in the frame. Keep the flat [green #00FF00 / magenta #FF00FF] background, edge to edge. Change only what is described below.

Plant keeps **magenta**; bear, leopard and glacier keep **green**.

**Sad, not grim.** Her instruction stands: visibly sad at worst, never distressing. Nothing dies, nothing is in real danger, and stage 4 is still recognisably the same friendly character having a bad day.

Send me all twenty files when they are done and name them `plant-0` to `plant-4`, `bear-0` to `bear-4`, and so on. I will key, crop, size and wire them in.

---

## Plant *(magenta)*

**Stage 1 — first signs**
> The leaves are slightly less plump. A few leaf tips have started to brown. The face looks mildly concerned: eyebrows lifted slightly, the smile smaller. The soil surface looks dry.

**Stage 2 — wilting**
> The outer ring of leaves now droops over the rim of the pot. The green has shifted towards a yellow-green and more of the leaf tips are brown and dry. The mouth is flat rather than smiling, the eyes are worried.

**Stage 3 — badly wilted**
> Most leaves droop heavily and have turned yellow-brown. One dried leaf has fallen and rests against the side of the pot. The soil is cracked. The face is frowning and tired.

**Stage 4 — exhausted**
> The leaves are shrivelled, brown and hanging limp, and the whole plant leans to one side. Two dried leaves lie beside the pot. The eyes are half-closed and sad. Still alive, still the same character — just worn out.

---

## Polar bear *(green)*

**Stage 1 — first signs**
> The block of ice is slightly smaller, with a thin film of meltwater shining on top. The bear glances down at it. One eyebrow is raised in mild concern.

**Stage 2 — the ice is going**
> The block of ice is now about half its original size with rounded, melted edges and a couple of drips falling from it. The bear has pulled its paws in and sits more compactly. The face is worried.

**Stage 3 — balancing**
> The ice is a small raft barely wider than the bear itself. The bear balances with its paws close together, a single drop of sweat by its brow, and a sad frown.

**Stage 4 — the last of it**
> Only a thin sliver of ice is left directly under the bear. Its ears are down, its eyes are large and sad, and it sits very still. The bear is still on the ice, never in the water.

---

## Snow leopard *(green)*

**Stage 1 — first signs**
> The snow on the rock is thinner and a patch of grey stone shows through at one edge. The leopard has lifted its head slightly. The face shows mild concern.

**Stage 2 — the snow is going**
> Half the snow has gone and the grey rock is clearly exposed. The leopard has uncurled and sits rather than lies. It looks warm and a little uncomfortable.

**Stage 3 — bare rock**
> Only a rim of snow is left; the rock is mostly bare and dull grey. The leopard sits upright with its tail hanging down, mouth slightly open as if panting, clearly too warm.

**Stage 4 — nowhere cool**
> There is no snow left at all, only bare grey rock. The leopard is slumped with its ears back and its eyes large and sad, visibly overheated. Still the same cosy character, just miserable.

---

## Glacier *(green)*

**Stage 1 — first signs**
> A few drips run from the base of the ice and one hairline crack has appeared. The snow cap on top is slightly thinner. The eyebrows tilt into mild concern.

**Stage 2 — shrinking**
> The iceberg is noticeably shorter and narrower with several more cracks across it. The snow cap is patchy, and one small chunk of ice has broken away and sits beside it. The face looks worried.

**Stage 3 — calving**
> The iceberg is about half its original height and looks wet. The snow cap is gone and three broken chunks of ice sit around its base. The face is frowning.

**Stage 4 — a small mound**
> What is left is a low rounded mound of ice with a few scattered chunks beside it. The eyes are large and sad. Still recognisably the same character, much smaller.

---

---

## Snow leopard — reshoot (2026-09-24)

**Why:** stages 1, 2 and 3 came back too similar to tell apart in the card. The fault is in the prompts above, not the generation: they describe the *snow* changing by small amounts and leave the leopard doing roughly the same thing each time. At the size this appears on screen, small changes to a white shape are invisible.

**The fix — change three things every stage, not one:**

1. **Snow coverage, as a stated fraction.** Give the model a number it can act on, not "thinner".
2. **The pose, so the silhouette changes.** Curled → head up → sitting → standing → slumped. Shape reads at any size; shading does not.
3. **One new element per stage** — a meltwater trickle, then a puddle. Something that wasn't there before, so the eye has an anchor.

Run these on the **approved healthy leopard**, each stage editing the result of the one before it, with the same opening paragraph as every other prompt (same character, same style, same line weight, same size, same position, flat green `#00FF00` background edge to edge).

**Stage 1 — first signs**
> The rock is now about **three-quarters covered in snow**; a band of grey stone is clearly exposed along the front edge, wide enough to see at a glance. The leopard has **raised its head and opened its eyes**, still lying down. A single thin trickle of meltwater runs down the exposed rock. The face shows mild concern — eyebrows lifted, the smile smaller.

**Stage 2 — the snow is going**
> The rock is now only **half covered in snow**, and the bare grey stone is the largest single area in the picture. The leopard has **sat up on its front legs**, tail curled around beside it, changing its shape clearly from the previous image. A small pool of meltwater has collected at the base of the rock. It looks warm and uncomfortable, mouth closed, eyes worried.

**Stage 3 — bare rock**
> Only a **thin rim of snow** is left around the very edge; the rock is otherwise **bare, dull grey and dry**, with visible texture. The leopard is **standing on all four legs**, head lowered, **mouth open and panting**, tail hanging straight down. The meltwater pool has shrunk to a damp patch. Clearly too warm.

**Stage 4 — nowhere cool**
> There is **no snow at all**, only bare grey rock, and the damp patch has gone. The leopard is **lying flat on its side** on the stone with its legs stretched out, **ears flat back**, eyes large and sad, visibly overheated. Still the same cosy character — just miserable.

**Check before sending:** put stages 1, 2 and 3 side by side at thumbnail size. If you cannot tell which is which in two seconds with the pictures shrunk to about 2 cm wide, the deltas are still too small and stage 2 needs pushing further.

---

## When you send them

I will key out the chroma, trim, normalise all four characters to the same footprint so they sit identically in the card, convert to WebP and wire five frames per character. Five stages map onto the day cleanly: roughly fine, first signs, halfway, struggling, at the limit.

Two things I will check and report back on: whether each character holds together at 62 pixels in all five stages, and whether any stage jumps in size or position against the one before it — that is the only thing that makes a cross-fade look broken, and it is fixable by regenerating just the offending stage.
