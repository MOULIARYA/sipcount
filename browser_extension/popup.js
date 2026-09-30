const KEY = 'sipcount.v1';
const $ = id => document.getElementById(id);
const dayKey = d => new Date(d).toISOString().slice(0, 10);
const VENDOR = { openai: 'ChatGPT', anthropic: 'Claude', google: 'Gemini', unknown: 'Other' };
const last7 = () => [...Array(7)].map((_, i) => { const d = new Date(); d.setDate(d.getDate() - (6 - i)); return dayKey(d); });

async function load() { const r = await chrome.storage.local.get(KEY); const s = Object.assign({ budget: SIP.C.defaultBudgetMl, region: SIP.DEFAULT_REGION, days: {}, last: null }, r[KEY] || {});
  if (!SIP.C.regions[s.region]) s.region = SIP.DEFAULT_REGION;   // migrate the old two-region ids
  return s; }
async function save(s) { await chrome.storage.local.set({ [KEY]: s }); chrome.runtime.sendMessage({ type: 'refresh_badge' }); }

/* The same drop as the app, draining as the day is spent — it is the product's one image, and the
   extension looked nothing like the product without it. */
const DROP = (level, colour) => { const y = 130 * (1 - level); return `<svg viewBox="0 0 100 130">
  <defs><clipPath id="dc"><path d="M50 4 C50 4 12 52 12 82 a38 38 0 0 0 76 0 C88 52 50 4 50 4 Z"/></clipPath></defs>
  <path d="M50 4 C50 4 12 52 12 82 a38 38 0 0 0 76 0 C88 52 50 4 50 4 Z" fill="#131313"/>
  <g clip-path="url(#dc)"><rect class="fill" x="0" y="0" width="100" height="130" fill="${colour}" style="transform:translateY(${y}px)"/></g>
  <!-- The outline carries the zone colour so an empty drop reads as EMPTY rather than as a
       missing image. In the app the character carries that moment; here there is no character. -->
  <path d="M50 4 C50 4 12 52 12 82 a38 38 0 0 0 76 0 C88 52 50 4 50 4 Z" fill="none"
        stroke="${colour}" stroke-opacity="${level < 0.06 ? 0.85 : 0.35}" stroke-width="2"/></svg>`; };

