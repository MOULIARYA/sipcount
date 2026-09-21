# Sipcount — image generation prompts (mascot artwork)

Written 2026-09-21 for round 15. Use these in **Google AI Studio** or the Gemini API (not the phone app —
the consumer app stamps a visible sparkle on free and AI Pro tiers; every image carries the invisible
SynthID mark either way). Settings: **aspect ratio 4:3, resolution 2K**, one image per prompt.

Two routes. **Route A (recommended)** generates three photoreal *backdrops* and keeps the bear, ice floe,
glacier wall and plant as SVG on top, so they can still shrink and wilt continuously with the number.
**Route B** generates complete photoreal scenes as five fixed frames per mascot, which look richer but
can only cross-fade between steps.

Hard rules baked into every prompt: true-black-friendly (the app background is `#000000`), no text, no
people, no logos, cool blue/teal palette so it never fights the neon green accent, and a clear empty
area where the SVG subject sits.

---

## Route A — three backdrops (recommended)

### A1 · Arctic sea (behind the polar bear)

```
A photorealistic wide view of open Arctic sea at blue-hour twilight, shot on a 35mm lens from just
above the waterline. Calm dark water with a slow swell and long, soft reflections. A low band of
distant pack ice sits on the horizon, far away and small. The sky is heavy overcast in deep navy and
slate, unlit, with no sun and no bright highlights. Very low-key exposure: the image falls to near
black at all four edges and in the top third, as if lit only by the last of the light. Muted cool
palette of deep navy, slate blue and desaturated teal. Simple, calm composition with very few
elements so it stays readable at thumbnail size. Leave the lower centre of the frame completely
empty open water — no ice, no objects, no subject there. Natural documentary photography, fine
grain, no stylisation.
Do not include: any animal, any person, boats, text, letters, captions, watermarks, logos, bright
sky, sunsets, warm colours, heavy HDR, tilt-shift, vignette rings, or busy detail.
```

### A2 · Glacial fjord (behind the glacier)

```
A photorealistic view across a dark glacial fjord at dusk, camera just above the water. Deep, still,
almost black water in the foreground with faint cold reflections and a few small drifting shards of
ice at the far left and far right edges only. Far in the distance, low dark mountain ridges. Sky is
overcast and unlit, deep blue-grey falling to near black at the top of the frame and at every edge.
Very low-key exposure, no sun, no warm tones. Muted palette of glacial blue, slate and desaturated
teal. Minimal, calm composition that reads at thumbnail size. The entire centre of the frame is empty
water and sky — nothing standing there.
Do not include: any large ice wall or iceberg in the centre, any person or animal, boats, text,
letters, captions, watermarks, logos, sunlight, warm colours, aurora, heavy HDR, or busy detail.
```

### A3 · Dark interior windowsill (behind the plant)

```
A photorealistic dark interior scene at dusk: a plain matte concrete windowsill and a softly blurred
window to the upper left, with cool grey daylight falling from that side. Deep shadow everywhere else,
falling to near black at the right side, the bottom and all edges. Shallow depth of field, the
background wall soft and featureless. Muted, desaturated palette of cool grey, charcoal and faint
blue — no warm lamplight. Very low-key, moody, calm. The centre of the sill is completely empty —
no plant, no pot, no objects of any kind.
Do not include: any plant, flower, pot, vase, person, hands, furniture, text, letters, captions,
watermarks, logos, warm light, sunlight, clutter, or busy detail.
```

**After generating:** downscale each to about 900 px wide, convert to WebP at quality ~80 (target
under 80 KB), name them `assets/bg-bear.webp`, `assets/bg-glacier.webp`, `assets/bg-plant.webp`, and
tell me — wiring them behind the existing SVG is a small change.

---

## Route B — full photoreal scenes, five states per mascot

Generate the **state 0** image first. Then, in the same chat, **edit that image** for each following
state rather than generating a new one — that is the only reliable way to keep the same camera, light
and scene across the set. Export each state before moving on.

### B1 · Polar bear — state 0 (pristine)

```
A photorealistic polar bear sitting on a solid, broad, flat ice floe in dark Arctic water, seen from
slightly above the waterline on a 50mm lens. The floe is large and stable with plenty of room around
the bear, its edges thick and wet. Calm dark sea, a low band of distant pack ice on the horizon,
heavy overcast twilight sky with no sun. Very low-key exposure falling to near black at every edge.
Muted deep navy, slate and desaturated teal; the bear's fur is cool white with soft grey shadow, not
pure white. Natural wildlife documentary photography, fine grain, no stylisation. The bear is calm
and upright, seen from the side, centred in the frame.
Do not include: text, letters, captions, watermarks, logos, people, boats, bright sky, sunsets, warm
colours, cartoon or illustration style, heavy HDR.
```

