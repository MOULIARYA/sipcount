/* Browser-extension behaviour, tested without a browser.
   Run:  node docs/test/extension.js        (no dependencies)

   Loads engine.js and background.js into one VM context the way Chrome's importScripts does, with
   a working in-memory chrome.storage, then drives real messages through the service worker.

   Why it exists: the reply-measurement work (I-18) changes the number AFTER the fact — count on an
   assumption, correct when the answer lands. That is exactly the kind of arithmetic that silently
   double-counts, and nothing else in the repo would notice. */
const fs = require('fs'), path = require('path'), vm = require('vm');
const ROOT = path.join(__dirname, '..', '..');
const load = p => fs.readFileSync(path.join(ROOT, p), 'utf8');

let pass = 0, fail = 0;
const ok = (name, cond, extra = '') => { if (cond) { pass++; console.log('  ✓', name); }
                                         else { fail++; console.log('  ✗', name, extra); } };
const near = (a, b, eps = 1e-6) => Math.abs(a - b) < eps;

/* ---- a Chrome-shaped sandbox ---- */
const store = {};
let onMessage = null;
const stub = () => {};
const sandbox = {
  console: { log: stub, warn: stub, error: stub }, setTimeout, clearTimeout,
  importScripts: stub, OffscreenCanvas: function () { return { getContext: () => ({ translate: stub, scale: stub, createLinearGradient: () => ({ addColorStop: stub }), fill: stub, stroke: stub, beginPath: stub, ellipse: stub, getImageData: () => ({}) }) }; },
  Path2D: function () {},
  chrome: {
    storage: { local: { get: async k => (k in store ? { [k]: store[k] } : {}), set: async o => Object.assign(store, o) } },
    runtime: { onMessage: { addListener: fn => { onMessage = fn; } }, onInstalled: { addListener: stub }, onStartup: { addListener: stub } },
    action: { setBadgeText: async () => {}, setBadgeBackgroundColor: async () => {}, setBadgeTextColor: async () => {}, setIcon: async () => {} }
  }
};
sandbox.globalThis = sandbox; sandbox.self = sandbox;
const ctx = vm.createContext(sandbox);
vm.runInContext(load('browser_extension/engine.js'), ctx, { filename: 'engine.js' });
vm.runInContext(load('browser_extension/background.js').replace(/^\s*importScripts\(.*$/m, ''), ctx, { filename: 'background.js' });

const send = msg => new Promise(res => { const kept = onMessage(msg, null, res); if (!kept) res(undefined); });
const state = () => store['sipcount.v1'];
const todayMl = () => { const s = state(); const d = s.days[Object.keys(s.days)[0]]; return d ? d.s1 + d.s2 : 0; };
const SIP = vm.runInContext('SIP', ctx);

(async () => {
  console.log('\nCOUNTING A TURN');
  const promptChars = 30, inTok = SIP.tok(promptChars);
  await send({ type: 'prompt_event', event: { v: 1, vendor: 'anthropic', turnId: 't1', model_hint: null, task: 'text', char_count: promptChars, attachment_count: 0, ts: Math.floor(Date.now() / 1000) } });
  const assumed = SIP.estimate({ tier: 'standard', task: 'text', region: state().region, inputTokens: inTok }).total;
  ok('a prompt is counted immediately, on the assumed answer', near(todayMl(), assumed), `${todayMl()} vs ${assumed}`);
  ok('and it is flagged as an estimate', state().last.estimated === true);
  ok('the turn is held open for correction', state().open && Object.keys(state().open).length === 1);

  console.log('\nCORRECTING IT WHEN THE ANSWER LANDS');
  const replyChars = 8000;                                   // ≈2,000 output tokens: a long answer
  await send({ type: 'prompt_reply', reply: { v: 1, turnId: 't1', reply_chars: replyChars, ttft_ms: 900, duration_ms: 12000 } });
  const measured = SIP.estimate({ tier: 'standard', task: 'text', region: state().region, inputTokens: inTok, outputTokens: SIP.tok(replyChars) }).total;
  ok('the day total becomes the MEASURED figure', near(todayMl(), measured), `${todayMl().toFixed(4)} vs ${measured.toFixed(4)}`);
  ok('which is much larger than the assumption', measured > assumed * 4, `${assumed.toFixed(2)} → ${measured.toFixed(2)} mL`);
  ok('it corrects rather than double-counting', !near(todayMl(), assumed + measured));
  ok('the turn stays open for further corrections', Object.keys(state().open).length === 1);
  ok('and the last-prompt line is no longer an estimate', state().last.estimated === false && state().last.outTokens === SIP.tok(replyChars));
  ok('per-brand and per-tier totals are corrected too', (() => {
    const d = state().days[Object.keys(state().days)[0]];
    return near(d.vendor.anthropic, measured) && near(d.tier.standard, measured);
  })());

  console.log('\nTHE AWKWARD CASES');
  /* Reports arrive repeatedly while the answer streams — an early one can land mid-answer (this
     happened live: a 4,000-character reply was finalised at 190 characters during a pause). Each
     report must move the total to the NEW measurement, never add the turn again. */
  await send({ type: 'prompt_reply', reply: { v: 1, turnId: 't1', reply_chars: 16000 } });
  const grown = SIP.estimate({ tier: 'standard', task: 'text', region: state().region, inputTokens: inTok, outputTokens: SIP.tok(16000) }).total;
  ok('a later, larger report replaces the earlier one', near(todayMl(), grown), `${todayMl().toFixed(3)} vs ${grown.toFixed(3)}`);
  ok('and does not add the turn twice', todayMl() < measured + grown);
  await send({ type: 'prompt_reply', reply: { v: 1, turnId: 't1', reply_chars: 16000 } });
  ok('an identical repeat changes nothing', near(todayMl(), grown));
  await send({ type: 'prompt_reply', reply: { v: 1, turnId: 'never-seen', reply_chars: 5000 } });
  ok('an unknown turn changes nothing', near(todayMl(), grown));

  const before = todayMl();
  await send({ type: 'prompt_event', event: { v: 1, vendor: 'google', turnId: 't2', model_hint: 'flash', task: 'text', char_count: 30, attachment_count: 0, ts: Math.floor(Date.now() / 1000) } });
  await send({ type: 'prompt_reply', reply: { v: 1, turnId: 't2', reply_chars: 0 } });
  ok('an empty answer still costs the input', todayMl() > before);
  ok('a light model costs far less than a standard one', todayMl() - before < assumed);

  console.log('\nCALIBRATION RECORD (N11)');
  /* The data that retires the two guesses in the engine — the 5× output multiplier and the
     90 tokens/second rate — by replacing them with measurements. Off unless asked for. */
  {
    const before = (state().cal || []).length;
    await send({ type: 'prompt_event', event: { v: 1, vendor: 'openai', turnId: 'c1', model_hint: 'gpt-5 thinking', task: 'code', char_count: 120, script: 'latin', attachment_count: 0, ts: Math.floor(Date.now() / 1000) } });
    await send({ type: 'prompt_reply', reply: { v: 1, turnId: 'c1', reply_chars: 4000, reply_script: 'latin', ttft_ms: 900, active_ms: 30000, duration_ms: 32000 } });
    ok('nothing is recorded unless calibration is on', (state().cal || []).length === before);

    state().calibrate = true;
    await send({ type: 'prompt_event', event: { v: 1, vendor: 'anthropic', turnId: 'c2', model_hint: 'opus 5.5', task: 'text', char_count: 200, script: 'devanagari', attachment_count: 0, ts: Math.floor(Date.now() / 1000) } });
    await send({ type: 'prompt_reply', reply: { v: 1, turnId: 'c2', reply_chars: 9000, reply_script: 'devanagari', ttft_ms: 1200, active_ms: 240000, duration_ms: 245000 } });
    const row = state().cal[state().cal.length - 1];
    ok('a turn is recorded once switched on', !!row);
    ok('it carries what a coefficient needs', ['in_chars', 'out_chars', 'in_tokens', 'out_tokens', 'active_ms', 'ttft_ms', 'hidden_tokens', 'ml', 'region', 'vendor', 'tier', 'in_script', 'out_script'].every(k => k in row),
       Object.keys(row).join(', '));
    ok('and no field long enough to be a prompt', Object.values(row).every(v => typeof v !== 'string' || v.length <= 64));
    ok('the unseen work is recorded alongside the visible', row.hidden_tokens > 1000 && row.out_tokens > 1000);
    ok('the script is kept, so Hindi turns can be fitted separately', row.in_script === 'devanagari');
    for (let i = 0; i < 520; i++) state().cal.push({ t: Date.now() });
    await send({ type: 'prompt_event', event: { v: 1, vendor: 'google', turnId: 'c3', model_hint: 'flash', task: 'text', char_count: 20, script: 'latin', attachment_count: 0, ts: Math.floor(Date.now() / 1000) } });
    await send({ type: 'prompt_reply', reply: { v: 1, turnId: 'c3', reply_chars: 500, reply_script: 'latin', ttft_ms: 600, active_ms: 4000, duration_ms: 5000 } });
    ok('the log is capped and cannot grow without bound', state().cal.length <= 500, String(state().cal.length));
    state().calibrate = false;
  }

  console.log('\nTHE TEST BRIDGE LEAKS NOTHING');
  const dbg = await send({ type: 'debug_state' });
  ok('returns counts only', dbg.ok && typeof dbg.today === 'object' && dbg.region);
  /* What would a leak look like? A long string. Everything legitimate here is a number, a boolean,
     or a short label — region ids, brand names, tier and task names, a model label capped at 60. */
  const strings = [], keys = [];
  (function walk(v, k) {
    if (k) keys.push(k);
    if (typeof v === 'string') strings.push(v);
    else if (v && typeof v === 'object') for (const kk of Object.keys(v)) walk(v[kk], kk);
  })(dbg, null);
  ok('carries no free text, only short labels', strings.every(s => s.length <= 64),
     JSON.stringify(strings.filter(s => s.length > 64).slice(0, 2)));
  ok('and no field that could hold a prompt', !keys.some(k => /prompt|message|body|content|text_|_text/i.test(k)),
     keys.filter(k => /prompt|message|body|content|text_|_text/i.test(k)).join(', '));
  ok('content.js gates the bridge behind ?sipcount_debug=1', /sipcount_debug=1/.test(load('browser_extension/content.js')));

  console.log('\nTHE PAGE HOOK HAS WHAT IT NEEDS');
  /* content.js calls SIP.scriptOf(). Content scripts do NOT share the service worker's scope, so
     if the manifest does not load engine.js alongside content.js, SIP is undefined, the send
     handler throws, and NOTHING is counted — silently, with the page looking perfectly normal.
     That shipped on 2026-09-30 and was caught only by sending a real prompt. */
  const manifest = JSON.parse(load('browser_extension/manifest.json'));
  const csJs = manifest.content_scripts[0].js;
  const usesSip = /\bSIP\./.test(load('browser_extension/content.js'));
  ok('the content script can reach everything it calls', !usesSip || csJs.includes('engine.js'),
     `content.js uses SIP but the manifest loads only: ${csJs.join(', ')}`);
  ok('and content.js is loaded after it', csJs.indexOf('engine.js') < csJs.indexOf('content.js'));
  ok('the service worker imports it too', /importScripts\(['"]engine\.js/.test(load('browser_extension/background.js')));

  console.log('\nWHAT THE PAGE HOOK SENDS');
  const c = load('browser_extension/content.js');
  ok('the reply is measured by LENGTH, never captured', /reply_chars/.test(c) && !/reply_text|innerText\s*\)\s*;\s*chrome\.runtime/.test(c));
  ok('timing is recorded for reasoning detection', /ttft_ms/.test(c));
  ok('measurement stops rather than watching forever', /setTimeout\(stopAll, 300000\)/.test(c));
  ok('it waits while the model is still writing', /aria-label\*="Stop"/.test(c) && /generating\(\)/.test(c));
  ok('reports are cumulative, not one-shot', /if \(grew === reported\) return/.test(c));

  console.log(`\n${pass} passed, ${fail} failed`);
  process.exit(fail ? 1 : 0);
})();
