// Sipcount calculation engine — same math and constants as app/assets/calc/models.json (v2026-09-14)
// and app/lib/features/calculation_engine/domain/water_calculator.dart. Pure functions, no I/O.
const SIP = (() => {
  const C = {
    version: '2026-09-14', charsPerToken: 4,
    tiers: { lightweight: { wh1k: 0.15, label: 'Light' }, standard: { wh1k: 0.75, label: 'Standard' }, reasoning: { wh1k: 7.5, label: 'Reasoning' } },
    tasks: { text: { out: 300, label: 'Text' }, code: { out: 600, label: 'Code' }, long_context: { out: 500, label: 'Long doc' }, image: { fixed: 2.9, label: 'Image' } },
    regions: { us_default: { pue: 1.15, site: 0.55, grid: 3.142, label: 'US grid' }, colo_average: { pue: 1.5, site: 1.8, grid: 3.142, label: 'Colo avg' } },
    range: { low: 0.2, high: 3.9 },
    eq: [['bottle', 500], ['coffee cup', 240], ['espresso', 30], ['sip', 15]],
    // vendor → substring patterns → tier (longest match wins)
    vendorMap: {
      openai:    { def: 'standard', p: { 'o1': 'reasoning', 'o3': 'reasoning', 'o4': 'reasoning', 'thinking': 'reasoning', 'pro': 'reasoning', 'mini': 'lightweight', 'nano': 'lightweight' } },
      anthropic: { def: 'standard', p: { 'extended': 'reasoning', 'haiku': 'lightweight' } },
      google:    { def: 'standard', p: { 'thinking': 'reasoning', 'deep think': 'reasoning', 'flash': 'lightweight', 'flash-lite': 'lightweight' } },
      unknown:   { def: 'standard', p: {} }
    }
  };
  const tok = ch => ch <= 0 ? 0 : Math.ceil(ch / C.charsPerToken);
  function resolveTier(vendor, hint) {
    const v = C.vendorMap[vendor] || C.vendorMap.unknown, h = (hint || '').toLowerCase();
    let best = null;
    for (const p in v.p) if (h.includes(p) && (!best || p.length > best.length)) best = p;
    return best ? v.p[best] : v.def;
  }
  function estimate({ tier, task, region = 'us_default', inputTokens = 0, items = 1 }) {
    const T = C.tiers[tier] || C.tiers.standard, K = C.tasks[task] || C.tasks.text, R = C.regions[region] || C.regions.us_default;
    let energy, tokens;
    if (K.fixed != null) { energy = K.fixed * items; tokens = 0; } else { tokens = inputTokens + K.out; energy = T.wh1k * tokens / 1000; }
    const f = energy * R.pue;
    return { energyWh: energy, s1: f * R.site, s2: f * R.grid, total: f * (R.site + R.grid), tokens };
  }
  function savingsIfLighter(tier, task, region, inputTokens) {
    const alt = tier === 'reasoning' ? 'standard' : tier === 'standard' ? 'lightweight' : null;
    if (!alt || task === 'image') return { alt: null, ml: 0 };
    return { alt, ml: estimate({ tier, task, region, inputTokens }).total - estimate({ tier: alt, task, region, inputTokens }).total };
  }
  const fmt = (n, d) => n.toLocaleString(undefined, { maximumFractionDigits: d ?? (n < 10 ? 1 : 0) });
  function equiv(ml) { for (const [l, v] of C.eq) if (ml >= v) return `${fmt(ml / v, 1)} ${l}${ml / v >= 1.95 ? 's' : ''}`; return `${fmt(ml / 15, 1)} of a sip`; }
  return { C, tok, resolveTier, estimate, savingsIfLighter, fmt, equiv };
})();
if (typeof module !== 'undefined') module.exports = SIP;
