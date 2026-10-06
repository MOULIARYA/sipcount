/// How far behind the reference design (`sipcount.html`) this app is, stated out loud.
///
/// The failure this exists to prevent (I-58): the prototype moved from v11 to v14 over three weeks,
/// the phone app did not, and every test stayed green the whole time — because the suites compared
/// calculations, and nothing compared the app to the design it is supposed to be.
///
/// Two numbers, deliberately:
///
///  * [implementedUiContract] — what this app genuinely satisfies today.
///  * [acknowledgedPrototypeContract] — the prototype's number as of the last time a human looked
///    at the difference and decided what to do about it.
///
/// `parity.js` checks the *second* against the prototype's `sipcount-ui-contract` meta. So a known,
/// tracked gap does not leave CI permanently red (a red build nobody can fix is a build nobody
/// reads), but the next prototype change fails immediately and names what drifted. Closing the gap
/// means raising both numbers together.
///
/// Lowering the prototype's number to make this pass is the one move that defeats the point.
library;

/// What the Flutter app actually implements. Still Increment 3: v11's dashboard, none of v12–v14's
/// characters, Log screen, fact banner, About rewrite, age tier or sync.
const int implementedUiContract = 11;

/// The prototype revision whose difference from [implementedUiContract] has been reviewed and
/// booked as open work — tracked as **P7** in `docs/TRACEABILITY.md` and **I-58** in `ISSUES.md`.
/// Raise this only when someone has genuinely looked at what changed and decided.
const int acknowledgedPrototypeContract = 15;
