// Sipcount background service worker: receives PromptEvents, computes water, keeps
// daily counters in chrome.storage.local (on this device only), updates the badge.
importScripts('engine.js');

const KEY = 'sipcount.v1';
const dayKey = d => new Date(d).toISOString().slice(0, 10);
/* region ids now come from the shared engine (7 regions, not 2). Anything unrecognised falls
   back to SIP.DEFAULT_REGION inside the adapter, so an old stored 'us_default' still works. */
const defaults = () => ({ budget: SIP.C.defaultBudgetMl, region: 'us_hyperscale', saved: 0, days: {}, last: null, health: {} });

/* How many separate days a site must look wrong before we say so. One day is noise: a cold load,
   a slow network, a page that never finished rendering. Two different days is a redesign. */
const HEALTH_DAYS_BEFORE_WARNING = 2;

/**
 * Keep a verdict per site on whether this extension still understands its page.
 *
 * Stores day strings and small counters — never a URL, never text, never a timestamp finer than
 * the calendar day. That is the same bar as the counters themselves, so this adds nothing new to
 * what the privacy page already promises.
 */
async function handleHealth(h) {
  if (!['openai', 'anthropic', 'google'].includes(h.vendor)) return;
  const s = await getState();
  const today = dayKey(Date.now());
  const v = (s.health[h.vendor] ||= { okDay: null, missDay: null, missDays: 0, modelMissDay: null, modelMissDays: 0 });

  if (h.composerFound) {
    // A good sighting clears the slate: whatever was wrong is wrong no longer.
    v.okDay = today; v.missDays = 0; v.missDay = null;
  } else if (v.missDay !== today) {
    // once per day, so a tab left open all afternoon cannot manufacture a warning
    v.missDay = today; v.missDays++;
  }

  /* A model name we cannot read is a quieter fault than a composer we cannot find, and a more
     expensive one: it silently prices a reasoning prompt as a standard one, which was a ~10×
     undercount when it last happened (I-42). Tracked separately so the popup can say which. */
  if (h.modelExpected) {
    if (h.modelFound) { v.modelMissDays = 0; v.modelMissDay = null; }
    else if (v.modelMissDay !== today) { v.modelMissDay = today; v.modelMissDays++; }
  }
  await setState(s);
}

/** Sites that have looked wrong on enough separate days to tell the user about. */
function healthWarnings(s) {
  const NAMES = { openai: 'ChatGPT', anthropic: 'Claude', google: 'Gemini' };
  const out = [];
  for (const [vendor, v] of Object.entries(s.health || {})) {
    if (!v) continue;
    if (v.missDays >= HEALTH_DAYS_BEFORE_WARNING) out.push({ site: NAMES[vendor] || vendor, kind: 'blind' });
    else if (v.modelMissDays >= HEALTH_DAYS_BEFORE_WARNING) out.push({ site: NAMES[vendor] || vendor, kind: 'model' });
  }
  return out;
}

async function getState() { const r = await chrome.storage.local.get(KEY); return Object.assign(defaults(), r[KEY] || {}); }
async function setState(s) { await chrome.storage.local.set({ [KEY]: s }); }

