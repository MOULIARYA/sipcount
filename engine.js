/* =====================================================================================
   Sipcount shared engine + constants (2026-09-21). Used by sipcount.html — the single prototype.
   (The v8 "Aqua" branch was dropped at the product owner's request, round 14.)
   Mirrors app/assets/calc/models.json + WaterCalculator.dart
   (I-16: Dart still to be synced to input/output weighting).

   Formula: total_mL = E_Wh × PUE × (WUE_site + EWIF_grid)
     E_Wh (text tasks) = wh_per_1k_weighted_tokens × (in × w_in + out × w_out) / 1000
     E_Wh (image)      = fixed_wh × items
   Token weighting (I-28, LOW confidence): output tokens are generated one at a time
   (autoregressive decode) and are less compute-efficient than parallel input processing.
   We weight output 5× input and re-normalise so the calibrated reference prompt
   (100 in + 300 out ≈ 0.30 Wh standard tier) is unchanged: 400 plain tokens = 320 weighted
   → wh1k_weighted = wh1k_plain × WEIGHT_NORM, where WEIGHT_NORM is derived from the multiplier
   below rather than hardcoded, so the calibration survives the multiplier being replaced
   (1.25 at 5×, 1.20 at 3×, 1.32 at 10×). Evidence and open items: docs/TOKEN-ECONOMICS.md.
   ===================================================================================== */
/* ---------- the one number we expect to be wrong ------------------------------------------------
   OUTPUT_PER_INPUT is how much more an output token costs than an input token. 5 is the central
   estimate of a 3–10× range in the literature — a placeholder, not a finding (D-22). It gets
   replaced by a measured, per-platform coefficient from the I-30 calibration.

   Everything below is DERIVED from it, so replacing it is a one-line change. The published per-1k
   figures are calibrated against a reference prompt (100 in + 300 out ≈ 0.30 Wh on a standard
   model), and weighting tokens changes what "1k tokens" means — so the per-1k figure has to be
   re-normalised by the same ratio, or the calibrated prompt silently drifts. That normalisation
   used to be the literal `400/320`, which would have quietly broken the moment anyone changed the
   multiplier. It is now computed. docs/TOKEN-ECONOMICS.md has the evidence.                      */
const OUTPUT_PER_INPUT = 5;
const REFERENCE_PROMPT = { inputTokens: 100, outputTokens: 300 };   // the calibrated query, 0.30 Wh
const TOKEN_WEIGHTS = { input: 1 / OUTPUT_PER_INPUT, output: 1 };
const _refPlain    = REFERENCE_PROMPT.inputTokens + REFERENCE_PROMPT.outputTokens;
const _refWeighted = REFERENCE_PROMPT.inputTokens * TOKEN_WEIGHTS.input + REFERENCE_PROMPT.outputTokens * TOKEN_WEIGHTS.output;
const WEIGHT_NORM  = _refPlain / _refWeighted;                      // 1.25 at 5×, 1.20 at 3×, 1.32 at 10×

