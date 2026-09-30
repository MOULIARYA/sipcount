/* End-to-end simulation of a real conversation, without a browser.
   Run:  node docs/test/simulate.js        (needs jsdom)

   Loads engine.js and content.js into a jsdom page the way the manifest loads them, wires the
   messages it sends into a real background.js running in a VM, then plays out a conversation:
   the user types, presses Enter, and an answer streams in chunk by chunk with pauses — the way
   models actually behave.

   Every fault this project has hit in the last week was of a kind unit tests could not see:
     · the content script threw because the manifest did not load the engine → counted NOTHING
     · the reply was finalised during a pause → measured 190 of 4,000 characters
     · Gemini re-sends the whole answer each chunk → a naive measure double-counts
   Each now has a scenario below. Timers run 50× faster so a 25-second idle window costs 0.5s. */
let JSDOM; try { ({ JSDOM } = require('jsdom')); }
catch (e) { console.error('jsdom is missing. Run:  npm install jsdom'); process.exit(2); }
const fs = require('fs'), path = require('path'), vm = require('vm');
const ROOT = path.join(__dirname, '..', '..');
const load = p => fs.readFileSync(path.join(ROOT, p), 'utf8');
const SPEED = 50;

let pass = 0, fail = 0;
const ok = (n, c, x = '') => { if (c) { pass++; console.log('  ✓', n); } else { fail++; console.log('  ✗', n, x); } };
const near = (a, b, tol = 0.02) => Math.abs(a - b) <= Math.abs(b) * tol + 1e-9;
const wait = ms => new Promise(r => setTimeout(r, ms));