async function handle(ev) {
  // Fail closed: refuse any payload carrying text.
  for (const k of ['text', 'prompt', 'content', 'body']) if (k in ev) return;
  const s = await getState();
  const tier = SIP.resolveTier(ev.vendor, ev.model_hint);
  const task = ['text', 'code', 'long_context', 'image'].includes(ev.task) ? ev.task : 'text';
  const inputTokens = SIP.tok(ev.char_count || 0, ev.script);
  // the conversation the model must re-read, counted the same way at first estimate and at
  // correction — otherwise the number moves for a reason that has nothing to do with the answer
  const contextTokens = SIP.tok((ev.context_chars || 0) + (ev.char_count || 0), ev.script);
  const e = SIP.estimate({ tier, task, region: s.region, inputTokens, contextTokens, items: 1 });
  const k = dayKey(Date.now());
  const b = s.days[k] || (s.days[k] = { n: 0, s1: 0, s2: 0, tier: {}, task: {}, vendor: {} });
  b.n++; b.s1 += e.s1; b.s2 += e.s2;
  b.tier[tier] = (b.tier[tier] || 0) + e.total;
  b.task[task] = (b.task[task] || 0) + e.total;
  b.vendor[ev.vendor] = (b.vendor[ev.vendor] || 0) + e.total;
  const sv = SIP.savingsIfLighter(tier, task, s.region, inputTokens);
  s.last = { ts: ev.ts, vendor: ev.vendor, tier, task, ml: e.total, tokens: e.tokens, energyWh: e.energyWh, altTier: sv.alt, altSavesMl: sv.ml, model_hint: ev.model_hint, estimated: true };
  /* Remember enough to correct this turn once the answer has finished arriving. Counts only —
     no text, and the record is dropped as soon as it is used or the hour is up. */
  if (ev.turnId) {
    s.open = s.open || {};
    s.open[ev.turnId] = { day: k, tier, task, vendor: ev.vendor, inputTokens, script: ev.script, charCount: ev.char_count, modelHint: ev.model_hint, contextTokens, ml: e.total, s1: e.s1, s2: e.s2, at: Date.now() };
    for (const id of Object.keys(s.open)) if (Date.now() - s.open[id].at > 3600000) delete s.open[id];
  }
  // keep 400 days max
  const keys = Object.keys(s.days).sort(); while (keys.length > 400) delete s.days[keys.shift()];
  await setState(s);
  await updateBadge(s);
}

/* The answer has landed, so replace the assumed reply length with the measured one (I-18).
   The first figure was a guess by necessity — the reply had not been written yet — so this
   subtracts what we assumed and adds what actually happened. */
async function handleReply(r) {
  const s = await getState();
  const o = s.open && s.open[r.turnId];
  if (!o) return;                                   // unknown or expired turn: leave what we have
  const b = s.days[o.day];
  if (b) {
    const outTokens = SIP.tok(r.reply_chars || 0, r.reply_script);
    // work done before a word appeared: tool calls, reasoning, files written
    const hiddenTokens = SIP.hiddenFrom({ activeMs: r.active_ms, outputTokens: outTokens, tier: o.tier });
    const fresh = SIP.estimate({ tier: o.tier, task: o.task, region: s.region, inputTokens: o.inputTokens, outputTokens: outTokens, hiddenTokens, contextTokens: o.contextTokens });
    // Apply only the difference from whatever was last recorded for this turn. Reports arrive
    // repeatedly as the answer grows, so this must be idempotent — adding the turn again each
    // time would inflate the day badly on a long answer.
    b.s1 += fresh.s1 - o.s1; b.s2 += fresh.s2 - o.s2;
    const d = fresh.total - o.ml;
    b.tier[o.tier] = (b.tier[o.tier] || 0) + d;
    b.task[o.task] = (b.task[o.task] || 0) + d;
    b.vendor[o.vendor] = (b.vendor[o.vendor] || 0) + d;
    Object.assign(o, { ml: fresh.total, s1: fresh.s1, s2: fresh.s2, at: Date.now(), outTokens });
    /* Calibration (I-30 / N11). Off unless switched on in the popup. One row per turn: counts and
       timings only, never text — the same boundary as everything else. This is the data that
       replaces the two guesses in the engine, the 5x output multiplier and the 90 tokens/second
       rate, with measured numbers. Capped so it can never grow without bound. */
    if (s.calibrate) {
      s.cal = s.cal || [];
      s.cal.push({ t: Date.now(), vendor: o.vendor, tier: o.tier, task: o.task, model: o.modelHint || null,
        in_chars: o.charCount, in_script: o.script, in_tokens: o.inputTokens,
        out_chars: r.reply_chars, out_script: r.reply_script, out_tokens: outTokens, context_tokens: o.contextTokens,
        ttft_ms: r.ttft_ms, active_ms: r.active_ms, duration_ms: r.duration_ms,
        hidden_tokens: hiddenTokens, ml: +fresh.total.toFixed(4), region: s.region });
      while (s.cal.length > 500) s.cal.shift();
    }
    if (s.last && s.last.ts && Math.abs(Date.now() / 1000 - s.last.ts) < 3600) {
      s.last = Object.assign({}, s.last, { ml: fresh.total, tokens: fresh.weightedTokens, energyWh: fresh.energyWh,
        outTokens, hiddenTokens, // more work happened off-screen than on: self-scaling, unlike an arbitrary threshold
        thinking: hiddenTokens > outTokens, ttftMs: r.ttft_ms, estimated: false,
        altSavesMl: SIP.savingsIfLighter(o.tier, o.task, s.region, o.inputTokens, outTokens, hiddenTokens).ml });
    }
  }
  await setState(s);
  await updateBadge(s);
}

