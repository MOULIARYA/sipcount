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

## traceability.js

The matrix as a build artefact. Every row has a status; no row claims done with an empty proof
column; every test file it names exists; **every suite that exists is named in it**, so a new test
cannot be invisible; and its "Last updated" date may not be older than the newest decision in
`ISSUES.md`. That last check is the one that catches a switch between tracks. It also enforces the
three-day platform-research cadence from `PLATFORM-RESEARCH-LOG.md` — a note after three days, a
failing build after ten.

## ../../tools/check-dart.js

Not a test of the product — a test of the Dart we cannot compile. The authoring sandbox blocks
`storage.googleapis.com`, which serves both the Dart SDK and Flutter's engine artifacts, so
`flutter analyze` and `flutter test` cannot run while the code is being written and every Dart
fault waits for a push. Five waits in two days (I-68); four of the five were visible in the source.

Catches: unbalanced brackets, imports that point nowhere, methods that silently need
`package:collection`, `const` on widgets whose constructors are not const, deprecated APIs we have
already been bitten by, widget tests asserting on animated text before the clock advances, and
generated fixtures that no test reads.

It is not the analyzer. The real fix is `flutter analyze && flutter test` before pushing.