const SIPCOUNT_CONFIG = {
  version: '2026-09-30',
  charsPerToken: 4,
  /* Characters per token is not language-neutral, and treating it as if it were under-counts the
     people we most want to reach. English runs ≈4 chars/token on all three vendors' tokenizers;
     Devanagari ≈3–3.5 on o200k and far worse on older ones; Hinglish worse again; code ≈3–3.5.
     (TOKEN-ECONOMICS §2.) The sensor classifies the SCRIPT of what it counted — a label, never the
     text — and we divide accordingly. An exact tokenizer is the proper fix (N8) and is a large
     dependency; this captures most of the error for ten lines and no download. */
  charsPerTokenByScript: { latin: 4, devanagari: 3.2, hinglish: 3.0, cjk: 1.6, code: 3.4, mixed: 3.6 },
  /* Work you never see. A turn that takes five minutes before a word appears is not idle — the
     model is generating the whole time: reasoning, calling tools, reading what they return,
     writing a spreadsheet. Only the final prose reaches the screen, so measuring the visible
     answer alone under-counted a real five-minute research turn by about 28× (2026-09-30).
     TOKEN-ECONOMICS §4: T_hidden ≈ tokens/s × (TTFT − 1.5 s), output speeds 70–125 tokens/s.
     **Confidence: LOW.** This is the second placeholder after the 5× multiplier, and the same
     calibration (I-30) replaces it with a measured rate. */
  thinking: { tokensPerSec: 90, floorSec: 1.5, maxSec: 900 },
  /* A long conversation costs more per word of answer. Generating each output token re-reads the
     whole context, so the twentieth message in a thread is dearer than the first even if the reply
     is identical — and heavy users live in long threads, so ignoring this under-counts exactly the
     people who matter most. ML.ENERGY v3 measured ≈ +8% per extra 1,000 tokens of context on one
     model at production batch; +3–8%/1k is the recommended modelling range (TOKEN-ECONOMICS §3).
     We take the middle. Capped, because the factor must not run away on a very long thread.
     **Confidence: LOW** — the third placeholder, and the same calibration replaces it. */
  context: { perThousand: 0.05, max: 4 },
  outputPerInput: OUTPUT_PER_INPUT,
  referencePrompt: REFERENCE_PROMPT,
  weightNormalisation: WEIGHT_NORM,
  tokenWeights: TOKEN_WEIGHTS,
  /* `base` is the published per-1k figure for plain tokens; `wh1k` is it re-normalised for weighted
     tokens. Keeping the base means the multiplier can be re-fitted later without losing the source
     number — see recalibrate(). */
  tiers: { lightweight:{base:0.15,wh1k:0.15*WEIGHT_NORM,label:'Light'}, standard:{base:0.75,wh1k:0.75*WEIGHT_NORM,label:'Standard'}, reasoning:{base:7.5,wh1k:7.5*WEIGHT_NORM,label:'Reasoning'} },
  tasks: { text:{out:300,label:'Text'}, code:{out:600,label:'Code'}, long_context:{out:500,label:'Long doc'}, image:{fixed:2.9,label:'Image'} },
  range: { low:0.2, high:3.9 },
  brands: { openai:'ChatGPT', anthropic:'Claude', google:'Gemini', unknown:'Other' },
  cooling: { reported:{label:'As reported for this region'}, tower:{wue:1.80,label:'Evaporative cooling towers',conf:'medium'}, adiabatic:{wue:0.32,label:'Air-side economiser + adiabatic',conf:'high'}, dry:{wue:0.03,label:'Closed-loop / dry / free-air',conf:'high'} },
  stress: [ {id:0,label:'Low',band:'<10 % of supply withdrawn'}, {id:1,label:'Low–medium',band:'10–20 %'}, {id:2,label:'Medium–high',band:'20–40 %'}, {id:3,label:'High',band:'40–80 %'}, {id:4,label:'Extremely high',band:'>80 %'} ],
  regions: {
    us_hyperscale:{ label:'United States', short:'US', pue:1.17, wueSite:0.55, ewif:{incl:3.142,excl:1.67}, stress:1, defaultCooling:'reported', conf:{pue:'high',wueSite:'high',ewifIncl:'high',ewifExcl:'low'}, note:'PUE 1.17 & WUE 0.55 = Microsoft US average (Li et al. Table 1). EWIF 3.142 = WRI US national incl. hydro; excl-hydro derived.', sources:['Li et al. 2023/25, Table 1','WRI 2020, Appendix 2/4/6'] },
    us_ercot:{ label:'United States · Texas', short:'Texas', pue:1.28, wueSite:0.25, ewif:{incl:1.287,excl:1.22}, stress:3, defaultCooling:'reported', conf:{pue:'high',wueSite:'high',ewifIncl:'high',ewifExcl:'low'}, note:'Gas-heavy grid → low grid water. PUE/WUE = Microsoft San Antonio. EWIF = WRI eGRID ERCT.', sources:['Li et al. 2023/25','WRI 2020, Appendix 1'] },
    eu_average:{ label:'Europe · EU average', short:'EU', pue:1.16, wueSite:0.03, ewif:{incl:3.95,excl:1.9}, stress:2, defaultCooling:'reported', conf:{pue:'high',wueSite:'high',ewifIncl:'low',ewifExcl:'low'}, note:'Microsoft EMEA FY25 (free-air). EWIF = generation-weighted mean of 26 WRI country factors (2016 mix).', sources:['Microsoft efficiency page FY25','WRI 2020 (derived)'] },
    nordic:{ label:'Nordics · Norway / Sweden / Finland', short:'Nordic', pue:1.12, wueSite:0.05, ewif:{incl:6.00,excl:1.12}, stress:0, defaultCooling:'reported', conf:{pue:'high',wueSite:'high',ewifIncl:'low',ewifExcl:'low'}, note:'Hydro/nuclear/wind grid. With hydro ON the WRI method counts gross reservoir evaporation — contested for cold climates (Bakken 2017).', sources:['Li et al. Table 1','WRI 2020 (derived)','Bakken 2017'] },
    india:{ label:'India', short:'India', pue:1.43, wueSite:2.0, ewif:{incl:3.44,excl:2.25}, stress:4, defaultCooling:'reported', conf:{pue:'medium',wueSite:'low',ewifIncl:'high',ewifExcl:'low'}, note:'Coal ≈75 %. EWIF 3.44 = WRI India. PUE = Microsoft India (projected). WUE 2.0 = typical tower-cooled DC (derived).', sources:['WRI 2020','CSE 2021 (CEA norms)','WRI Aqueduct: extremely high'] },
    singapore:{ label:'Singapore', short:'SG', pue:1.28, wueSite:2.2, ewif:{incl:0.75,excl:0.40}, stress:4, defaultCooling:'reported', conf:{pue:'high',wueSite:'medium',ewifIncl:'low',ewifExcl:'low'}, note:'94 % gas, largely seawater-cooled → low freshwater EWIF (derived). WUE 2.2 = IMDA median 2021.', sources:['EMA 2024','Macknick 2011','IMDA 2024'] },
    japan:{ label:'Japan', short:'JP', pue:1.10, wueSite:0.32, ewif:{incl:2.31,excl:1.50}, stress:-1, defaultCooling:'adiabatic', conf:{pue:'high',wueSite:'low',ewifIncl:'high',ewifExcl:'low'}, note:'EWIF = WRI Japan. PUE = Google Inzai. No published site WUE → adiabatic default assumed.', sources:['WRI 2020','Google PUE page 2026','LBNL 2024'] }
  },
  models: {
    openai:[['GPT-5','standard'],['GPT-5 mini','lightweight'],['o3','reasoning'],['GPT-4o','standard']],
    anthropic:[['Claude Sonnet','standard'],['Claude Opus','standard'],['Claude Opus (extended thinking)','reasoning'],['Claude Haiku','lightweight']],
    google:[['Gemini Pro','standard'],['Gemini Flash','lightweight'],['Gemini Pro (Deep Think)','reasoning'],['Gemini Flash-Lite','lightweight']]
  },
  /* A day's water. Was 100 mL, set when a prompt cost 1.3 mL and nothing unseen was counted —
     roughly 43 chat prompts. With the reply and the hidden work measured (I-18, N9) a normal
     answer is ~12 mL and a regular day ~420 mL, so at 100 every character died before lunch and
     the whole keep-it-alive mechanic stopped meaning anything. 500 ≈ a regular working day.
     (I-45, Madhur 2026-09-30.) */
  defaultBudgetMl: 500,
  /* The region a fresh install starts in. Here rather than in each product because the phone app
     invented its own ('us_default') and kept it through the seven-region migration, which left it
     looking up a region that no longer existed. */
  defaultRegionId: 'us_hyperscale',
  zones: { green:0.5, amber:0.7 },
  /* Reading a tier out of the model name shown on screen. Shared, not per-product: the extension,
     the phone apps and the desktop build must all classify "Gemini Flash-Lite" the same way or the
     same prompt gets two different answers. Longest match wins, so 'flash-lite' beats 'flash'. */
  vendorMap: {
    openai:    { def:'standard', p:{ 'o1':'reasoning','o3':'reasoning','o4':'reasoning','thinking':'reasoning','pro':'reasoning','mini':'lightweight','nano':'lightweight' } },
    anthropic: { def:'standard', p:{ 'extended':'reasoning','haiku':'lightweight' } },
    google:    { def:'standard', p:{ 'thinking':'reasoning','deep think':'reasoning','flash':'lightweight','flash-lite':'lightweight' } },
    unknown:   { def:'standard', p:{} }
  },
  /* Real-world opportunity cost (I-27, volumes assumed): daily hydration 2,000 mL (common guidance, varies), glass 250 mL, house plant 250 mL, toilet flush 6 L, shower 9 L/min */
  opp: { hydration:2000, glass:250, plant:250, flush:6000, showerMin:9000 },
  /* Facts — each figure verified on its source page (2026-09-17) */
  facts: [
    { hook:"How much water is drinkable?", t:"Only 2.5% of Earth's water is fresh — and just 1.2% of that is in rivers and lakes.", e:'💧', s:'USGS Water Science School', full:'Of all water on Earth, about 2.5% is freshwater. Of that, 68.7% is locked in ice and snow and 30.1% is groundwater; only around 1.2% is surface water such as rivers, lakes and swamps.', url:'https://www.usgs.gov/special-topics/water-science-school/science/where-earths-water' },
    { hook:'Your charger has a water bill', t:'Making 1 kWh of US electricity used about 57 litres of water in 2015.', e:'⚡', s:'USGS 2015', full:'US power plants withdrew about 15 gallons (57 litres) of water per kilowatt-hour generated in 2015. Most is returned to the source warmer; a share evaporates.', url:'https://www.usgs.gov/mission-areas/water-resources/science/thermoelectric-power-water-use' },
    { hook:'Data centres are growing fast', t:'US data centres used 4.4% of the country’s electricity in 2023 — could hit 12% by 2028.', e:'🖥️', s:'LBNL 2024 report', full:'Lawrence Berkeley National Laboratory estimates US data centres consumed 176 TWh in 2023 and could reach 325–580 TWh by 2028, driven largely by AI hardware.', url:'https://eta-publications.lbl.gov/sites/default/files/2024-12/lbnl-2024-united-states-data-center-energy-usage-report_1.pdf' },
    { hook:'What training GPT-3 drank', t:'Training GPT-3 evaporated about 700,000 litres of clean water — mostly to cool the servers.', e:'🌡️', s:'Li et al. 2023', full:'Researchers estimate training GPT-3 in Microsoft’s US data centres directly evaporated about 700,000 litres of freshwater for cooling.', url:'https://arxiv.org/abs/2304.03271' },
    { hook:'Five drops per prompt', t:'A typical Gemini text prompt uses about 0.26 mL of water on-site — roughly five drops.', e:'🤖', s:'Google 2025', full:'Google measured a median Gemini Apps text prompt at 0.24 Wh and 0.26 mL of water for data-centre cooling (August 2025). That excludes the water used to make the electricity, which Sipcount adds.', url:'https://arxiv.org/abs/2508.15734' },
    { hook:"Google's water bill, in one year", t:'Google used about 41 billion litres of water in 2025 — up 34% in a single year.', e:'📈', s:'Google Environmental Report 2026', full:'Google reported 10.9 billion gallons (about 41 billion litres) of water consumption in 2025, a 34% rise on the year before, driven by its AI data-centre buildout. It says replenishment projects returned roughly 78% of that volume to watersheds.', url:'https://sustainability.google/google-2026-environmental-report/' },
    { hook:'1 in 4 people…', t:'2.2 billion people still lacked safely managed drinking water in 2022.', e:'🚱', s:'WHO/UNICEF JMP 2023', full:'The WHO/UNICEF Joint Monitoring Programme reports that in 2022, 2.2 billion people lacked safely managed drinking water, including 115 million who drank untreated surface water.', url:'https://www.unwater.org/publications/who/unicef-joint-monitoring-program-update-report-2023' },
    { hook:'25 countries running dry', t:'25 countries — home to 1 in 4 people — use up almost their entire water supply every year.', e:'🌍', s:'WRI Aqueduct 4.0', full:'WRI’s Aqueduct 4.0 (2023) finds 25 countries, housing a quarter of the world’s population, face extremely high water stress — using more than 80% of their renewable supply each year.', url:'https://www.wri.org/insights/highest-water-stressed-countries' },
    { hook:'India’s water stress, in one number', t:'Nearly 600 million Indians face high-to-extreme water stress.', e:'🇮🇳', s:'NITI Aayog CWMI 2018', full:'NITI Aayog’s Composite Water Management Index (2018) found nearly 600 million Indians facing high to extreme water stress.', url:'https://www.pib.gov.in/newsite/PrintRelease.aspx?relid=195635' },
    { hook:'Where most water really goes', t:'Farms use 72% of all the freshwater humans take from rivers and aquifers.', e:'🌾', s:'FAO', full:'The FAO puts agriculture at 72% of global freshwater withdrawals, mostly for irrigation — the largest single human use of water.', url:'https://www.fao.org/land-water/water/agricultural-water-management/en' },
    { hook:'A lake, half gone', t:'Utah’s Great Salt Lake shrank from ~2,300 sq mi in 1986 to under 1,000 in 2022.', e:'🏜️', s:'USGS Utah', full:'The Great Salt Lake covered about 2,300 square miles at its 1986 high and fell below 1,000 square miles in 2022, a record low.', url:'https://www.usgs.gov/centers/utah-water-science-center/science/great-salt-lake-elevations-and-areal-extent' }
  ],
  charities: [
    { name:'charity: water', url:'https://www.charitywater.org/donate', line:'≈ 1,100 litres of clean water per $1 (their published average); 100 % of public donations fund projects.', per_l_usd:1/1100 },
    { name:'Water.org', url:'https://water.org/donate/', line:'$5 reaches one person with safe water or sanitation (their FY2020–24 average).' },
    { name:'WaterAid India', url:'https://www.wateraid.org/in/donate/clean-water', line:'Clean water and sanitation programmes across 13 Indian states; donations in INR, 80G tax deductible.' },
    { name:'BEF Water Restoration Certificates', url:'https://www.b-e-f.org/programs/water-restoration-certificates/', line:'$4 restores 1,000 US gallons (3,785 L) of river flow in a stressed basin — a restoration certificate, not an offset.', per_l_usd:4/3785 }
  ]
};
const C = SIPCOUNT_CONFIG;