Then edit the **same image** for each state, one at a time:

```
State 1 — Keep the same bear, camera, light and sea exactly as they are. Make the ice floe noticeably
smaller, about three quarters of its size, with meltwater pooling on its surface and thinner edges.
Change nothing else.
```
```
State 2 — Same bear, camera, light and sea. The floe is now about half its original size, edges
undercut by the water, thin meltwater running off the sides. The bear has less room and sits closer
to the edge. Change nothing else.
```
```
State 3 — Same bear, camera, light and sea. The floe is barely larger than the bear, cracked through
in one place, sitting low in the water. Change nothing else.
```
```
State 4 — Same bear, camera, light and sea. Only a small broken raft of ice remains, just big enough
for the bear, with loose fragments floating around it. Change nothing else.
```

### B2 · Glacier — state 0

```
A photorealistic tall glacier ice wall meeting dark fjord water, seen straight on from just above the
waterline on a 35mm lens. The wall is unbroken and massive, filling most of the frame, its face
showing layered blue ice, fine vertical fractures and a wind-carved upper edge. Still dark water in
front with faint cold reflections. Overcast dusk sky, no sun, very low-key exposure falling to near
black at the top and at every edge. Glacial blue, slate and desaturated teal only. Natural landscape
photography, fine grain, no stylisation.
Do not include: text, letters, captions, watermarks, logos, people, boats, wildlife, sunlight, warm
colours, aurora, heavy HDR, cartoon or illustration style.
```

Edits: `State 1` — same camera and light, the wall has retreated a little and two deep crevasses have
opened. `State 2` — the wall is about two thirds of its height, meltwater streaking down the face,
one large block calved and floating in front. `State 3` — half its height, heavily fractured, several
icebergs drifting in the foreground. `State 4` — a low, broken remnant of ice with the fjord open
behind it and scattered bergs in the water.

### B3 · Plant — state 0

```
A photorealistic healthy young potted plant with broad green leaves in a plain matte dark grey pot,
on a concrete windowsill in a dark interior at dusk. Cool grey daylight from a softly blurred window
to the upper left, deep shadow elsewhere falling to near black at all edges. Shallow depth of field,
featureless background wall. Muted cool palette, no warm lamplight. Natural still-life photography,
fine grain, no stylisation. The plant is upright and turgid, centred.
Do not include: text, letters, captions, watermarks, logos, people, hands, flowers, other plants,
clutter, warm light, sunlight, heavy HDR, cartoon or illustration style.
```

Edits: `State 1` — same plant, pot, camera and light, leaves slightly softened and beginning to
droop, soil drying at the surface. `State 2` — clearly wilting, leaves folded down, edges going pale.
`State 3` — badly wilted, leaves yellowing and curled, soil cracked. `State 4` — dry and brown,
leaves collapsed over the rim of the pot, a few fallen on the sill.

**After generating:** export each state, downscale to about 900 px wide, WebP quality ~80, name them
`bear-0.webp` … `bear-4.webp` (same for `glacier-` and `plant-`), put them in `assets/`, and fill in
`MASCOT_ASSETS` at the top of the Ecosystem section in `sipcount.html`:

```js
const MASCOT_ASSETS = {
  plant:   { dir:'assets/', frames:['plant-0.webp','plant-1.webp','plant-2.webp','plant-3.webp','plant-4.webp'] },
  bear:    { dir:'assets/', frames:['bear-0.webp','bear-1.webp','bear-2.webp','bear-3.webp','bear-4.webp'] },
  glacier: { dir:'assets/', frames:['glacier-0.webp','glacier-1.webp','glacier-2.webp','glacier-3.webp','glacier-4.webp'] }
};
```

---

## Things to keep in mind

- Don't paste the stock reference images into the generator and ask for "this style" — one of them is a
  watermarked pngtree illustration, and deriving from it carries the same problem as copying it.
  Describe the composition in words, as above.
- Every Gemini image carries an invisible SynthID watermark. Commercial use is permitted under Google's
  terms and Google doesn't claim ownership of the output, but verify the current terms before shipping.
- Purely AI-generated images generally get no copyright protection, so nothing stops a competitor
  reusing them. If the mascot becomes the product's face, commission it instead (I-31).
- Route B costs ~1 MB of assets and can only cross-fade between five steps; Route A stays a few KB and
  keeps the degradation continuous. If in doubt, generate Route A first and judge it on the device.