async function render() {
  const s = await load(), fmt = SIP.fmt;
  const t = s.days[dayKey(Date.now())] || { n: 0, s1: 0, s2: 0 }, ml = t.s1 + t.s2, pct = Math.min(1, ml / s.budget);
  const z = SIP.zone(ml / s.budget), ui = SIP.ZONE_UI[z];
  const colour = { green: '#00F076', amber: '#FFB800', red: '#FF3B30' }[z];
  $('todayMl').textContent = fmt(ml, ml < 10 ? 1 : 0);
  /* the app's own words, not "4.1 espressos" */
  $('todayEq').textContent = ml > 0
    ? `${SIP.opportunityCost(ml)} Likely ${fmt(ml * SIP.C.range.low, 1)}–${fmt(ml * SIP.C.range.high)} mL.`
    : 'Nothing counted yet today. Use ChatGPT, Claude or Gemini and come back.';
  $('drop').innerHTML = DROP(Math.max(0, 1 - pct), colour);
  $('fill').style.width = (pct * 100) + '%'; $('fill').className = z === 'green' ? '' : z;
  $('budgetLine').textContent = ml > s.budget ? `Over your ${s.budget} mL budget by ${fmt(ml - s.budget)} mL` : `${Math.round(pct * 100)}% of your ${s.budget} mL daily budget`;
  $('statusPill').className = 'pill ' + { green: 'good', amber: 'warn', red: 'bad' }[z];
  $('statusPill').textContent = `${ui.ico} ${ml > s.budget ? 'Over budget' : ui.label}`;
  $('tPrompts').textContent = t.n;
  const keys = last7(), vals = keys.map(k => { const b = s.days[k]; return b ? b.s1 + b.s2 : 0; }), max = Math.max(1, ...vals);
  $('tWeek').textContent = fmt(vals.reduce((a, b) => a + b, 0)) + ' mL';
  // today's bar carries the day's zone colour — a green bar on a red day reads as a contradiction
  $('bars').innerHTML = keys.map((k, i) => `<div class="bar"><i class="${i === 6 ? 'today' : ''}"${i === 6 ? ` style="height:${Math.max(3, vals[i] / max * 100)}%;background:${colour}"` : ` style="height:${Math.max(3, vals[i] / max * 100)}%"`} title="${fmt(vals[i], 1)} mL"></i><em>${'SMTWTFS'[new Date(k + 'T12:00:00').getDay()]}</em></div>`).join('');
  const v = {}; keys.forEach(k => { const b = s.days[k]; if (b && b.vendor) for (const x in b.vendor) v[x] = (v[x] || 0) + b.vendor[x]; });
  $('byVendor').innerHTML = Object.entries(v).sort((a, b) => b[1] - a[1]).map(([x, m]) => `<div class="it"><span>${VENDOR[x] || x}</span><span>${fmt(m, 1)} mL</span></div>`).join('') || '<div class="it"><span>Send a prompt on ChatGPT, Claude or Gemini to start</span></div>';
  const L = s.last, n = $('last');
  if (!L) { n.className = 'nudge quiet'; n.textContent = 'Waiting for your first prompt. Keep this extension installed and use ChatGPT, Claude or Gemini as usual.'; }
  else {
    const when = new Date(L.ts * 1000).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
    const tip = L.thinking ? ` Most of that was work you never saw — research, tools, files — about <b>${fmt(L.hiddenTokens || 0, 0)}</b> tokens of it.`
      : L.altTier ? ` Simple task? A <b>${SIP.C.tiers[L.altTier].label.toLowerCase()} model</b> would have saved <b>${fmt(L.altSavesMl, 2)} mL</b>.` : '';
    n.className = 'nudge'; n.innerHTML = `Last prompt (${when}, ${VENDOR[L.vendor]}, ${SIP.C.tiers[L.tier].label.toLowerCase()}, ${SIP.C.tasks[L.task].label.toLowerCase()}): <b>${fmt(L.ml, 2)} mL</b>.${tip}`;
  }
  $('budget').value = s.budget;
  $('calibrate').checked = !!s.calibrate;
  const calRows = (s.cal || []).length;
  $('calNote').textContent = s.calibrate
    ? `Recording one row per turn — ${calRows} so far. Counts and timings only, never text. Export and send it over.`
    : 'Off. Switch on to record counts and timings per turn, so the estimates can be replaced by measurements.';
  $('region').innerHTML = Object.entries(SIP.C.regions).map(([id, r]) => `<option value="${id}">${r.label}</option>`).join('');
  $('region').value = s.region;
  const R = SIP.C.regions[s.region];
  const one = SIP.estimate({ tier: 'standard', task: 'text', region: s.region, inputTokens: 100, outputTokens: 300 }).total;
  $('regionNote').textContent = `${R.short}: a typical prompt ≈ ${fmt(one, 2)} mL`;
}
$('budget').onchange = async e => { const s = await load(); s.budget = Math.max(10, +e.target.value || SIP.C.defaultBudgetMl); await save(s); render(); };
$('calibrate').onchange = async e => { const s = await load(); s.calibrate = e.target.checked; await save(s); render(); };
/* Changing the region only affects prompts counted from here on — past days keep the numbers they
   were recorded with, because re-stating history with today's setting would be a different lie. */
$('region').onchange = async e => { const s = await load(); if (SIP.C.regions[e.target.value]) s.region = e.target.value; await save(s); render(); };
$('clear').onclick = async () => { if (!confirm('Delete all totals stored in this browser?')) return; const s = await load(); s.days = {}; s.last = null; await save(s); render(); };
/* With calibration rows recorded, export those — they are the point of the exercise. Otherwise
   export the day totals, which is also the proof that we hold nothing but counts. */
$('export').onclick = async () => {
  const s = await load(); let rows;
  if (s.calibrate && (s.cal || []).length) {
    const cols = ['t', 'vendor', 'tier', 'task', 'model', 'in_chars', 'in_script', 'in_tokens',
                  'out_chars', 'out_script', 'out_tokens', 'ttft_ms', 'active_ms', 'duration_ms',
                  'hidden_tokens', 'ml', 'region'];
    rows = [cols.concat('constants_version')];
    for (const r of s.cal) rows.push(cols.map(c => c === 't' ? new Date(r.t).toISOString()
      : (r[c] === null || r[c] === undefined ? '' : String(r[c]).replace(/[",\n]/g, ' '))).concat(SIP.C.version));
  } else {
    rows = [['date', 'prompts', 'scope1_cooling_ml', 'scope2_grid_ml', 'total_ml', 'constants_version']];
    Object.keys(s.days).sort().forEach(k => { const b = s.days[k]; rows.push([k, b.n, b.s1.toFixed(3), b.s2.toFixed(3), (b.s1 + b.s2).toFixed(3), SIP.C.version]); });
  }
  await navigator.clipboard.writeText(rows.map(r => r.join(',')).join('\n'));
  $('export').textContent = `Copied ${rows.length - 1}`; setTimeout(() => $('export').textContent = 'Copy CSV', 1800);
};
render();
