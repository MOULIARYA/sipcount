#!/usr/bin/env node
/* Turn a calibration export into the numbers that replace the guesses.
   Run:  node tools/fit-calibration.js path/to/export.csv

   Three constants in engine.js are placeholders taken from literature ranges. This reads real
   turns and says what they should be, next to what they are, with the spread — because a fitted
   number from eight noisy turns deserves less confidence than one from eighty, and the output
   should say so rather than look authoritative.

   It proposes. It does not write. Anything adopted goes into docs/constants.json by hand, which
   is how it reaches installed apps without a release. */
const fs = require('fs'), path = require('path');
const ROOT = path.join(__dirname, '..');
const { C } = (new Function(fs.readFileSync(path.join(ROOT, 'engine.js'), 'utf8') + '\nreturn {C};'))();

const file = process.argv[2];
if (!file) { console.error('usage: node tools/fit-calibration.js <export.csv>'); process.exit(2); }

const lines = fs.readFileSync(file, 'utf8').trim().split(/\r?\n/);
const head = lines.shift().split(',').map(s => s.trim());
const rows = lines.filter(Boolean).map(l => {
  const v = l.split(','); const o = {};
  head.forEach((h, i) => { const x = (v[i] || '').trim(); o[h] = x === '' ? null : (isNaN(Number(x)) ? x : Number(x)); });
  return o;
});
if (!rows.length) { console.error('no rows in that file'); process.exit(1); }

const med = a => { if (!a.length) return null; const s = [...a].sort((x, y) => x - y); const m = s.length >> 1;
  return s.length % 2 ? s[m] : (s[m - 1] + s[m]) / 2; };
const iqr = a => { if (a.length < 4) return null; const s = [...a].sort((x, y) => x - y);
  return [s[Math.floor(s.length * 0.25)], s[Math.floor(s.length * 0.75)]]; };
const n2 = x => x === null || x === undefined ? '—' : (Math.round(x * 100) / 100).toString();

console.log(`\nRead ${rows.length} turns from ${path.basename(file)}`);
const byVendor = {};
for (const r of rows) byVendor[r.vendor] = (byVendor[r.vendor] || 0) + 1;
console.log('  ' + Object.entries(byVendor).map(([k, v]) => `${k} ${v}`).join(' · '));

const confidence = n => n >= 40 ? 'good' : n >= 15 ? 'thin — treat as indicative' : 'too few to trust';

/* ---- 1. tokens per second, from plain chat turns ------------------------------------------
   On a turn with no tools, the model generates only what you see. So rate × active seconds
   should equal the visible output, and the rate that makes that true is the real one. Turns
   where the model clearly did other work would drag the fit upward, so they are excluded. */
console.log('\n1 · HOW FAST THE MODEL GENERATES  (currently ' + C.thinking.tokensPerSec + ' tokens/second)');
{
  const plain = rows.filter(r => r.out_tokens > 40 && r.active_ms > 2000
    && r.task !== 'image'
    && r.active_ms / 1000 < 90                       // long turns are the ones that did other work
    && r.tier !== 'reasoning');                      // reasoning tiers price thinking differently
  const rates = plain.map(r => r.out_tokens / (r.active_ms / 1000 - C.thinking.floorSec))
                     .filter(x => isFinite(x) && x > 5 && x < 1000);
  const m = med(rates), q = iqr(rates);
  console.log(`  ${plain.length} plain turns used  (${confidence(plain.length)})`);
  if (m) {
    console.log(`  measured: ${n2(m)} tokens/second` + (q ? `   middle half ${n2(q[0])}–${n2(q[1])}` : ''));
    const drift = (m - C.thinking.tokensPerSec) / C.thinking.tokensPerSec * 100;
    console.log(`  → ${Math.abs(drift) < 10 ? 'the placeholder is about right' :
      drift > 0 ? `we are UNDER-counting unseen work by roughly ${Math.round(Math.abs(drift))}%`
                : `we are OVER-counting unseen work by roughly ${Math.round(Math.abs(drift))}%`}`);
    console.log(`  constants.json:  "thinking": { "tokensPerSec": ${Math.round(m)} }`);
    /* Against synthetic turns with a known rate this method reads about 3% LOW, consistently, at
       every rate tried (docs/test/fit.js). The bias comes from noise in the timing rather than
       from the data, so treat the figure as a floor rather than a centre. Not corrected here:
       a correction derived from my own generator would be fitting the generator, not reality. */
    console.log('  (this method reads ~3% low against known data — treat it as a floor)');
  } else console.log('  not enough plain chat turns — send more ordinary prompts');
}

