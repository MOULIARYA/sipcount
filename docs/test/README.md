# Prototype regression check

```
npm install jsdom
node docs/test/regression.js
```

45 assertions over the whole prototype: boot, the hero and character card, the five stages (that the
picture and the words agree), notifications, the explainer popover, analytics, the simulator, settings
and the character gallery, CSV export, the weekly review, and the drawn fallback when artwork is
missing. Exits non-zero on any failure or console error.

Run it after any change to `sipcount.html` or `engine.js`. It is not a substitute for opening the file
in a browser — it has no layout engine, so it cannot see anything visual.