/* ---------- replacing a guess with a measurement (I-20 / N12) -------------------------------
   Two numbers in here are placeholders: the 5× output multiplier (D-22) and the 90 tokens/second
   rate for work that never reaches the screen. Both get replaced by measured values from the
   calibration, and they have to reach people who already installed the app — otherwise every
   correction waits on a store release, and the phone, the extension and the desktop build drift
   apart again.

   So a small file of *numbers* can be published and picked up. It can never carry code, and it is
   checked hard before anything is believed: wrong schema, unknown shape or any value outside a
   sane physical band and the whole payload is rejected, leaving the values we shipped with. Fail
   closed — a bad fetch must never be able to make the number say anything it likes. */
function recalibrate(outputPerInput){
  C.outputPerInput = outputPerInput;
  C.tokenWeights = { input: 1/outputPerInput, output: 1 };
  const refW = C.referencePrompt.inputTokens*C.tokenWeights.input + C.referencePrompt.outputTokens*C.tokenWeights.output;
  C.weightNormalisation = (C.referencePrompt.inputTokens + C.referencePrompt.outputTokens)/refW;
  for(const t of Object.values(C.tiers)) t.wh1k = t.base*C.weightNormalisation;
}
const BANDS = {
  outputPerInput:[1,20], charsPerToken:[1,10], 'thinking.tokensPerSec':[10,500],
  'tier.base':[0.001,200], 'region.pue':[1,3], 'region.wueSite':[0,20], 'region.ewif':[0,40],
  'context.perThousand':[0,1], 'context.max':[1,20]
};
const inBand=(k,v)=>typeof v==='number' && isFinite(v) && v>=BANDS[k][0] && v<=BANDS[k][1];
function applyConstants(raw){
  if(!raw || raw.schema!=='sipcount-constants/1') return {ok:false, reason:'wrong schema'};
  if(typeof raw.version!=='string' || raw.version.length>32) return {ok:false, reason:'bad version'};
  const applied=[];
  /* validate everything BEFORE changing anything, so a payload that is half-wrong cannot leave
     the constants half-updated */
  if('outputPerInput' in raw && !inBand('outputPerInput',raw.outputPerInput)) return {ok:false, reason:'outputPerInput out of range'};
  if(raw.thinking && !inBand('thinking.tokensPerSec',raw.thinking.tokensPerSec)) return {ok:false, reason:'thinking rate out of range'};
  if('charsPerToken' in raw && !inBand('charsPerToken',raw.charsPerToken)) return {ok:false, reason:'charsPerToken out of range'};
  if(raw.context && (!inBand('context.perThousand',raw.context.perThousand) || !inBand('context.max',raw.context.max))) return {ok:false, reason:'context factor out of range'};
  for(const [id,t] of Object.entries(raw.tiers||{})){
    if(!C.tiers[id]) return {ok:false, reason:'unknown tier '+id};
    if(!inBand('tier.base',t.base)) return {ok:false, reason:'tier '+id+' out of range'};
  }
  for(const [id,r] of Object.entries(raw.regions||{})){
    if(!C.regions[id]) return {ok:false, reason:'unknown region '+id};
    if(!inBand('region.pue',r.pue) || !inBand('region.wueSite',r.wueSite)
       || !inBand('region.ewif',r.ewif&&r.ewif.incl) || !inBand('region.ewif',r.ewif&&r.ewif.excl))
      return {ok:false, reason:'region '+id+' out of range'};
  }
  // everything checked; now apply
  if('charsPerToken' in raw){ C.charsPerToken=raw.charsPerToken; applied.push('charsPerToken'); }
  if(raw.charsPerTokenByScript) for(const [k,v] of Object.entries(raw.charsPerTokenByScript))
    if(k in C.charsPerTokenByScript && inBand('charsPerToken',v)){ C.charsPerTokenByScript[k]=v; applied.push('script:'+k); }
  if(raw.thinking){ C.thinking.tokensPerSec=raw.thinking.tokensPerSec; applied.push('thinking'); }
  if(raw.context){ C.context.perThousand=raw.context.perThousand; C.context.max=raw.context.max; applied.push('context'); }
  for(const [id,t] of Object.entries(raw.tiers||{})){ C.tiers[id].base=t.base; applied.push('tier:'+id); }
  for(const [id,r] of Object.entries(raw.regions||{})){
    Object.assign(C.regions[id],{pue:r.pue,wueSite:r.wueSite,ewif:{incl:r.ewif.incl,excl:r.ewif.excl}}); applied.push('region:'+id); }
  if('outputPerInput' in raw){ recalibrate(raw.outputPerInput); applied.push('outputPerInput'); }
  else recalibrate(C.outputPerInput);                 // tier bases may have moved
  C.version = raw.version;
  return {ok:true, applied};
}

