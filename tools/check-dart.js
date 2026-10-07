#!/usr/bin/env node
/**
 * Static checks on the Dart that do not need a Dart toolchain.
 *
 * WHY THIS EXISTS. `storage.googleapis.com` is blocked by the sandbox allowlist, and that is where
 * both the Dart SDK and Flutter's engine artifacts come from — so the assistant writing this code
 * cannot run `flutter analyze` or `flutter test` at all. Every Dart fact is unverifiable until CI
 * runs, and over two days that produced five round trips, each one costing Madhur a push and a
 * wait:
 *
 *   1. `TierProfile` had no `label`              — a missing member
 *   2. `Matrix4.translate`/`scale` deprecated     — a stale API
 *   3. `firstOrNull` needs package:collection     — a method that is not in dart:core
 *   4. `ConstrainedBox` is not a const constructor
 *   5. a widget test asserting animated text on the first frame
 *
 * Four of those five are detectable by reading the source. This script reads it. It is not a
 * substitute for the analyzer — it is the part of the analyzer that can run where the analyzer
 * cannot, and it runs in under a second next to the JS suites rather than three minutes into CI.
 *
 * Run: node tools/check-dart.js
 */
const fs = require('fs');
const path = require('path');

const ROOT = path.join(__dirname, '..');
const APP = path.join(ROOT, 'app');

let pass = 0;
const problems = [];
const ok = (name, bad, hint = '') => {
  if (bad.length === 0) { pass++; console.log('  ✓ ' + name); return; }
  console.log('  ✗ ' + name);
  for (const b of bad) console.log('      ' + b);
  if (hint) console.log('      → ' + hint);
  problems.push(name);
};

const walk = d => !fs.existsSync(d) ? [] : fs.readdirSync(d, { withFileTypes: true }).flatMap(e =>
  e.isDirectory() ? walk(path.join(d, e.name)) : (e.name.endsWith('.dart') ? [path.join(d, e.name)] : []));

const libFiles = walk(path.join(APP, 'lib'));
const testFiles = walk(path.join(APP, 'test'));
const all = [...libFiles, ...testFiles];
const rel = f => path.relative(APP, f).replace(/\\/g, '/');
const read = f => fs.readFileSync(f, 'utf8');

/** Source with comments and string literals removed, so punctuation inside them cannot confuse us. */
const code = src => src
  .replace(/\/\/.*$/gm, '')
  .replace(/\/\*[\s\S]*?\*\//g, '')
  .replace(/'''[\s\S]*?'''/g, "''")
  .replace(/"""[\s\S]*?"""/g, '""')
  .replace(/'(?:\\.|[^'\\\n])*'/g, "''")
  .replace(/"(?:\\.|[^"\\\n])*"/g, '""');

console.log('\nTHE SOURCE IS WELL FORMED');
{
  const bad = [];
  for (const f of all) {
    const c = code(read(f));
    for (const [open, close, what] of [['{', '}', 'braces'], ['(', ')', 'parens'], ['[', ']', 'brackets']]) {
      const n = c.split(open).length - c.split(close).length;
      if (n !== 0) bad.push(`${rel(f)}: ${what} off by ${n}`);
    }
  }
  ok('every file balances its brackets', bad);
}
{
  const bad = [];
  for (const f of all) {
    for (const m of read(f).matchAll(/import '(\.{1,2}\/[^']+)'/g)) {
      if (!fs.existsSync(path.resolve(path.dirname(f), m[1]))) bad.push(`${rel(f)} -> ${m[1]}`);
    }
    for (const m of read(f).matchAll(/import 'package:ai_water\/([^']+)'/g)) {
      if (!fs.existsSync(path.join(APP, 'lib', m[1]))) bad.push(`${rel(f)} -> package:ai_water/${m[1]}`);
    }
  }
  ok('every import points at a file that exists', bad);
}

