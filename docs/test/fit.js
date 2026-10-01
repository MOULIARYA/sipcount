/* Does the calibration fitter actually recover a number it has never been told?
   Run:  node docs/test/fit.js        (no dependencies)

   The fitter will be used once, on real data, to replace a constant that decides most of the
   product's headline number. If it is quietly wrong, we would adopt a wrong constant with more
   confidence than the guess it replaced — worse than not fitting at all. So: generate turns from
   a rate the fitter cannot see, and check it finds it. */
const fs = require('fs'), path = require('path'), { execFileSync } = require('child_process');
const ROOT = path.join(__dirname, '..', '..');
const SIP = (new Function('module', fs.readFileSync(path.join(ROOT, 'browser_extension/engine.js'), 'utf8') + '\nreturn SIP;'))({});

let pass = 0, fail = 0;
const ok = (n, c, x = '') => { if (c) { pass++; console.log('  ✓', n); } else { fail++; console.log('  ✗', n, x); } };

const COLS = ['t','vendor','tier','task','model','in_chars','in_script','in_tokens','out_chars','out_script',
              'out_tokens','context_tokens','ttft_ms','active_ms','duration_ms','hidden_tokens','ml','region','constants_version'];

function synth(trueRate, turns, noise, seed = 1) {
  let s = seed; const R = () => { s = (s * 1103515245 + 12345) & 0x7fffffff; return s / 0x7fffffff; };
  const rows = [COLS.join(',')];
  for (let i = 0; i < turns; i++) {
    const out = Math.round(120 + R() * 1400);
    const active = Math.round((out / trueRate + SIP.C.thinking.floorSec) * 1000 * (1 - noise / 2 + R() * noise));
    const inChars = Math.round(30 + R() * 300), ctx = Math.round(R() * 1500);
    const hidden = SIP.hiddenFrom({ activeMs: active, outputTokens: out, tier: 'standard' });
    const e = SIP.estimate({ tier: 'standard', task: 'text', region: 'india', inputTokens: SIP.tok(inChars), outputTokens: out, hiddenTokens: hidden, contextTokens: ctx });
    rows.push([new Date(Date.now() - i * 6e4).toISOString(), 'anthropic', 'standard', 'text', 'opus 5.5',
      inChars, 'latin', SIP.tok(inChars), out * 4, 'latin', out, ctx, 900, active, active + 800, hidden,
      e.total.toFixed(4), 'india', SIP.C.version].join(','));
  }
  const f = path.join(require('os').tmpdir(), `sipcount-fit-${trueRate}-${turns}.csv`);
  fs.writeFileSync(f, rows.join('\n') + '\n');
  return f;
}
const fitted = out => { const m = out.match(/measured: ([\d.]+) tokens\/second/); return m ? Number(m[1]) : null; };
const run = f => execFileSync(process.execPath, [path.join(ROOT, 'tools', 'fit-calibration.js'), f], { encoding: 'utf8' });

console.log('\nRECOVERING A RATE THE FITTER CANNOT SEE');
for (const trueRate of [70, 90, 118, 125]) {
  const got = fitted(run(synth(trueRate, 48, 0.16)));
  const err = got === null ? null : Math.abs(got - trueRate) / trueRate * 100;
  const shown = err === null ? 'no fit' : err.toFixed(1) + '% out';
  ok(`true ${trueRate} → fitted ${got} (${shown})`, err !== null && err < 10);
}

console.log('\nIT SAYS WHEN IT DOES NOT KNOW ENOUGH');
{
  const thin = run(synth(100, 6, 0.16));
  ok('a handful of turns is called out as thin', /too few to trust|thin/.test(thin));
  const many = run(synth(100, 60, 0.16));
  ok('a proper sample is called good', /\(good\)/.test(many));
  ok('missing exact token counts are reported, not guessed at', /no exact token counts/.test(many));
  ok('missing threaded turns are reported, not guessed at', /need both short and long threads|need the threaded/.test(many));
}

console.log('\nIT PROPOSES, IT NEVER WRITES');
{
  const before = fs.readFileSync(path.join(ROOT, 'docs', 'constants.json'), 'utf8');
  run(synth(118, 48, 0.16));
  ok('constants.json is untouched by a fit', fs.readFileSync(path.join(ROOT, 'docs', 'constants.json'), 'utf8') === before);
  ok('and it prints the line to adopt', /"thinking": \{ "tokensPerSec": \d+ \}/.test(run(synth(118, 48, 0.16))));
}

console.log(`\n${pass} passed, ${fail} failed`);
process.exit(fail ? 1 : 0);