/* ---------- engine ---------- */
function regionParams(regionId, coolingId, hydro){ const R=C.regions[regionId]; const site = coolingId==='reported' ? R.wueSite : C.cooling[coolingId].wue; return { pue:R.pue, site, grid: hydro ? R.ewif.incl : R.ewif.excl }; }
/* inputTokens / outputTokens are tracked separately; `weightedTokens` is what energy scales with. */
/* Tokens the model generated that never reached the screen.
   A model generates continuously while it is working, at a fairly steady rate. So the work a turn
   could have produced is (rate × how long it was working), and whatever we did not see on screen
   was spent elsewhere: reasoning, tool calls, reading what they returned, writing a file.

       hidden ≈ rate × active_seconds − visible_output_tokens

   Time-to-first-token is the wrong signal here, which is why this replaced it the same day: a
   research turn streams "Searching…" almost immediately, so first-output looks fast while the
   model goes on working for five more minutes. Duration does not fall for that.

   An ordinary chat turn lands near zero — 10 s at 90 tok/s is 900 tokens, and a 900-token answer
   accounts for all of it. Returns 0 for a reasoning tier, whose 10× multiplier already stands in
   for hidden work; counting both would charge the same thinking twice. */
function hiddenFrom({activeMs, outputTokens=0, tier}={}){
  if(tier==='reasoning' || !(activeMs>0)) return 0;
  const secs=Math.min(C.thinking.maxSec, Math.max(0, activeMs/1000 - C.thinking.floorSec));
  return Math.max(0, Math.round(secs*C.thinking.tokensPerSec - outputTokens));
}
/* How much dearer each output token is, given how much conversation precedes it. 1 on a fresh
   chat, so the calibrated reference prompt is untouched. */