console.log('\nNOTHING REACHES FOR WHAT IS NOT THERE');
{
  /* Methods people reach for that live in package:collection, not dart:core. Cost one CI round. */
  const collectionOnly = ['firstOrNull', 'lastOrNull', 'singleOrNull', 'firstWhereOrNull',
                          'whereNotNull', 'sortedBy', 'groupListsBy', 'mapIndexed', 'equalsIgnoreAsciiCase'];
  const pubspec = read(path.join(APP, 'pubspec.yaml'));
  const hasCollection = /^\s+collection:/m.test(pubspec);
  const bad = [];
  if (!hasCollection) {
    for (const f of all) {
      const c = code(read(f));
      for (const m of collectionOnly) {
        if (new RegExp('\\.' + m + '\\b').test(c)) bad.push(`${rel(f)}: .${m} needs package:collection`);
      }
    }
  }
  ok('no method that silently needs package:collection', bad,
     'either add the dependency on purpose or write it in plain dart:core');
}
{
  /* Flutter widgets whose constructors are NOT const, usually because of an assert that calls a
     method. Nothing at the call site hints at it; `ConstrainedBox` cost one CI round. */
  const notConst = ['ConstrainedBox', 'Container', 'ListView', 'GridView', 'InkWell', 'TextButton',
                    'OutlinedButton', 'FilledButton', 'ElevatedButton', 'IconButton', 'TextField',
                    'Slider', 'Switch', 'Checkbox', 'DropdownButton', 'DropdownButtonFormField',
                    'AnimatedSwitcher', 'AnimatedContainer', 'TweenAnimationBuilder', 'CustomScrollView',
                    'SingleChildScrollView', 'PageView', 'Scrollbar', 'RefreshIndicator'];
  const bad = [];
  for (const f of all) {
    const c = code(read(f));
    for (const w of notConst) {
      if (new RegExp('\\bconst\\s+' + w + '\\s*\\(').test(c)) bad.push(`${rel(f)}: const ${w}(`);
    }
  }
  ok('no const on a widget whose constructor is not const', bad,
     'drop the const — it is an optimisation, and prefer_const_constructors will suggest it where valid');
}
{
  /* Deprecated APIs that have bitten us. Each entry is one that reached CI. */
  const deprecated = [[/Matrix4[\s\S]{0,40}\.\.translate\(/, 'Matrix4..translate is deprecated'],
                      [/Matrix4[\s\S]{0,40}\.\.scale\(/, 'Matrix4..scale is deprecated'],
                      [/\.withOpacity\(/, '.withOpacity is deprecated — use .withValues(alpha:)']];
  const bad = [];
  for (const f of all) {
    const c = code(read(f));
    for (const [re, why] of deprecated) if (re.test(c)) bad.push(`${rel(f)}: ${why}`);
  }
  ok('no deprecated API we have already been bitten by', bad);
}

console.log('\nWIDGET TESTS DO NOT ASSERT BEFORE THE FRAME EXISTS');
{
  /* The failure this is written for: `launch_sequence_test.dart` asserted the final value of a
     figure that counts up over 1,200 ms, on the first frame, where it still read "0". Static and
     obvious once stated — an `expect` on text between `pumpWidget` and any advance of the clock. */
  const bad = [];
  for (const f of testFiles) {
    const src = read(f);
    const blocks = [...src.matchAll(/testWidgets\((['"])(.*?)\1[\s\S]*?\n  \}\);/g)];
    for (const b of blocks) {
      const body = b[0];
      const name = b[2];
      const mount = body.search(/pumpWidget|\bshow\(/);
      if (mount === -1) continue;
      const after = body.slice(mount);
      const advance = after.search(/pump\(\s*(const\s*)?Duration|pumpAndSettle/);
      const assertAt = after.search(/expect\(\s*find\.(text|textContaining)/);
      if (assertAt !== -1 && (advance === -1 || assertAt < advance)) {
        // An assertion on STATIC text is fine; flag only when the test also looks for a number,
        // which is what animates in this app.
        const firstAssert = after.slice(assertAt, assertAt + 200);
        if (/\d/.test(firstAssert)) {
          bad.push(`${rel(f)}: "${name}" asserts text containing a number before advancing the clock`);
        }
      }
    }
  }
  ok('no assertion on animated text before the clock advances', bad,
     'pump past the animation first, or assert the static label instead of the moving number');
}

console.log('\nTEST EXPECTATIONS COME FROM THE GENERATOR, NOT FROM MEMORY');
{
  /* Numbers typed into a test are a guess; numbers read from models.v2.json are a contract. This
     caught nothing today but is the rule that turned the `fmt` bug from a mystery into a fixture. */
  const fixtures = ['golden', 'hidden_rule', 'fmt_cases'];
  const src = testFiles.map(read).join('\n');
  const bad = fixtures.filter(k => !src.includes(k));
  ok('the generated fixtures are all exercised by a test', bad.map(k => `no test reads "${k}"`));
}

console.log(`\n${pass} check(s) passed${problems.length ? `, ${problems.length} FAILED` : ''}`);
if (problems.length) {
  console.log('\nThese are the classes of fault that have cost a CI round each. Fix before pushing.');
  process.exit(1);
}