/* ---- 2. characters per token, per script --------------------------------------------------
   Compared against the literature figures we ship. Needs the exact-token column, which only the
   scripted run produces; without it this reports the spread of what we assumed. */
console.log('\n2 · CHARACTERS PER TOKEN  (we assume ' + JSON.stringify(C.charsPerTokenByScript) + ')');
{
  const scripts = [...new Set(rows.map(r => r.out_script).filter(Boolean))];
  for (const s of scripts) {
    const rs = rows.filter(r => r.out_script === s && r.out_chars > 200 && r.exact_out_tokens > 0);
    if (rs.length) {
      const per = rs.map(r => r.out_chars / r.exact_out_tokens);
      console.log(`  ${s.padEnd(11)} measured ${n2(med(per))}  vs assumed ${C.charsPerTokenByScript[s]}   (${rs.length} turns)`);
    } else {
      const rs2 = rows.filter(r => r.out_script === s);
      console.log(`  ${s.padEnd(11)} ${rs2.length} turns, no exact token counts — run the scripted set (docs/calibration/PROTOCOL.md)`);
    }
  }
}

/* ---- 3. the context factor -----------------------------------------------------------------
   Prompts 13-17 of the protocol: one thread, the same kind of question, steadily more history.
   Cost per output token against context length is the factor, read straight off. */
console.log('\n3 · WHAT A LONG THREAD COSTS  (currently +' + (C.context.perThousand * 100) + '% per 1,000 tokens)');
{
  const usable = rows.filter(r => r.context_tokens > 0 && r.out_tokens > 50 && r.ml > 0);
  if (usable.length < 4) console.log(`  ${usable.length} turns with context recorded — need the threaded prompts (13–17)`);
  else {
    const pts = usable.map(r => ({ ctx: r.context_tokens, per: r.ml / r.out_tokens }));
    const lo = pts.filter(p => p.ctx < 2000), hi = pts.filter(p => p.ctx > 8000);
    if (lo.length && hi.length) {
      const base = med(lo.map(p => p.per)), deep = med(hi.map(p => p.per));
      const ctxHi = med(hi.map(p => p.ctx));
      const k = (deep / base - 1) / (ctxHi / 1000);
      console.log(`  short threads ${n2(base * 1000)} · long threads ${n2(deep * 1000)} (mL per 1k output tokens)`);
      console.log(`  measured: +${n2(k * 100)}% per 1,000 tokens of context   (${lo.length} short, ${hi.length} long)`);
      console.log(`  constants.json:  "context": { "perThousand": ${n2(k)}, "max": ${C.context.max} }`);
      console.log('  NOTE: this is circular unless the cost came from measurement rather than from');
      console.log('  our own factor — only trust it when the mL column was recorded with the factor off.');
    } else console.log('  need both short and long threads in the same export');
  }
}

/* ---- 4. what it all means for a real day ---------------------------------------------------- */
console.log('\n4 · WHAT THESE TURNS ACTUALLY COST');
{
  const byDay = {};
  for (const r of rows) { const d = String(r.t).slice(0, 10); byDay[d] = (byDay[d] || 0) + (r.ml || 0); }
  for (const [d, ml] of Object.entries(byDay))
    console.log(`  ${d}  ${Math.round(ml)} mL  (${Math.round(ml / C.defaultBudgetMl * 100)}% of the ${C.defaultBudgetMl} mL budget)`);
  const heavy = rows.filter(r => r.hidden_tokens > r.out_tokens);
  console.log(`  ${heavy.length} of ${rows.length} turns did more work off-screen than on`);
  if (heavy.length) console.log(`  the heaviest was ${Math.round(Math.max(...heavy.map(r => r.ml)))} mL`);
}

console.log('\nNothing was changed. Adopt a line by editing docs/constants.json, then:');
console.log('  node tools/build-shared.js && npm test\n');