function contextFactor(contextTokens){
  if(!(contextTokens>0)) return 1;
  return Math.min(C.context.max, 1 + C.context.perThousand*contextTokens/1000);
}
function estimate({tier,task,inputTokens=0,outputTokens=null,hiddenTokens=0,contextTokens=0,items=1,params}){
  const T=C.tiers[tier], K=C.tasks[task], P=params, W=C.tokenWeights; let energy, weighted=0;
  const outTok = outputTokens==null ? (K.out||0) : outputTokens;
  /* hidden tokens are generated one at a time exactly like visible ones, so they carry the
     output weight, not the input weight. The context factor applies to the visible answer, per
     the equation in TOKEN-ECONOMICS §3 — b(L)·T_out and plain b·T_hidden. */
  if(K.fixed!=null){ energy=K.fixed*items; }
  else { weighted=inputTokens*W.input + outTok*W.output*contextFactor(contextTokens) + hiddenTokens*W.output;
         energy=T.wh1k*weighted/1000; }
  const f=energy*P.pue;
  /* an image task spends no text tokens — report both sides as 0 so day totals stay honest */
  return { energyWh:energy, s1:f*P.site, s2:f*P.grid, total:f*(P.site+P.grid), inputTokens:K.fixed!=null?0:inputTokens, outputTokens:K.fixed!=null?0:outTok, hiddenTokens:K.fixed!=null?0:hiddenTokens, weightedTokens:weighted,
           inputShare: weighted? (inputTokens*W.input)/weighted : 0 };
}
/* `script` is a label produced by the sensor from text it never keeps: 'latin', 'devanagari',
   'hinglish', 'cjk', 'code' or 'mixed'. Unknown or absent falls back to English. */
