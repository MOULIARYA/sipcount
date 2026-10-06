/**
 * The matrix checks itself.
 *
 * `TRACEABILITY.md` has twice now been the thing that failed rather than the code. It had twelve
 * rows for the calculator and none for the phone's screens, so the app drifted three revisions
 * behind the design with every suite green (I-58). Its header already says a requirement with no
 * test in the last column is not done — but nothing enforced that, and an unenforced rule is a
 * preference.
 *
 * So this suite treats the matrix as a build artefact:
 *   · every row is well formed and has a status
 *   · every row claiming ✅ cites something, and any test file it names must exist
 *   · every suite that exists must be named in the matrix, so a new test cannot be invisible
 *   · the "Last updated" date must not be older than the newest issue in ISSUES.md
 *
 * The last one is the point. Requirements change when we decide something, decisions land in
 * ISSUES.md, and the matrix is supposed to move with them. If ISSUES.md has moved and the matrix
 * has not, that is drift — caught here, on the switch between tracks, which is exactly when it has
 * always been missed. (Madhur, 2026-10-05.)
 */
const fs = require('fs');
const path = require('path');

const ROOT = path.join(__dirname, '..', '..');
const read = f => fs.readFileSync(path.join(ROOT, f), 'utf8');

let pass = 0, fail = 0;
const ok = (name, cond, detail = '') => {
  if (cond) { pass++; console.log('  ✓ ' + name); }
  else { fail++; console.log('  ✗ ' + name + (detail ? ' ' + detail : '')); }
};

const matrix = read('docs/TRACEABILITY.md');
const issues = read('ISSUES.md');

console.log('\nTHE MATRIX IS WELL FORMED');

/* Rows look like: | P7 | requirement | status | proof |  (section A also carries an "Agreed" column) */
const rows = [...matrix.matchAll(/^\|\s*(?:\*\*)?([A-Z]\d{1,2}|[A-Z]-\d{1,2}|[ND]\d{1,2})(?:\*\*)?\s*\|(.+)$/gm)]
  .map(m => ({ id: m[1], rest: m[2] }));

ok('the matrix has rows at all', rows.length >= 20, `${rows.length} found`);

const STATUS = ['✅', '🟡', '⬜', '⏸', '❌'];   // ✅ 🟡 ⬜ ⏸ ❌
const statusless = rows.filter(r => !STATUS.some(s => r.rest.includes(s))).map(r => r.id);
ok('every row carries a status', statusless.length === 0, statusless.join(', '));

const ids = rows.map(r => r.id);
const dupes = ids.filter((id, i) => ids.indexOf(id) !== i);
ok('no duplicated row ids', dupes.length === 0, [...new Set(dupes)].join(', '));

console.log('\nEVERY CLAIM POINTS AT SOMETHING');

/* A ✅ with an empty proof column is the exact failure the matrix was created to stop. */
const emptyProof = rows.filter(r => {
  if (!r.rest.includes('✅')) return false;
  const cols = r.rest.split('|').map(c => c.trim()).filter(c => c !== '');
  return cols.length < 2 || cols[cols.length - 1].length < 10;
}).map(r => r.id);
ok('no row is marked done with nothing to show for it', emptyProof.length === 0, emptyProof.join(', '));

/* Any `foo.js` named anywhere in the matrix has to be a suite that actually exists. */
const named = [...new Set([...matrix.matchAll(/`?([a-z_-]+\.js)`?/g)].map(m => m[1]))];
const missing = named.filter(f => !fs.existsSync(path.join(ROOT, 'docs', 'test', f)) &&
                                  !fs.existsSync(path.join(ROOT, 'tools', f)) &&
                                  !fs.existsSync(path.join(ROOT, f)) &&
                                  !fs.existsSync(path.join(ROOT, 'browser_extension', f)));
ok('every test file the matrix cites exists', missing.length === 0, missing.join(', '));

