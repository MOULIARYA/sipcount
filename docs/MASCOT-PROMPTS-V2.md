# Sipcount — mascot artwork, hand-drawn direction

*2026-09-22 · for Gemini / Nano Banana. Round 2 of the art direction. We settle the plant first, then build the rest on the same lines, then the states.*

## What changed, and why the first attempt failed

The first direction asked for **a photograph of a hand-made toy**. It produced exactly that: a 3D-looking succulent sitting on a wooden table with a blurred brown room behind it. Too photographic, and it brought a whole background with it.

The direction now is **drawn by hand, then cleaned up into a graphic** — an illustrated character asset, flat colour, visible line work, and **nothing behind it at all**, so the app's own black shows through.

## The transparency problem, and the fix

Gemini cannot produce a transparent background. Every model in the family — Nano Banana, Nano Banana Pro, Nano Banana 2 — outputs flat RGB with no alpha channel; ask for "transparent" and you get solid white, solid black, or a painted-on checkerboard that only looks transparent.

So we generate on a **flat chromakey colour** and I strip it to a true transparent file afterwards. The colour has to be one the character does not contain:

| Character | Chromakey to ask for |
|---|---|
| Plant (green) | **magenta** `#FF00FF` |
| Polar bear, snow leopard, glacier (white / grey / blue) | **green** `#00FF00` |

Send me the raw generation and you get back a transparent WebP sized for the app. Do not try to cut it out yourself.

---

## The plant prompt

Use **AI Studio**, 16:9, 2K.

```
A hand-drawn character mascot of a chubby, friendly succulent in a small rounded pot — illustrated by hand and then cleaned up into a flat graphic asset for a mobile game.

Drawing style: confident hand-inked outline of varying weight, slightly wobbly and human rather than mechanical. Flat cel-shaded colour, no more than two tones per shape, with one simple shadow side as if lit softly from the upper left. Subtle coloured-pencil grain inside the shapes. Warm sage and mint green leaves with dusty rose tips, a simple dark charcoal pot. Large friendly eyes and a small calm smile on the body of the plant itself, gently asymmetric. Bold simple silhouette that still reads when shrunk to the size of a thumbnail.

Composition: the whole character, centred, with an even margin all round and nothing cropped. It stands on nothing — no ground, no surface, no shadow beneath it, no plinth.

Background: a completely flat, even magenta #FF00FF field. Nothing else in the frame at all — no scenery, no table, no room, no vignette, no gradient, no texture in the background.

Do not include: photography, 3D rendering, depth of field, blur, glossy or plastic shading, realistic lighting, a table or floor or wall, a cast shadow, a background scene, a white sticker border, gradients in the background, text, letters, logos, watermarks, sparkles, people, hands, other characters.
```

### If it comes back wrong

- **Still looks 3D or photographic** → add *"a flat 2D illustration, like a page from a picture book. Absolutely no rendering, no dimensional shading."*
- **Background is not clean** → add *"the background must be one single flat colour, edge to edge, with no shading of any kind."*
- **Too much detail** → add *"simplify: fewer, larger shapes; this has to read at 60 pixels."*
- **Face lost in the leaves** → add *"the face sits on the central body of the plant and is the clearest thing in the picture."*

---

## Picking it

Four checks, in order — the first eliminates most candidates.

**Shrink it to 60 pixels.** That is the size in the widget and the Settings gallery. If you cannot tell what it is, it is out, however good it looks large.

**Squint at the silhouette.** As a black shape, is it instantly a potted plant?

**Check the face.** The eyes carry every state we build later. If they are lost now, the wilting version will not land.

**Check the line.** It should look drawn by a person — uneven weight, small imperfections. A perfectly smooth vector line is the thing that reads as machine-made.

---

## What follows, once the plant is agreed

1. **The other three**, generated in the same chat so the line weight, palette logic and eye style carry across: *"Same drawing style, same line weight, same flat colour treatment as the plant. Chromakey green background."* — polar bear on a block of ice, snow leopard curled on a snowy rock, glacier with a face. All on green.
2. **The states.** For each character, edit its own healthy image so the drawing stays identical and only the condition changes: *in trouble* at minimum, and a middle state if we want the decline to be gradual rather than a switch at the halfway mark. That decision is worth making once you see the plant wilt.
3. **The small crops** for the widget, if the full drawing turns out not to read at 60 pixels.
