#!/usr/bin/env node
/* =====================================================================================
   THE RELEASE PIPELINE IS CHECKED LIKE CODE (I-75, I-76).

   Three builds in one day failed for reasons no test could see: a dependency that moved under
   us (build 30, 31), and a CI step written in bash but run one line at a time by `sh` (run 32).
   Each was readable in the repository before the push. This suite reads it.

   It does not run the pipeline — it checks that the pipeline is the one we meant to write:
   dependencies pinned and guarded, the published APK launched on an emulator before release,
   the launch script a real file that parses, the runners pinned, and the boot marker the app
   prints being the one the script waits for.

   Run: node docs/test/ci.js
   ===================================================================================== */
const fs = require('fs'), path = require('path'), { execFileSync } = require('child_process');
const ROOT = path.join(__dirname, '..', '..');
const read = f => fs.readFileSync(path.join(ROOT, f), 'utf8');

let pass = 0, fail = 0;
const ok = (name, cond, detail = '') => {
  if (cond) { pass++; console.log('  ✓ ' + name); }
  else { fail++; console.log('  ✗ ' + name + (detail ? '  — ' + detail : '')); }
};

const apk = read('.github/workflows/android-apk.yml');
const pubspec = read('app/pubspec.yaml');
const main = read('app/lib/main.dart');

console.log('\nNOTHING IN THE BUILD MOVES WITHOUT US (I-75)');
{
  const sp = pubspec.match(/^\s*shared_preferences:\s*(\S+)\s*$/m);
  ok('shared_preferences is pinned to an exact version', !!sp && /^\d+\.\d+\.\d+$/.test(sp[1]), sp ? sp[1] : 'not found');
  const spa = pubspec.match(/^\s*shared_preferences_android:\s*(\S+)\s*$/m);
  ok('shared_preferences_android is held at an exact version', !!spa && /^\d+\.\d+\.\d+$/.test(spa[1]), spa ? spa[1] : 'not found');
  ok('…under dependency_overrides, where it actually takes effect',
     /dependency_overrides:[\s\S]*?shared_preferences_android:/.test(pubspec));
  /* The CI guard must look for the SAME version the pubspec pins, or a future pin change passes
     pubspec and fails CI (or worse, the guard checks a stale number and passes anything). */
  const guard = apk.match(/shared_preferences_android (\d+\\\.\d+\\\.\d+)/);
  ok('CI guards the resolved version', !!guard, 'no grep for the resolved version in android-apk.yml');
  ok('…and the guard checks the version the pubspec pins',
     !!guard && !!spa && guard[1].replace(/\\/g, '') === spa[1],
     guard && spa ? `guard ${guard[1].replace(/\\/g, '')} vs pubspec ${spa[1]}` : '');
  ok('CI prints the toolchain and the full dependency list', /flutter --version/.test(apk) && /flutter pub deps/.test(apk));
}

console.log('\nTHE PUBLISHED APK IS LAUNCHED ON AN ANDROID FIRST (I-74 / I-75)');
{
  ok('a boot-check job exists', /^\s{2}boot-check:/m.test(apk));
  ok('boot-check runs after the build', /boot-check:\s*\n\s*needs:\s*build/.test(apk));
  ok('publishing waits for the boot check', /publish:\s*\n\s*needs:\s*boot-check/.test(apk));
  ok('the emulator is hardware-accelerated (KVM enabled)', /kvm/i.test(apk));
  ok('the APK that is checked is the APK that is published (same artifact)',
     (apk.match(/name: sipcount-android-apk/g) || []).length >= 3);
}

console.log('\nTHE LAUNCH SCRIPT IS A FILE THAT PARSES (I-76)');
{
  /* The emulator action runs `script:` one line at a time with sh. A multi-line bash block there
     is split into fragments; `set -euo pipefail` on its own exits 2, which is exactly how run 32
     died. So the script must be ONE line that calls a file. */
  const scriptLines = [...apk.matchAll(/^\s*script:\s*(.*)$/gm)].map(m => m[1].trim());
  ok('the emulator action has a script', scriptLines.length >= 1);
  ok('…written as one line, not a block', scriptLines.every(s => s !== '|' && s !== '>' && s.length > 0), scriptLines.join(' / '));
  const files = scriptLines.map(s => (s.match(/(\.github\/scripts\/[\w.-]+\.sh)/) || [])[1]).filter(Boolean);
  ok('…that calls a script file under .github/scripts', files.length === scriptLines.length, scriptLines.join(' / '));
  for (const f of files) {
    const exists = fs.existsSync(path.join(ROOT, f));
    ok(`${f} exists`, exists);
    if (!exists) continue;
    const src = read(f);
    ok(`${f} is bash with strict mode`, /^#!\/usr\/bin\/env bash/.test(src) && /set -euo pipefail/.test(src));
    let parses = true, err = '';
    try { execFileSync('bash', ['-n', path.join(ROOT, f)], { stdio: 'pipe' }); } catch (e) { parses = false; err = String(e.stderr || e.message).trim(); }
    ok(`${f} parses (bash -n)`, parses, err);
    /* The marker the script waits for must be the marker the app prints. */
    ok('the script waits for the boot marker the app prints',
       /SIPCOUNT_BOOT \(ok\|failed\)/.test(src) && /SIPCOUNT_BOOT ok/.test(src));
    ok('the script fails on a dead process', /pidof/.test(src) && /exit 1/.test(src));
  }
  ok('the app prints "SIPCOUNT_BOOT ok" when its first screen is up', /print\('SIPCOUNT_BOOT ok/.test(main));
  ok('…and "SIPCOUNT_BOOT failed: <reason>" from the error screen', /print\('SIPCOUNT_BOOT failed: \$e'\)/.test(main));
  ok('the markers use print, which survives a release build', !/debugPrint\('SIPCOUNT_BOOT/.test(main));
}

console.log('\nTHE RUNNERS DO NOT MOVE UNDER US EITHER');
{
  const workflows = fs.readdirSync(path.join(ROOT, '.github', 'workflows')).filter(f => /\.ya?ml$/.test(f));
  const floating = [];
  for (const w of workflows) for (const m of read('.github/workflows/' + w).matchAll(/runs-on:\s*(\S+)/g)) if (/-latest/.test(m[1])) floating.push(`${w}: ${m[1]}`);
  ok('every runs-on names a version, never -latest', floating.length === 0, floating.join(', '));
}

console.log('\nTHE START-UP TESTS RUN ON EVERY BUILD (I-74)');
{
  ok('app/test/startup_test.dart exists', fs.existsSync(path.join(ROOT, 'app/test/startup_test.dart')));
  ok('the APK workflow runs the whole test folder, not a subset', /^\s*- run: flutter test\s*$/m.test(apk));
  const st = read('app/test/startup_test.dart');
  ok('start-up is tested with no bridge, a healthy bridge and a broken bridge',
     /no Android bridge/.test(st) && /healthy bridge/.test(st) && /throws on every call/.test(st));
  ok('the error screen is tested on a throw and on a hang', /start-up throws/.test(st) && /start-up hangs/.test(st));
}

console.log(`\n${pass} passed, ${fail} failed`);
process.exit(fail ? 1 : 0);
