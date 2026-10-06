/// How far behind the reference design (`sipcount.html`) this app is, stated out loud.
///
/// The failure this exists to prevent (I-58): the prototype moved from v11 to v14 over three
/// weeks, the phone app did not, and every test stayed green the whole time — because the suites
/// compared calculations, and nothing compared the app to the design it is supposed to be.
///
/// Two numbers, deliberately:
///
///  * [implementedUiContract] — what this app genuinely satisfies today.
///  * [acknowledgedPrototypeContract] — the prototype's number as of the last time a human looked
///    at the difference and decided what to do about it.
///
/// `parity.js` checks the *second* against the prototype's `sipcount-ui-contract` meta. So a known,
/// tracked gap does not leave CI permanently red (a red build nobody can fix is a build nobody
/// reads), but the next prototype change fails immediately and names what drifted.
///
/// Lowering the prototype's number to make this pass is the one move that defeats the point.
library;

/// Raised from 11 to 15 on 2026-10-06, when the port landed: four screens behind one bottom nav,
/// the draining drop, the ecosystem characters with Mouli's own art, the insights card, detailed
/// analytics, the fact cards, the Simulate estimator with its effort control, the About copy and
/// the intro with its age band.
///
/// Deliberately still missing, and tracked rather than pretended: the share sheet and story image,
/// the weekly report overlay, the home-screen widget, the preview scrubber, and the character idle
/// animations. None of them changes a number; all of them are listed in `docs/TRACEABILITY.md`.
const int implementedUiContract = 15;

/// The prototype revision whose difference from [implementedUiContract] has been reviewed and
/// booked as open work — tracked as **P7** in `docs/TRACEABILITY.md` and **I-58** in `ISSUES.md`.
/// Raise this only when someone has genuinely looked at what changed and decided.
const int acknowledgedPrototypeContract = 15;
