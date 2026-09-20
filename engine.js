/* =====================================================================================
   Sipcount shared engine + constants (v8, 2026-09-20). Used by sipcount.html (Branch A) and
   sipcount-aqua.html (Branch B). Mirrors app/assets/calc/models.json + WaterCalculator.dart
   (I-16: Dart still to be synced to input/output weighting).

   Formula: total_mL = E_Wh × PUE × (WUE_site + EWIF_grid)
     E_Wh (text tasks) = wh_per_1k_weighted_tokens × (in × w_in + out × w_out) / 1000
     E_Wh (image)      = fixed_wh × items
   Token weighting (I-28, LOW confidence): output tokens are generated one at a time
   (autoregressive decode) and are less compute-efficient than parallel input processing.
   We weight output 5× input and re-normalise so the calibrated reference prompt
   (100 in + 300 out ≈ 0.30 Wh standard tier) is unchanged: 400 plain tokens = 320 weighted
   → wh1k_weighted = wh1k_plain × 400/320. Evidence and open items: docs/TOKEN-ECONOMICS.md.
   ===================================================================================== */
const SIPCOUNT_CONFIG = {
  version: '2026-09-20',
  charsPerToken: 4,
  /* output = 5× input (central of a 3–10× literature range; docs/TOKEN-ECONOMICS.md §1). Reference prompt 100 in + 300 out = 320 weighted tokens, kept at 0.30 Wh standard. */
  tokenWeights: { input: 0.20, output: 1.0 },
  tiers: { lightweight:{wh1k:0.15*400/320,label:'Light'}, standard:{wh1k:0.75*400/320,label:'Standard'}, reasoning:{wh1k:7.5*400/320,label:'Reasoning'} },
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
  zones: { green:0.5, amber:0.7 },
  /* Real-world opportunity cost (I-27, volumes assumed): daily hydration 2,000 mL (common guidance, varies), glass 250 mL, house plant 250 mL, toilet flush 6 L, shower 9 L/min */
  opp: { hydration:2000, glass:250, plant:250, flush:6000, showerMin:9000 },
  /* Facts — each figure verified on its source page (2026-09-17) */
  facts: [
    { hook:"How much water is drinkable?", t:"Only 2.5% of Earth's water is fresh — and just 1.2% of that is in rivers and lakes.", e:'💧', s:'USGS Water Science School', full:'Of all water on Earth, about 2.5% is freshwater. Of that, 68.7% is locked in ice and snow and 30.1% is groundwater; only around 1.2% is surface water such as rivers, lakes and swamps.', url:'https://www.usgs.gov/special-topics/water-science-school/science/where-earths-water' },
    { hook:'Your charger has a water bill', t:'Making 1 kWh of US electricity used about 57 litres of water in 2015.', e:'⚡', s:'USGS 2015', full:'US power plants withdrew about 15 gallons (57 litres) of water per kilowatt-hour generated in 2015. Most is returned to the source warmer; a share evaporates.', url:'https://www.usgs.gov/mission-areas/water-resources/science/thermoelectric-power-water-use' },
    { hook:'Data centres are growing fast', t:'US data centres used 4.4% of the country’s electricity in 2023 — could hit 12% by 2028.', e:'🖥️', s:'LBNL 2024 report', full:'Lawrence Berkeley National Laboratory estimates US data centres consumed 176 TWh in 2023 and could reach 325–580 TWh by 2028, driven largely by AI hardware.', url:'https://eta-publications.lbl.gov/sites/default/files/2024-12/lbnl-2024-united-states-data-center-energy-usage-report_1.pdf' },
    { hook:'What training GPT-3 drank', t:'Training GPT-3 evaporated about 700,000 litres of clean water — mostly to cool the servers.', e:'🌡️', s:'Li et al. 2023', full:'Researchers estimate training GPT-3 in Microsoft’s US data centres directly evaporated about 700,000 litres of freshwater for cooling.', url:'https://arxiv.org/abs/2304.03271' },
    { hook:'Five drops per prompt', t:'A typical Gemini text prompt uses about 0.26 mL of water on-site — roughly five drops.', e:'🤖', s:'Google 2025', full:'Google measured a median Gemini Apps text prompt at 0.24 Wh and 0.26 mL of water for data-centre cooling (August 2025). That excludes the water used to make the electricity, which Sipcount adds.', url:'https://arxiv.org/abs/2508.15734' },
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

/* ---------- engine ---------- */
function regionParams(regionId, coolingId, hydro){ const R=C.regions[regionId]; const site = coolingId==='reported' ? R.wueSite : C.cooling[coolingId].wue; return { pue:R.pue, site, grid: hydro ? R.ewif.incl : R.ewif.excl }; }
/* inputTokens / outputTokens are tracked separately; `weightedTokens` is what energy scales with. */
function estimate({tier,task,inputTokens=0,outputTokens=null,items=1,params}){
  const T=C.tiers[tier], K=C.tasks[task], P=params, W=C.tokenWeights; let energy, weighted=0;
  const outTok = outputTokens==null ? (K.out||0) : outputTokens;
  if(K.fixed!=null){ energy=K.fixed*items; } else { weighted=inputTokens*W.input+outTok*W.output; energy=T.wh1k*weighted/1000; }
  const f=energy*P.pue;
  return { energyWh:energy, s1:f*P.site, s2:f*P.grid, total:f*(P.site+P.grid), inputTokens, outputTokens:K.fixed!=null?0:outTok, weightedTokens:weighted,
           inputShare: weighted? (inputTokens*W.input)/weighted : 0 };
}
const tok=ch=>ch<=0?0:Math.ceil(ch/C.charsPerToken);
const fmt=(n,d)=>n.toLocaleString(undefined,{maximumFractionDigits:d??(n<10?1:0),minimumFractionDigits:0});
const zone=pct=>pct<C.zones.green?'green':pct<C.zones.amber?'amber':'red';
const ZONE_UI={ green:{ico:'✓',label:'Optimal'}, amber:{ico:'⚠️',label:'Elevated'}, red:{ico:'🛑',label:'Limit Exceeded'} };

/* ---------- opportunity cost (one line, plain words) ---------- */
function opportunityCost(ml){
  const o=C.opp;
  if(ml<=0) return 'Nothing yet today.';
  if(ml<o.glass*0.5){ const p=ml/o.hydration*100; return p<1?`That’s about ${Math.max(1,Math.round(ml/0.05))} drops of water.`:`That’s ${Math.round(p)}% of a day’s drinking water gone.`; }
  if(ml<o.glass*1.5) return 'That’s a full glass of drinking water gone.';
  if(ml<o.flush) { const n=ml/o.plant; return `That’s enough to water ${fmt(n,n<10?1:0)} houseplant${fmt(n,n<10?1:0)==='1'?'':'s'} today.`; }
  if(ml<o.showerMin*3){ const n=ml/o.flush; return `That’s ${fmt(n,n<10?1:0)} toilet flush${fmt(n,n<10?1:0)==='1'?'':'es'} of water.`; }
  const n=ml/o.showerMin; return `That’s a ${fmt(n,n<10?1:0)}-minute shower’s worth of water.`;
}

/* ---------- storage (DayTotals canonical document, ARCHITECTURE §9) ---------- */
const dayKey=d=>`${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`;
function makeStore(KEY, defaults){
  let S;
  function load(){
    try{ const j=JSON.parse(localStorage.getItem(KEY)); if(j&&j.days){ const s=Object.assign({}, defaults, j); if(!C.regions[s.region]) s.region=defaults.region; if(!C.cooling[s.cooling]) s.cooling='reported'; return s; } }catch(e){}
    let days={}, budget=100, region='us_hyperscale';
    for(const k of ['sipcount.v7','sipcount.v6','sipcount.v5','sipcount.v4','sipcount.v3','sipcount.v2','sipcount.v1']){ try{ const old=JSON.parse(localStorage.getItem(k)); if(old&&old.days){ days=old.days; budget=old.budget||100; region=C.regions[old.region]?old.region:region; break; } }catch(e){} }
    return Object.assign({}, defaults, { budget, region, days, installedAt: (()=>{ const ks=Object.keys(days).sort(); return ks.length? new Date(ks[0]+'T12:00:00').getTime() : Date.now(); })() });
  }
  S=load();
  const save=()=>{ try{ localStorage.setItem(KEY,JSON.stringify(S)); }catch(e){} };
  const bucket=k=>{ const b=(S.days[k] ||= {n:0,img:0,s1:0,s2:0,tin:0,tout:0,tier:{},task:{},vendor:{}}); b.tier||={}; b.task||={}; b.vendor||={}; b.img||=0; b.tin||=0; b.tout||=0; return b; };
  const record=(e,tier,task,vendor,dt)=>{
    const b=bucket(dayKey(dt||new Date())); b.n++; if(task==='image') b.img++; b.s1+=e.s1; b.s2+=e.s2; b.tin+=e.inputTokens||0; b.tout+=e.outputTokens||0;
    b.tier[tier]=(b.tier[tier]||0)+e.total; b.task[task]=(b.task[task]||0)+e.total;
    const v=(b.vendor[vendor] ||= {n:0,ml:0,tiers:{}}); v.n++; v.ml+=e.total; v.tiers[tier]=(v.tiers[tier]||{n:0,ml:0}); v.tiers[tier].n++; v.tiers[tier].ml+=e.total;
  };
  const params=()=>regionParams(S.region,S.cooling,S.hydro);
  const last7=()=>[...Array(7)].map((_,i)=>{const d=new Date(); d.setDate(d.getDate()-(6-i)); return dayKey(d);});
  const todayStats=()=>{ const t=S.days[dayKey(new Date())]||{n:0,img:0,s1:0,s2:0,tin:0,tout:0,vendor:{},tier:{}}; return {...t, total:t.s1+t.s2, pct:(t.s1+t.s2)/S.budget}; };
  const loadSample=()=>{
    S.days={}; S.sample=true; const P=params(); const vendors=['openai','anthropic','google'];
    const plan=[[6,0],[9,1],[7,0],[14,2],[5,0],[11,1],[4,1]];
    plan.forEach(([n,img],i)=>{ const d=new Date(); d.setDate(d.getDate()-(6-i));
      for(let p=0;p<n;p++){ const tier=p%5===0?'reasoning':(p%3===0?'lightweight':'standard'); const task=p%4===0?'code':'text'; const vendor=vendors[(p+i)%3];
        record(estimate({tier,task,inputTokens:tok(200+((p*137)%900)),params:P}),tier,task,vendor,d); }
      for(let k=0;k<img;k++) record(estimate({tier:'standard',task:'image',inputTokens:0,params:P}),'standard','image','openai',d);
    });
    save();
  };
  if(!Object.keys(S.days).length && !S.wiped) loadSample();
  return { get S(){return S;}, set S(v){S=v;}, save, bucket, record, params, last7, todayStats, loadSample };
}

/* ---------- weekly analysis (shared by both branches) ---------- */
function weeklyAnalysis(store){
  const S=store.S, keys=store.last7(); let total=0,n=0,tin=0,tout=0, byBrand={}, reasoning={}, tiers={};
  keys.forEach(k=>{ const b=S.days[k]; if(!b) return; n+=b.n; total+=b.s1+b.s2; tin+=b.tin||0; tout+=b.tout||0; for(const v in (b.vendor||{})){ byBrand[v]=(byBrand[v]||0)+b.vendor[v].ml; const r=b.vendor[v].tiers?.reasoning; if(r) reasoning[v]=(reasoning[v]||0)+r.ml; } for(const t in (b.tier||{})) tiers[t]=(tiers[t]||0)+b.tier[t]; });
  const vals=keys.map(k=>{const b=S.days[k]; return b?b.s1+b.s2:0;});
  const top=Object.entries(byBrand).sort((a,b)=>b[1]-a[1])[0], topTier=Object.entries(tiers).sort((a,b)=>b[1]-a[1])[0];
  const rTot=Object.values(reasoning).reduce((a,b)=>a+b,0), saving=rTot*(1-C.tiers.standard.wh1k/C.tiers.reasoning.wh1k), rBrand=Object.entries(reasoning).sort((a,b)=>b[1]-a[1])[0];
  const outShare = (tin*C.tokenWeights.input + tout*C.tokenWeights.output) ? (tout*C.tokenWeights.output)/(tin*C.tokenWeights.input + tout*C.tokenWeights.output) : 0;
  const tips=[];
  if(saving>0 && rBrand) tips.push(`Switching your ${C.brands[rBrand[0]]||rBrand[0]} reasoning-model prompts to standard models could save you roughly ${fmt(saving)} mL next week.`);
  if(outShare>0.8) tips.push(`About ${Math.round(outShare*100)}% of your water went into the answers, not your questions — asking for shorter replies is the quickest saving.`);
  if((tiers.standard||0)>0) tips.push(`Quick questions on a light model use about a fifth of the water of a standard one.`);
  if(!tips.length) tips.push('Keep it up — nothing heavier than a standard model this week.');
  return { keys, vals, total, n, tin, tout, outShare, top, topTier, saving, rBrand, tips };
}
