const KEY = 'sipcount.v1';
const $ = id => document.getElementById(id);
const dayKey = d => new Date(d).toISOString().slice(0, 10);
const VENDOR = { openai: 'ChatGPT', anthropic: 'Claude', google: 'Gemini', unknown: 'Other' };
const last7 = () => [...Array(7)].map((_, i) => { const d = new Date(); d.setDate(d.getDate() - (6 - i)); return dayKey(d); });

async function load() { const r = await chrome.storage.local.get(KEY); return Object.assign({ budget: 100, region: 'us_default', days: {}, last: null }, r[KEY] || {}); }
async function save(s) { await chrome.storage.local.set({ [KEY]: s }); chrome.runtime.sendMessage({ type: 'refresh_badge' }); }

async function render() {
  const s = await load(), fmt = SIP.fmt;
  const t = s.days[dayKey(Date.now())] || { n: 0, s1: 0, s2: 0 }, ml = t.s1 + t.s2, pct = Math.min(1, ml / s.budget);
  $('todayMl').textContent = fmt(ml, ml < 10 ? 1 : 0);
  $('todayEq').textContent = ml > 0 ? `≈ ${SIP.equiv(ml)} · likely ${fmt(ml * SIP.C.range.low, 1)}–${fmt(ml * SIP.C.range.high)} mL` : 'No prompts counted yet today';
  $('fill').style.width = (pct * 100) + '%'; $('fill').className = ml > s.budget ? 'over' : '';
  $('budgetLine').textContent = ml > s.budget ? `Over your ${s.budget} mL budget by ${fmt(ml - s.budget)} mL` : `${Math.round(pct * 100)}% of your ${s.budget} mL daily budget`;
  $('statusPill').className = 'pill' + (ml > s.budget ? ' warn' : ''); $('statusPill').textContent = ml > s.budget ? 'Over budget' : 'Watching';
  $('tPrompts').textContent = t.n;
  const keys = last7(), vals = keys.map(k => { const b = s.days[k]; return b ? b.s1 + b.s2 : 0; }), max = Math.max(1, ...vals);
  $('tWeek').textContent = fmt(vals.reduce((a, b) => a + b, 0)) + ' mL';
  $('bars').innerHTML = keys.map((k, i) => `<div class="bar"><i class="${i === 6 ? 'today' : ''}" style="height:${Math.max(3, vals[i] / max * 100)}%" title="${fmt(vals[i], 1)} mL"></i><em>${'SMTWTFS'[new Date(k + 'T12:00:00').getDay()]}</em></div>`).join('');
  const v = {}; keys.forEach(k => { const b = s.days[k]; if (b && b.vendor) for (const x in b.vendor) v[x] = (v[x] || 0) + b.vendor[x]; });
  $('byVendor').innerHTML = Object.entries(v).sort((a, b) => b[1] - a[1]).map(([x, m]) => `<div class="it"><span>${VENDOR[x] || x}</span><span>${fmt(m, 1)} mL</span></div>`).join('') || '<div class="it"><span>Send a prompt on ChatGPT, Claude or Gemini to start</span></div>';
  const L = s.last, n = $('last');
  if (!L) { n.className = 'nudge quiet'; n.textContent = 'Waiting for your first prompt. Keep this extension installed and use ChatGPT, Claude or Gemini as usual.'; }
  else {
    const when = new Date(L.ts * 1000).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
    const tip = L.altTier ? ` Simple task? A <b>${SIP.C.tiers[L.altTier].label.toLowerCase()} model</b> would have saved <b>${fmt(L.altSavesMl, 2)} mL</b>.` : '';
    n.className = 'nudge'; n.innerHTML = `Last prompt (${when}, ${VENDOR[L.vendor]}, ${SIP.C.tiers[L.tier].label.toLowerCase()}, ${SIP.C.tasks[L.task].label.toLowerCase()}): <b>${fmt(L.ml, 2)} mL</b>.${tip}`;
  }
  $('budget').value = s.budget;
}
$('budget').onchange = async e => { const s = await load(); s.budget = Math.max(10, +e.target.value || 100); await save(s); render(); };
$('clear').onclick = async () => { if (!confirm('Delete all totals stored in this browser?')) return; const s = await load(); s.days = {}; s.last = null; await save(s); render(); };
$('export').onclick = async () => {
  const s = await load(); const rows = [['date', 'prompts', 'scope1_cooling_ml', 'scope2_grid_ml', 'total_ml', 'constants_version']];
  Object.keys(s.days).sort().forEach(k => { const b = s.days[k]; rows.push([k, b.n, b.s1.toFixed(3), b.s2.toFixed(3), (b.s1 + b.s2).toFixed(3), SIP.C.version]); });
  await navigator.clipboard.writeText(rows.map(r => r.join(',')).join('\n')); $('export').textContent = 'Copied!'; setTimeout(() => $('export').textContent = 'Copy CSV', 1500);
};
render();
