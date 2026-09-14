// Sipcount background service worker: receives PromptEvents, computes water, keeps
// daily counters in chrome.storage.local (on this device only), updates the badge.
importScripts('engine.js');

const KEY = 'sipcount.v1';
const dayKey = d => new Date(d).toISOString().slice(0, 10);
const defaults = () => ({ budget: 100, region: 'us_default', saved: 0, days: {}, last: null });

async function getState() { const r = await chrome.storage.local.get(KEY); return Object.assign(defaults(), r[KEY] || {}); }
async function setState(s) { await chrome.storage.local.set({ [KEY]: s }); }

async function handle(ev) {
  // Fail closed: refuse any payload carrying text.
  for (const k of ['text', 'prompt', 'content', 'body']) if (k in ev) return;
  const s = await getState();
  const tier = SIP.resolveTier(ev.vendor, ev.model_hint);
  const task = ['text', 'code', 'long_context', 'image'].includes(ev.task) ? ev.task : 'text';
  const inputTokens = SIP.tok(ev.char_count || 0);
  const e = SIP.estimate({ tier, task, region: s.region, inputTokens, items: 1 });
  const k = dayKey(Date.now());
  const b = s.days[k] || (s.days[k] = { n: 0, s1: 0, s2: 0, tier: {}, task: {}, vendor: {} });
  b.n++; b.s1 += e.s1; b.s2 += e.s2;
  b.tier[tier] = (b.tier[tier] || 0) + e.total;
  b.task[task] = (b.task[task] || 0) + e.total;
  b.vendor[ev.vendor] = (b.vendor[ev.vendor] || 0) + e.total;
  const sv = SIP.savingsIfLighter(tier, task, s.region, inputTokens);
  s.last = { ts: ev.ts, vendor: ev.vendor, tier, task, ml: e.total, tokens: e.tokens, energyWh: e.energyWh, altTier: sv.alt, altSavesMl: sv.ml, model_hint: ev.model_hint };
  // keep 400 days max
  const keys = Object.keys(s.days).sort(); while (keys.length > 400) delete s.days[keys.shift()];
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
  if (msg?.type === 'refresh_badge') { updateBadge().then(() => sendResponse({ ok: true })); return true; }
});
chrome.runtime.onInstalled.addListener(() => updateBadge());
chrome.runtime.onStartup.addListener(() => updateBadge());