const tok=(ch,script)=>ch<=0?0:Math.ceil(ch/(C.charsPerTokenByScript[script]||C.charsPerToken));
/* Which script a counted string is in, by proportion of code points. Runs on a local string that
   is discarded immediately — the same boundary as counting its length. */
function scriptOf(text){
  if(!text) return 'latin';
  const n=text.length; let dev=0, cjk=0, latin=0;
  for(let i=0;i<n;i++){ const c=text.charCodeAt(i);
    if(c>=0x0900&&c<=0x097F) dev++;
    else if((c>=0x4E00&&c<=0x9FFF)||(c>=0x3040&&c<=0x30FF)||(c>=0xAC00&&c<=0xD7AF)) cjk++;
    else if((c>=0x41&&c<=0x5A)||(c>=0x61&&c<=0x7A)) latin++; }
  if(cjk/n>0.2) return 'cjk';
  if(dev/n>0.5) return 'devanagari';
  /* Even a little Devanagari among Latin means Hinglish, and the code test must come after this
     or "mujhe ek python function chahiye जो..." is classified as code. Fully Romanised Hinglish
     ("mujhe ek function chahiye") is indistinguishable from English by code point and is counted
     as English — a known under-count that only word-level detection or a real tokenizer fixes. */
  if(dev/n>0.02) return 'hinglish';
  if(/```|[{};]\s*$|\b(function|const|let|def |import |class )\b/m.test(text)) return 'code';
  return latin/n>0.5 ? 'latin' : 'mixed';
}
const fmt=(n,d)=>n.toLocaleString(undefined,{maximumFractionDigits:d??(n<10?1:0),minimumFractionDigits:0});
const zone=pct=>pct<C.zones.green?'green':pct<C.zones.amber?'amber':'red';
const ZONE_UI={ green:{ico:'✓',label:'Optimal'}, amber:{ico:'⚠️',label:'Elevated'}, red:{ico:'🛑',label:'Limit Exceeded'} };

/* ---------- opportunity cost (one line, plain words) ---------- */
function opportunityCost(ml, period='today'){
  const o=C.opp;
  if(ml<=0) return `Nothing yet ${period}.`;
  if(ml<o.glass*0.5){ const p=ml/o.hydration*100; return p<1?`Your AI evaporated about ${Math.max(1,Math.round(ml/0.05))} drops of water ${period}.`:`Your AI evaporated about ${Math.round(p)}% of a day’s drinking water ${period}.`; }
  if(ml<o.flush){ const s=fmt(ml/o.glass, ml/o.glass<10?1:0); return `Your AI evaporated enough water to fill ${s} standard drinking glass${s==='1'?'':'es'} ${period}.`; }
  if(ml<o.showerMin*3){ const s=fmt(ml/o.flush, ml/o.flush<10?1:0); return `Your AI evaporated enough water to flush a toilet ${s} time${s==='1'?'':'s'} ${period}.`; }
  const s=fmt(ml/o.showerMin, ml/o.showerMin<10?1:0); return `Your AI evaporated enough water for a ${s}-minute shower ${period}.`;
}

/* ---------- storage (DayTotals canonical document, ARCHITECTURE §9) ---------- */
const dayKey=d=>`${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`;

/* ---------- multi-device merge (sync foundation, ARCHITECTURE §9.1) -------------------------
   A device only ever writes its OWN day totals, into S.days. Totals pulled from a paired device
   are parked, untouched, in S.peers[devId].days. Everything the UI reads goes through days(),
   which sums the sources for each date.

   Why this shape: two devices that both edited one shared days[date] would fight over it, and a
   later write would silently erase the other's number. Here the writers never overlap, so there
   is nothing to resolve — the worst case is a peer that is simply out of date, which shows up as
   a total that is too low for a moment, never as data that is lost. It also happens to be true:
   the extension on a laptop and the app on a phone really did see different prompts.            */
const EMPTY_DAY=()=>({n:0,img:0,s1:0,s2:0,tin:0,tout:0,tier:{},task:{},vendor:{}});
function mergeDay(){
  const o=EMPTY_DAY();
  for(const src of arguments){
    if(!src) continue;
    o.n+=src.n||0; o.img+=src.img||0; o.s1+=src.s1||0; o.s2+=src.s2||0; o.tin+=src.tin||0; o.tout+=src.tout||0;
    for(const t in (src.tier||{})) o.tier[t]=(o.tier[t]||0)+src.tier[t];
    for(const t in (src.task||{})) o.task[t]=(o.task[t]||0)+src.task[t];
    for(const v in (src.vendor||{})){ const s=src.vendor[v]||{}, d=(o.vendor[v] ||= {n:0,ml:0,tiers:{}});
      d.n+=s.n||0; d.ml+=s.ml||0;
      for(const t in (s.tiers||{})){ const x=(d.tiers[t] ||= {n:0,ml:0}); x.n+=s.tiers[t].n||0; x.ml+=s.tiers[t].ml||0; } }
  }
  return o;
}
/* Sum this device's days with every paired device's. With no peers the own map is returned
   untouched, so an unsynced install behaves exactly as it always did. */
function mergeAll(own, peers){
  const ids=Object.keys(peers||{});
  if(!ids.length) return own;
  const out={};
  for(const k in own) out[k]=mergeDay(own[k]);
  for(const id of ids){ const d=(peers[id]&&peers[id].days)||{}; for(const k in d) out[k]=mergeDay(out[k], d[k]); }
  return out;
}
const newDevId=()=>{
  try{ const a=new Uint8Array(8); (globalThis.crypto||window.crypto).getRandomValues(a);
       return [...a].map(b=>b.toString(16).padStart(2,'0')).join(''); }
  catch(e){ return Math.random().toString(16).slice(2,10)+Math.random().toString(16).slice(2,10); }
};

function makeStore(KEY, defaults){
  let S;
  function load(){
    try{ const j=JSON.parse(localStorage.getItem(KEY)); if(j&&j.days){ const s=Object.assign({}, defaults, j); if(!C.regions[s.region]) s.region=defaults.region; if(!C.cooling[s.cooling]) s.cooling='reported'; return s; } }catch(e){}
    let days={}, budget=C.defaultBudgetMl, region=C.defaultRegionId;
    for(const k of ['sipcount.v9','sipcount.v8a','sipcount.v7','sipcount.v6','sipcount.v5','sipcount.v4','sipcount.v3','sipcount.v2','sipcount.v1']){ try{ const old=JSON.parse(localStorage.getItem(k)); if(old&&old.days){ days=old.days; budget=old.budget||C.defaultBudgetMl; region=C.regions[old.region]?old.region:region; break; } }catch(e){} }
    return Object.assign({}, defaults, { budget, region, days, installedAt: (()=>{ const ks=Object.keys(days).sort(); return ks.length? new Date(ks[0]+'T12:00:00').getTime() : Date.now(); })() });
  }
  S=load();
  S.peers ||= {}; S.devId ||= newDevId();
  /* days() is read on every render, so the merge is cached and only recomputed when this device
     records a prompt or a peer's totals are replaced. */
  let rev=0, cacheRev=-1, cache=null;
  const days=()=>{ if(cacheRev!==rev){ cache=mergeAll(S.days, S.peers); cacheRev=rev; } return cache; };
  const dirty=()=>{ rev++; };
  const save=()=>{ try{ localStorage.setItem(KEY,JSON.stringify(S)); }catch(e){} };
  /* A pull replaces a peer's map wholesale — only that peer ever writes it, so there is no merge. */
  const setPeer=(id,d,meta)=>{ if(!id||id===S.devId) return; S.peers[id]=Object.assign({}, S.peers[id], meta||{}, {days:d||{}, seen:Date.now()}); dirty(); };
  const dropPeer=id=>{ delete S.peers[id]; dirty(); };
  const dropAllPeers=()=>{ S.peers={}; dirty(); };
  const bucket=k=>{ dirty(); const b=(S.days[k] ||= {n:0,img:0,s1:0,s2:0,tin:0,tout:0,tier:{},task:{},vendor:{}}); b.tier||={}; b.task||={}; b.vendor||={}; b.img||=0; b.tin||=0; b.tout||=0; return b; };
  const record=(e,tier,task,vendor,dt)=>{
    const b=bucket(dayKey(dt||new Date())); b.n++; if(task==='image') b.img++; b.s1+=e.s1; b.s2+=e.s2; b.tin+=e.inputTokens||0; b.tout+=e.outputTokens||0;
    b.task[task]=(b.task[task]||0)+e.total;
    const v=(b.vendor[vendor] ||= {n:0,ml:0,tiers:{}}); v.n++; v.ml+=e.total;
    /* Image water is a fixed per-image cost, not a function of the model tier — keeping it out of the
       tier maps stops "switch tier and save X" from claiming savings a tier switch cannot deliver. */
    if(task!=='image'){ b.tier[tier]=(b.tier[tier]||0)+e.total; v.tiers[tier]=(v.tiers[tier]||{n:0,ml:0}); v.tiers[tier].n++; v.tiers[tier].ml+=e.total; }
  };
  const params=()=>regionParams(S.region,S.cooling,S.hydro);
  const last7=()=>[...Array(7)].map((_,i)=>{const d=new Date(); d.setDate(d.getDate()-(6-i)); return dayKey(d);});
  const todayStats=()=>{ const t=days()[dayKey(new Date())]||EMPTY_DAY(); return {...t, total:t.s1+t.s2, pct:(t.s1+t.s2)/S.budget}; };
  const loadSample=()=>{
    S.days={}; dirty(); S.sample=true; S.streak=12; const P=params(); const vendors=['openai','anthropic','google'];
    const plan=[[6,0],[9,1],[7,0],[14,2],[5,0],[11,1],[4,1]];
    plan.forEach(([n,img],i)=>{ const d=new Date(); d.setDate(d.getDate()-(6-i));
      for(let p=0;p<n;p++){ const tier=p%5===0?'reasoning':(p%3===0?'lightweight':'standard'); const task=p%4===0?'code':'text'; const vendor=vendors[(p+i)%3];
        record(estimate({tier,task,inputTokens:tok(200+((p*137)%900)),params:P}),tier,task,vendor,d); }
      for(let k=0;k<img;k++) record(estimate({tier:'standard',task:'image',inputTokens:0,params:P}),'standard','image','openai',d);
    });
    save();
  };
  /* No automatic sample data (decision 2, 2026-09-24). The caller loads it deliberately, in demo
     mode only, so a real first run opens on a real empty day. */
  return { get S(){return S;}, set S(v){S=v; dirty();}, save, bucket, record, params, last7, todayStats, loadSample,
           days, dirty, setPeer, dropPeer, dropAllPeers, get ownDays(){return S.days;} };
}

/* ---------- weekly analysis (shared by both branches) ---------- */
function weeklyAnalysis(store){
  const S=store.S, D=store.days(), keys=store.last7(); let total=0,n=0,tin=0,tout=0, byBrand={}, reasoning={}, tiers={};
  keys.forEach(k=>{ const b=D[k]; if(!b) return; n+=b.n; total+=b.s1+b.s2; tin+=b.tin||0; tout+=b.tout||0; for(const v in (b.vendor||{})){ byBrand[v]=(byBrand[v]||0)+b.vendor[v].ml; const r=b.vendor[v].tiers?.reasoning; if(r) reasoning[v]=(reasoning[v]||0)+r.ml; } for(const t in (b.tier||{})) tiers[t]=(tiers[t]||0)+b.tier[t]; });
  const vals=keys.map(k=>{const b=D[k]; return b?b.s1+b.s2:0;});
  const top=Object.entries(byBrand).sort((a,b)=>b[1]-a[1])[0], topTier=Object.entries(tiers).sort((a,b)=>b[1]-a[1])[0];
  const rTot=Object.values(reasoning).reduce((a,b)=>a+b,0), saving=rTot*(1-C.tiers.standard.wh1k/C.tiers.reasoning.wh1k), rBrand=Object.entries(reasoning).sort((a,b)=>b[1]-a[1])[0];
  const outShare = (tin*C.tokenWeights.input + tout*C.tokenWeights.output) ? (tout*C.tokenWeights.output)/(tin*C.tokenWeights.input + tout*C.tokenWeights.output) : 0;
  const tips=[];
  if(saving>0 && rBrand) tips.push(`Switching your ${C.brands[rBrand[0]]||rBrand[0]} reasoning-model prompts to standard models could save you roughly ${fmt(saving)} mL next week.`);
  if(outShare>0.8) tips.push(`About ${Math.round(outShare*100)}% of your water went into the answers, not your questions — asking for shorter replies is the quickest saving.`);
  if((tiers.standard||0)>0) tips.push(`Quick questions on a light model use about a fifth of the water of a standard one.`);
  if(!tips.length) tips.push('Keep it up — nothing heavier than a standard model in the last 7 days.');
  return { keys, vals, total, n, tin, tout, outShare, top, topTier, saving, rBrand, tips };
}