// Draw the Sipcount droplet (same shape as the prototype) — no image files needed.
function drawDrop(size, over) {
  const c = new OffscreenCanvas(size, size), g = c.getContext('2d');
  const k = (size * 0.94) / 130, ox = (size - 100 * k) / 2, oy = (size - 130 * k) / 2;
  g.translate(ox, oy); g.scale(k, k);
  const p = new Path2D('M50 4 C50 4 12 52 12 82 a38 38 0 0 0 76 0 C88 52 50 4 50 4 Z');
  const grad = g.createLinearGradient(20, 30, 80, 120);
  if (over) { grad.addColorStop(0, '#FFB08A'); grad.addColorStop(1, '#FF6A3D'); } else { grad.addColorStop(0, '#9FD9FF'); grad.addColorStop(1, '#2E8BD6'); }
  g.fillStyle = grad; g.fill(p);
  g.strokeStyle = 'rgba(13,19,33,.35)'; g.lineWidth = 3; g.stroke(p);
  g.fillStyle = 'rgba(255,255,255,.55)'; g.beginPath(); g.ellipse(34, 78, 9, 16, -0.35, 0, Math.PI * 2); g.fill();
  return g.getImageData(0, 0, size, size);
}
let iconState = null;
async function setIcon(over) {
  if (iconState === over) return; iconState = over;
  const imageData = {}; for (const s of [16, 24, 32, 48, 128]) imageData[s] = drawDrop(s, over);
  await chrome.action.setIcon({ imageData });
}

async function updateBadge(s) {
  s = s || await getState();
  const t = s.days[dayKey(Date.now())]; const ml = t ? t.s1 + t.s2 : 0;
  await setIcon(ml > s.budget);
  const text = ml === 0 ? '' : ml < 10 ? ml.toFixed(1) : ml < 1000 ? String(Math.round(ml)) : (ml / 1000).toFixed(1) + 'L';
  await chrome.action.setBadgeText({ text });
  await chrome.action.setBadgeBackgroundColor({ color: ml > s.budget ? '#FF8A5B' : '#3A9BE0' });
  await chrome.action.setBadgeTextColor?.({ color: '#FFFFFF' });
}

chrome.runtime.onMessage.addListener((msg, _sender, sendResponse) => {
  if (msg?.type === 'prompt_event' && msg.event?.v === 1) { handle(msg.event).then(() => sendResponse({ ok: true })); return true; }
  if (msg?.type === 'prompt_reply' && msg.reply?.v === 1) { handleReply(msg.reply).then(() => sendResponse({ ok: true })); return true; }
  if (msg?.type === 'refresh_badge') { updateBadge().then(() => sendResponse({ ok: true })); return true; }
  if (msg?.type === 'site_health' && msg.vendor) { handleHealth(msg).then(() => sendResponse({ ok: true })); return true; }
  if (msg?.type === 'health') { getState().then(s => sendResponse({ ok: true, warnings: healthWarnings(s) })); return true; }
  /* Test hook. Returns counts only — the same numbers the popup shows — and only ever in
     response to a request from our own content script on a page carrying ?sipcount_debug=1.
     It exists because Chrome will not let an automated test read chrome.storage directly, and
     "we could not test it" is how the last three faults shipped. */
  if (msg?.type === 'debug_state') {
    getState().then(s => { const t = s.days[dayKey(Date.now())] || null;
      sendResponse({ ok: true, region: s.region, budget: s.budget, today: t, last: s.last,
                     openTurns: Object.keys(s.open || {}).length,
                     health: s.health || {}, warnings: healthWarnings(s) }); });
    return true;
  }
});
chrome.runtime.onInstalled.addListener(() => updateBadge());
chrome.runtime.onStartup.addListener(() => updateBadge());