/* ---- a service worker, for real ---- */
function makeWorker() {
  const store = {}; let onMessage = null; const stub = () => {};
  const sb = { console: { log: stub, warn: stub, error: stub }, setTimeout, clearTimeout, importScripts: stub,
    OffscreenCanvas: function () { return { getContext: () => ({ translate: stub, scale: stub, createLinearGradient: () => ({ addColorStop: stub }), fill: stub, stroke: stub, beginPath: stub, ellipse: stub, getImageData: () => ({}) }) }; },
    Path2D: function () {},
    chrome: { storage: { local: { get: async k => (k in store ? { [k]: store[k] } : {}), set: async o => Object.assign(store, o) } },
      runtime: { onMessage: { addListener: f => { onMessage = f; } }, onInstalled: { addListener: stub }, onStartup: { addListener: stub } },
      action: { setBadgeText: async () => {}, setBadgeBackgroundColor: async () => {}, setBadgeTextColor: async () => {}, setIcon: async () => {} } } };
  sb.globalThis = sb; sb.self = sb;
  const ctx = vm.createContext(sb);
  vm.runInContext(load('browser_extension/engine.js'), ctx);
  vm.runInContext(load('browser_extension/background.js').replace(/^\s*importScripts\(.*$/m, ''), ctx);
  return {
    send: msg => new Promise(res => { const kept = onMessage(msg, null, res); if (!kept) res(); }),
    state: () => store['sipcount.v1'],
    ml: () => { const s = store['sipcount.v1']; if (!s) return 0; const d = s.days[Object.keys(s.days)[0]]; return d ? d.s1 + d.s2 : 0; },
    prompts: () => { const s = store['sipcount.v1']; if (!s) return 0; const d = s.days[Object.keys(s.days)[0]]; return d ? d.n : 0; },
    SIP: vm.runInContext('SIP', ctx)
  };
}

/* ---- a page that behaves like the real thing ---- */
function makePage(host, worker, { loadEngine = true } = {}) {
  const dom = new JSDOM(`<!doctype html><html><body>
      <main><div id="convo"></div></main>
      <form><textarea id="prompt-textarea"></textarea>
      <button data-testid="send-button" aria-label="Send message">Send</button></form>
      <div id="controls"></div></body></html>`,
    { url: `https://${host}/`, runScripts: 'outside-only', pretendToBeVisual: true });
  const w = dom.window;
  // jsdom has no innerText; the extension uses it to measure length, so map it to textContent
  Object.defineProperty(w.HTMLElement.prototype, 'innerText',
    { get() { return this.textContent; }, set(v) { this.textContent = v; }, configurable: true });
  const realST = w.setTimeout;
  w.setTimeout = (fn, ms) => realST(fn, Math.max(0, Math.round((ms || 0) / SPEED)));
  const sent = [];
  w.chrome = { runtime: { sendMessage: (msg, cb) => { sent.push(msg); worker.send(msg).then(r => cb && cb(r)); } } };
  /* Chrome runs each content-script file as a classic script in ONE shared isolated world, so a
     top-level `const SIP` in engine.js is visible to content.js. `eval` does not work that way —
     each call gets its own lexical scope — so the binding is published explicitly here. Without
     this the simulation silently exercised the fallback path and reported false confidence. */
  if (loadEngine) w.eval(load('browser_extension/engine.js') + '\n;window.SIP = SIP;');
  w.eval(load('browser_extension/content.js'));
  const d = w.document;
  return {
    w, d, sent,
    type(text) { const t = d.getElementById('prompt-textarea'); t.value = text; t.focus(); },
    enter() { d.getElementById('prompt-textarea').dispatchEvent(new w.KeyboardEvent('keydown', { key: 'Enter', bubbles: true })); },
    writing(on) { d.getElementById('controls').innerHTML = on ? '<button aria-label="Stop responding">Stop</button>' : ''; },
    append(t) { d.getElementById('convo').textContent += t; },
    replace(t) { d.getElementById('convo').textContent = t; },   // Gemini: each chunk is cumulative
    echoPrompt(t) { d.getElementById('convo').textContent += t; }
  };
}

/* one answer, streamed the way a model streams it */
async function stream(page, text, { chunks = 8, gapMs = 30, pauseAfter = -1, pauseMs = 0, cumulative = false } = {}) {
  page.writing(true);
  const size = Math.ceil(text.length / chunks);
  let soFar = '';
  for (let i = 0; i < chunks; i++) {
    soFar += text.slice(i * size, (i + 1) * size);
    cumulative ? page.replace(soFar) : page.append(text.slice(i * size, (i + 1) * size));
    await wait(gapMs);
    if (i === pauseAfter) await wait(pauseMs);      // the model stops to think
  }
  page.writing(false);
  await wait(3000 / SPEED + 120);                   // let the settle timer fire
}

(async () => {
  const LONG = 'Photosynthesis converts light into chemical energy. '.repeat(80);   // ≈4,000 chars

  console.log('\n1 · SHORT QUESTION, LONG ANSWER — the whole point');
  {
    const wk = makeWorker(), p = makePage('chatgpt.com', wk);
    p.type('Explain how photosynthesis works in about 600 words'); p.enter();
    await wait(60);
    const early = wk.ml();
    p.echoPrompt('Explain how photosynthesis works in about 600 words');
    await stream(p, LONG);
    const S = wk.SIP, st = wk.state();
    const expect = S.estimate({ tier: 'standard', task: 'text', region: st.region, inputTokens: S.tok(50), outputTokens: S.tok(LONG.length) }).total;
    ok('counted once', wk.prompts() === 1);
    ok('the estimate lands first', early > 0);
    ok('then the MEASURED answer replaces it', near(wk.ml(), expect, 0.06), `${wk.ml().toFixed(2)} vs ${expect.toFixed(2)} mL`);
    ok('which is far bigger than the estimate', wk.ml() > early * 3, `${early.toFixed(2)} → ${wk.ml().toFixed(2)} mL`);
  }

  console.log('\n2 · THE MODEL PAUSES MID-ANSWER (the 2026-09-29 fault)');
  {
    const wk = makeWorker(), p = makePage('claude.ai', wk);
    p.type('Explain photosynthesis'); p.enter(); await wait(60);
    await stream(p, LONG, { chunks: 10, pauseAfter: 2, pauseMs: 4000 / SPEED + 200 });
    const S = wk.SIP;
    const expect = S.estimate({ tier: 'standard', task: 'text', region: wk.state().region, inputTokens: S.tok(22), outputTokens: S.tok(LONG.length) }).total;
    ok('a long pause does not finalise the measurement early', near(wk.ml(), expect, 0.08), `${wk.ml().toFixed(2)} vs ${expect.toFixed(2)} mL`);
    ok('and it is not still counted as an estimate', wk.state().last.estimated === false);
  }

  console.log('\n3 · GEMINI RE-SENDS THE WHOLE ANSWER EACH CHUNK');
  {
    const wk = makeWorker(), p = makePage('gemini.google.com', wk);
    p.type('Explain photosynthesis'); p.enter(); await wait(60);
    await stream(p, LONG, { chunks: 12, cumulative: true });
    const S = wk.SIP;
    const expect = S.estimate({ tier: 'standard', task: 'text', region: wk.state().region, inputTokens: S.tok(22), outputTokens: S.tok(LONG.length) }).total;
    ok('cumulative chunks are not counted twelve times', near(wk.ml(), expect, 0.08), `${wk.ml().toFixed(2)} vs ${expect.toFixed(2)} mL`);
  }

  console.log('\n4 · FIVE PROMPTS IN A ROW');
  {
    const wk = makeWorker(), p = makePage('chatgpt.com', wk);
    for (let i = 0; i < 5; i++) {
      p.type(`Question number ${i} about photosynthesis`); p.enter(); await wait(1400);
      await stream(p, 'A short answer. '.repeat(10), { chunks: 3 });
    }
    ok('exactly five counts, no double counting', wk.prompts() === 5, `got ${wk.prompts()}`);
    ok('the total is five answers, not one', wk.ml() > 0);
  }

  console.log('\n5 · A HINDI ANSWER COSTS MORE THAN AN ENGLISH ONE');
  {
    const en = makeWorker(), pe = makePage('chatgpt.com', en);
    pe.type('Explain photosynthesis'); pe.enter(); await wait(60);
    await stream(pe, 'Photosynthesis converts light. '.repeat(60), { chunks: 4 });
    const hi = makeWorker(), ph = makePage('chatgpt.com', hi);
    ph.type('Explain photosynthesis'); ph.enter(); await wait(60);
    await stream(ph, 'प्रकाश संश्लेषण प्रकाश को ऊर्जा में बदलता है। '.repeat(40), { chunks: 4 });
    ok('same-length answers, Hindi costs more', hi.ml() > en.ml() * 1.15, `en ${en.ml().toFixed(2)} vs hi ${hi.ml().toFixed(2)} mL`);
  }

  console.log('\n6 · THE ANSWER NEVER FINISHES');
  {
    const wk = makeWorker(), p = makePage('chatgpt.com', wk);
    p.type('Explain photosynthesis'); p.enter(); await wait(60);
    p.writing(true); p.append(LONG.slice(0, 1200));
    await wait(26000 / SPEED + 300);                    // the idle cap fires
    ok('a stalled answer is still measured, not lost', wk.ml() > 0);
    ok('and what was written is counted', wk.state().last.outTokens > 100, `${wk.state().last.outTokens} tokens`);
  }

  console.log('\n7 · THE ENGINE IS MISSING FROM THE PAGE (the 2026-09-30 fault)');
  {
    const wk = makeWorker(), p = makePage('chatgpt.com', wk, { loadEngine: false });
    p.type('Explain photosynthesis'); p.enter(); await wait(120);
    ok('the prompt is STILL counted rather than silently lost', wk.prompts() === 1, `got ${wk.prompts()}`);
  }

  console.log('\n8 · A TURN THAT WORKS FOR MINUTES AND SHOWS A PARAGRAPH');
  /* The real case: five minutes of web fetches, reading data and writing a spreadsheet, ending in
     a few paragraphs. Charged as a short chat turn it came to 1 mL — about 28× too little. This
     one genuinely spends ~6 seconds working, so the timing is real rather than mocked. */
  {
    const wk = makeWorker(), p = makePage('claude.ai', wk);
    p.type('Do a world car analysis by engine type and country with trends'); p.enter();
    await wait(60);
    p.writing(true);
    /* Chunks must arrive faster than the (scaled) idle window or the turn closes between them —
       25 s of real stillness is 500 ms here. Twenty chunks at 300 ms ≈ 6 s of genuine work. */
    for (let i = 0; i < 20; i++) { p.append('Searching… '); await wait(300); }   // tool calls, no real output
    p.append('A short summary of the findings. '.repeat(8));                      // the visible answer
    await wait(200); p.writing(false);
    await wait(3000 / SPEED + 250);
    const st = wk.state(), last = st.last;
    ok('the time it spent working is recorded', last.hiddenTokens > 200, `${last.hiddenTokens} unseen tokens`);
    ok('and flagged as thinking', last.thinking === true);
    ok('the water is far more than the visible text alone', (() => {
      const S = wk.SIP;
      const visibleOnly = S.estimate({ tier: last.tier, task: 'text', region: st.region, inputTokens: 16, outputTokens: last.outTokens }).total;
      return wk.ml() > visibleOnly * 2;
    })(), `${wk.ml().toFixed(1)} mL total`);
    ok('the saving claim stays smaller than the turn', Math.abs(last.altSavesMl) < wk.ml());
  }

  console.log(`\n${pass} passed, ${fail} failed`);
  process.exit(fail ? 1 : 0);
})();