/* …and the reverse, which is the direction that actually rots: a suite nobody records. */
const suites = fs.readdirSync(path.join(ROOT, 'docs', 'test')).filter(f => f.endsWith('.js'));
const uncited = suites.filter(f => !matrix.includes(f));
ok('every suite is named in the matrix', uncited.length === 0, uncited.join(', '));

console.log('\nTHE MATRIX HAS NOT BEEN LEFT BEHIND');

const dates = s => [...s.matchAll(/20\d\d-\d\d-\d\d/g)].map(m => m[0]).sort();
const matrixStamp = (matrix.match(/Last updated (20\d\d-\d\d-\d\d)/) || [])[1];
ok('the matrix says when it was last updated', !!matrixStamp, matrixStamp || 'no "Last updated" line');

const newestIssue = dates(issues).pop();
ok('the matrix is no older than the newest decision in ISSUES.md',
   !!matrixStamp && !!newestIssue && matrixStamp >= newestIssue,
   `matrix ${matrixStamp}, newest issue ${newestIssue} — a decision landed and the matrix did not move`);

/* The research cadence Madhur asked for on 2026-10-05. A promise in prose is not a cadence, so the
   log is a file and its freshness is a test. */
console.log('\nTHE PLATFORM RESEARCH IS NOT STALE');
const LOG = 'docs/PLATFORM-RESEARCH-LOG.md';
const haveLog = fs.existsSync(path.join(ROOT, LOG));
ok('the platform research log exists', haveLog, LOG);
if (haveLog) {
  const last = dates(read(LOG)).pop();
  const ageDays = last ? Math.floor((Date.now() - Date.parse(last + 'T00:00:00Z')) / 86400000) : 999;
  ok('the log has a dated entry', !!last);
  /* Warn at the agreed 3 days, fail at 10. A hard fail on day four would turn a weekend into a red
     build and teach everyone to ignore the colour; a fail at ten days still catches real neglect. */
  if (ageDays > 3) console.log(`  · due: last platform research ${ageDays} days ago (cadence is 3)`);
  ok('platform research is not badly overdue', ageDays <= 10, `${ageDays} days since ${last}`);
}

/* Madhur's second question on 2026-10-05: are all released versions compatible and updated when
   something changes? There was no answer, because nothing recorded what had shipped. The register
   is checked here so it cannot quietly go stale like the matrix did. */
console.log('\nWE KNOW WHAT IS IN THE FIELD');
const REL = 'docs/RELEASES.md';
const haveRel = fs.existsSync(path.join(ROOT, REL));
ok('the releases register exists', haveRel, REL);
if (haveRel) {
  const rel = read(REL);
  const relStamp = (rel.match(/Last updated (20\d\d-\d\d-\d\d)/) || [])[1];
  ok('the register says when it was last updated', !!relStamp);
  ok('the register is no older than the newest decision in ISSUES.md',
     !!relStamp && relStamp >= newestIssue,
     `register ${relStamp}, newest issue ${newestIssue} — something was decided and the field was not considered`);
  ok('every platform we ship to has a section',
     ['extension', 'Android', 'iOS', 'prototype'].every(p => new RegExp(p, 'i').test(rel)));
  /* The classification rule is the useful part: a change that breaks builds already installed has
     to be recognised as that before it merges, not after someone notices. */
  ok('the change-classification rule is stated', /class(ify|ification)/i.test(rel) && /\bD —|\bD —/.test(rel));
  /* A build known to be wrong in the field must say what the field needs, or the row is a diary
     entry rather than an obligation. */
  const broken = [...rel.matchAll(/^\|([^|]*)\|.*🔴.*$/gm)];
  ok('anything marked broken in the field says what has to happen to it',
     broken.every(m => /supersed|do not use|forced update|withdraw|moves to|Fixes/i.test(m[0])),
     `${broken.length} row(s) marked 🔴`);
}

console.log(`\n${pass} passed, ${fail} failed`);
process.exit(fail ? 1 : 0);
