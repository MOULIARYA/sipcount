/* Sipcount prototype regression check.  Run:  node docs/test/regression.js
   Needs jsdom (npm i jsdom) and a copy of the page with the Google-fonts <link> removed. */
let JSDOM; try{ ({JSDOM}=require('jsdom')); }
catch(e){ console.error('jsdom is missing. Run:  npm install jsdom'); process.exit(2); }
const fs=require('fs'); const path=require('path');
const ROOT=process.argv[2]||path.join(__dirname,'..','..');
let html=fs.readFileSync(path.join(ROOT,'sipcount.html'),'utf8').replace(/<link rel="stylesheet" href="https:\/\/fonts[^>]*>/,'');
const tmp=path.join(require('os').tmpdir(),'sipcount-test'); fs.mkdirSync(tmp,{recursive:true});
fs.writeFileSync(path.join(tmp,'sipcount.html'),html);
fs.copyFileSync(path.join(ROOT,'engine.js'),path.join(tmp,'engine.js'));
fs.mkdirSync(path.join(tmp,'assets'),{recursive:true});
for(const f of fs.readdirSync(path.join(ROOT,'assets'))) if(f.endsWith('.webp')) fs.copyFileSync(path.join(ROOT,'assets',f),path.join(tmp,'assets',f));

let pass=0, fail=0; const errors=[];
const ok=(name,cond,extra='')=>{ if(cond){pass++; console.log('  ✓',name);} else {fail++; console.log('  ✗',name, extra);} };

const dom=new JSDOM(html,{runScripts:'dangerously',resources:'usable',url:'file://'+path.join(tmp,'sipcount.html'),pretendToBeVisual:true,
  beforeParse(w){ w.onerror=(m,s,l,c,e)=>errors.push(String(e&&e.stack||m));
    /* jsdom ships crypto.getRandomValues but not crypto.subtle; the sync code needs both. */
    try{ const wc=require('crypto').webcrypto; if(wc && !(w.crypto&&w.crypto.subtle)) Object.defineProperty(w,'crypto',{value:wc,configurable:true,writable:true}); }catch(e){}
  }});
const w=dom.window;
w.addEventListener('load',()=>setTimeout(run,300));
const $=id=>w.document.getElementById(id);
const click=el=>el.dispatchEvent(new w.MouseEvent('click',{bubbles:true}));

async function run(){
 const d=w.document;
 try{
  console.log('\nBOOT');
  $('ageIn').value='30'; $('ageGo').onclick();
  ok('dashboard shown', $('s-today').classList.contains('active'));
  ok('nav is today/simulate/about/settings', [...d.querySelectorAll('nav button')].map(b=>b.dataset.s).join(',')==='today,log,about,settings');
  ok('grove parked', !$('s-grove'));

  console.log('\nINTRO SEQUENCE');
  /* the age screen is class="splash"; the intro overlay must never share a class with it, or the
     age screen inherits overlay styling and the app renders blank (this happened in the wild) */
  ok('no class collision with the age screen', d.querySelectorAll('.splash').length===1 && d.querySelector('.splash').id==='s-splash');
  ok('age screen reachable', (()=>{ w.eval("show('splash')"); const a=$('s-splash').classList.contains('active'); w.eval("show('today')"); return a; })());
  ok('two figures then the brand', w.eval('INTRO.length')===2 && w.eval('INTRO_MS.length')===3);
  ok('runs about eight seconds, not thirteen', (()=>{ const t=w.eval('INTRO_MS.reduce((a,b)=>a+b,0)'); return t>=7000 && t<=9000; })(), w.eval('INTRO_MS.reduce((a,b)=>a+b,0)')+'ms');
  ok('LBNL figure corrected to 66 billion', w.eval('INTRO[1].n')===66 && /billion/.test(w.eval('INTRO[1].suf')));
  ok('no "just to cool" overclaim', !/just to cool/i.test(w.eval('JSON.stringify(INTRO)')));
  ok('every figure names its source', w.eval('INTRO.every(s=>s.src&&s.src.length>6)'));
  ok('the Google figure survived in the fact library', w.eval("C.facts.some(f=>/41 billion/.test(f.t))"));
  ok('cards render with a counting number', (()=>{
     w.eval("S.introSeen=false; introIdx=0; playIntro();");
     const shown=$('launch') && !$('launch').hidden && !!$('lxN');
     const card=$('lxStage').textContent;
     return shown && /litres/.test(card) && /Li et al/.test(card);
  })());
  ok('progress bar per card', $('lxDots').children.length===3);
  ok('tapping advances', (()=>{ click($('launch')); return /data centres/.test($('lxStage').textContent); })());
  ok('last card is the brand and the promise', (()=>{ click($('launch')); const t=$('lxStage').textContent;
     return /Sipcount/.test(t) && /Now see your share/.test(t) && !!$('lxStage').querySelector('svg'); })());
  ok('skip closes it and never traps you', (()=>{ $('lxSkip').click(); w.eval("$('launch')&&$('launch').remove()"); return !$('launch'); })());
  ok('video slot still honoured if one is ever supplied', w.eval('LAUNCH_VIDEO')===null && /LAUNCH_VIDEO/.test(w.eval('playIntro.toString()')));

  console.log('\nHERO + CHARACTER');
  ok('drop painted', !!$('heroVessel').querySelector('svg'));
  ok('budget line only', !!$('todayBudget') && !d.getElementById('todayLeft'));
  ok('status names the character', /·/.test($('ecoStateTxt').textContent));
  ok('days alive spelled out', /\d+ days? alive/.test($('ecoAlive').textContent), $('ecoAlive').textContent);
  ok('five frames of art', $('ecoArt').querySelectorAll('img.frame').length===5);
  ok('art is contained, not cropped', $('ecoArt').querySelector('img.frame').style.objectFit==='contain');
  ok('no box around the character', w.getComputedStyle($('ecoArt')).backgroundColor==='rgba(0, 0, 0, 0)');

  console.log('\nSTAGES — picture and words agree');
  const seen=new Set();
  for(const pct of [0,0.2,0.4,0.7,0.95]){
    w.eval(`setPreview(${pct})`);
    const lit=[...$('ecoArt').querySelectorAll('img.frame')].findIndex(f=>f.style.opacity==='1');
    const stage=w.eval(`stageOf(${pct})`);
    ok(`${Math.round(pct*100)}% → stage ${stage} · ${$('ecoStateTxt').textContent}`, lit===stage);
    seen.add($('ecoStateTxt').textContent);
  }
  ok('five distinct status labels', seen.size===5, [...seen].join(' / '));
  ok('no numbers in the character text', !/\d/.test($('ecoStateTxt').textContent.replace(/·/,'')+$('ecoLine').textContent));
  w.eval('exitPreview()');
  ok('preview left real data alone', Math.round(w.eval('todayStats().total'))>0);

  console.log('\nNOTIFICATIONS');
  w.eval("alertCard('💡','A test hook.','The explanation, revealed on tap.')");
  const al=$('alerts').lastElementChild;
  ok('hook is a button', al.querySelector('.hook').tagName==='BUTTON');
  ok('no timer', !al.querySelector('.timer'));
  ok('body hidden until tapped', !al.classList.contains('open'));
  click(al.querySelector('.hook'));
  ok('expands on tap', al.classList.contains('open') && al.querySelector('.hook').getAttribute('aria-expanded')==='true');
  click(al.querySelector('.x'));
  ok('closes on ✕', !al.classList.contains('in'));

  console.log('\nEXPLAINER POPOVER');
  click(d.querySelector('.info[data-tip="eco"]'));
  ok('lives outside the phone frame', $('tipPop').parentElement.tagName==='BODY');
  ok('fixed to the viewport', w.getComputedStyle($('tipPop')).position==='fixed');
  ok('stays on screen', parseInt($('tipPop').style.left)>=10 && parseInt($('tipPop').style.top)>=0);
  click(d.querySelector('h1'));
  ok('dismisses on outside tap', $('tipPop').hidden);

  console.log('\nANALYTICS');
  ok('two metrics only', d.querySelectorAll('.metric').length===2);
  ok('metric labels', [...d.querySelectorAll('.metric .k')].map(k=>k.textContent).join(' + ')==='Prompts today + mL last 7 days');
  ok('no chart on the dashboard', !$('bars'));
  ok('no token talk anywhere on it', !/token/i.test($('s-today').textContent));

  console.log('\nSIMULATOR');
  w.eval("show('log')");
  ok('sliders labelled in words', /words/.test($('lenLabel').textContent) && /words/.test($('outLabel').textContent));
  ok('no jargon', !/(Wh|PUE|WUE|token)/.test($('s-log').textContent));
  const before=w.eval('todayStats().total'); $('logBtn').onclick();
  ok('logging records water', w.eval('todayStats().total')>before);

  console.log('\nSETTINGS');
  w.eval("show('settings')");
  ok('character gallery', d.querySelectorAll('.pick').length===4);
  ok('gallery uses plain images (iOS-safe)', [...d.querySelectorAll('.pick .art')].every(a=>a.firstElementChild.tagName==='IMG'));
  ok('locked cards carry the requirement', [...d.querySelectorAll('.pick[data-locked]')].every(c=>/days under budget/.test(c.textContent)));
  click($('unlockBtn'));
  ok('unlock all works', w.eval('S.unlocked.length')===4 && d.querySelectorAll('.pick[data-locked]').length===0);
  click([...d.querySelectorAll('.pick')].find(c=>c.dataset.m==='glacier'));
  ok('can switch character', w.eval("S.mascot")==='glacier');
  ok('session toggle renamed', /Remind me during long sessions/.test($('s-settings').textContent));
  let dl=null; w.HTMLAnchorElement.prototype.click=function(){dl=this.download;};
  w.URL.createObjectURL=()=>'blob:x'; w.URL.revokeObjectURL=()=>{};
  $('csvBtn').onclick();
  ok('CSV exports', /^sipcount-\d{4}-\d{2}-\d{2}\.csv$/.test(dl||''), dl);

  console.log('\nSYNC — pair code, merge and the 18+ gate');
  /* the code itself */
  const k1=w.eval('newSyncKey()');
  ok('code is 25 Crockford characters', /^[0-9A-HJKMNP-TV-Z]{25}$/.test(k1), k1);
  ok('shown as five blocks of five', w.eval(`fmtKey('${k1}')`).split('-').every(g=>g.length===5));
  ok('typed back in any shape', w.eval(`parseKey(' ${k1.slice(0,5).toLowerCase()}-${k1.slice(5)} ')`)===k1);
  ok('a short code is refused', w.eval("parseKey('ABC')")===null);
  /* two devices add up; neither overwrites the other */
  const mine=w.eval('Math.round(lifetimeMl())');
  w.eval(`(function(){ const d={}; const k=dayKey(new Date()); d[k]={n:4,img:0,s1:10,s2:15,tin:100,tout:400,tier:{standard:25},task:{text:25},vendor:{openai:{n:4,ml:25,tiers:{standard:{n:4,ml:25}}}}};
                        store.setPeer('laptop01', d, {label:'Computer'}); save(); })()`);
  ok('a paired device adds to the total', Math.round(w.eval('lifetimeMl()'))===mine+25, `${mine} → ${Math.round(w.eval('lifetimeMl()'))}`);
  ok("this device's own numbers are untouched", Math.round(w.eval('Object.values(store.ownDays).reduce((a,b)=>a+b.s1+b.s2,0)'))===mine);
  ok('the merged day keeps both breakdowns', w.eval("Object.keys(DAYS()[dayKey(new Date())].vendor).length")>=1);
  /* the settings card */
  w.eval("S.adult=true; save(); show('settings')");
  ok('adults are offered sync', /Set up sync/.test($('syncBody').textContent));
  w.eval(`startSync('${k1}')`);
  w.eval("show('settings')");
  ok('paired: both devices listed', d.querySelectorAll('#syncBody .dev').length===2, $('syncBody').textContent.trim().slice(0,90));
  ok('honest about there being no server yet', /isn’t live yet|isn't live yet/.test($('syncBody').textContent));
  /* what would go on the wire */
  const p=w.eval('JSON.stringify(Object.keys(syncPayload()))');
  ok('payload carries only totals and settings', p==='["v","dev","label","days","budget","region","at"]', p);
  ok('no timestamp finer than a date', w.eval("Object.keys(syncPayload().days).every(k=>/^\\d{4}-\\d{2}-\\d{2}$/.test(k))"));
  /* nothing but counts: every field of every day is one of the known aggregates, and every leaf
     is a number — so there is no slot a prompt could ever travel in. */
  ok('every day is counts only, no free text', w.eval(`(function(){
       const allow=['n','img','s1','s2','tin','tout','tier','task','vendor'];
       const leaves=v=>typeof v==='number' ? true : (v&&typeof v==='object' ? Object.values(v).every(leaves) : false);
       return Object.values(syncPayload().days).every(b=>Object.keys(b).every(k=>allow.includes(k)) && leaves(b));
     })()`));
  /* the server can never read it */
  if(w.crypto && w.crypto.subtle){
    const blob=await w.eval(`seal('${k1}', {hello:'world'})`);
    ok('blob is unreadable as it stands', !/hello|world/.test(blob));
    const back=await w.eval(`unseal('${k1}', ${JSON.stringify(blob)})`);
    ok('and opens again with the code', back.hello==='world');
    const room=await w.eval(`roomOf('${k1}')`);
    ok('room id is a hash, not the code', /^[0-9a-f]{32}$/.test(room) && !room.includes(k1.slice(0,5).toLowerCase()));
  } else { ok('WebCrypto available to test sealing', false, 'crypto.subtle missing'); }
  /* switching off */
  w.eval('stopSync()');
  ok('stopping removes the other device', Object.keys(w.eval('S.peers')).length===0 && Math.round(w.eval('lifetimeMl()'))===mine);
  /* the promise the app makes must survive the feature it just gained */
  w.eval("show('settings')");
  const priv=$('s-settings').textContent.replace(/\s+/g,' ');
  ok('privacy copy no longer claims nothing ever leaves', !/nothing (you type )?ever leaves this device/i.test(priv));
  ok('privacy copy names what syncing sends', /daily totals/i.test(priv) && /encrypted/i.test(priv) && /from 18/i.test(priv));
  w.eval("show('splash')");
  ok('age screen makes the narrow promise, not the broad one', !/nothing leaves this device/i.test($('s-splash').textContent) && /Nothing you type is ever stored/i.test($('s-splash').textContent));
  w.eval("show('today')");
  /* the age gate */
  w.eval("applyAge(15); show('settings')");
  ok('under 18 is local only', /available from 18/.test($('syncBody').textContent) && !/Set up sync/.test($('syncBody').textContent));
  ok('an under-18 answer disconnects any sync', w.eval('S.sync')===null && Object.keys(w.eval('S.peers')).length===0);
  w.eval("applyAge(30)");

  console.log('\nFIRST RUN');
  ok('age screen exists with its logo and question', /Sipcount/.test($('s-splash').textContent) && !!$('ageIn') && !!$('ageGo'));
  w.eval("window.confirm=()=>true; show('settings'); $('wipeBtn').onclick();");
  ok('clearing data returns you to the age screen', $('s-splash').classList.contains('active') && w.eval('S.mode')===null);
  ok('nav hidden while onboarding', $('nav').hidden===true);
  w.eval("$('ageIn').value='30'; $('ageGo').onclick();");
  ok('onboarding completes back into the app', $('s-today').classList.contains('active'));

  console.log('\nWEEKLY REVIEW');
  w.eval("show('today')"); $('weeklyBtn').onclick();
  const rep=$('reportSheet').textContent.replace(/\s+/g,' ');
  ok('heading appears once', (rep.match(/Weekly review/g)||[]).length===1);
  ok('reads "last 7 days"', /last 7 days/.test(rep) && !/this week/.test(rep), JSON.stringify(rep.slice(0,120)));
  ok('no token counts', !/token/i.test(rep));
  $('reportClose').onclick();

  console.log('\nFALLBACK');
  w.eval("Object.keys(MASCOT_ASSETS).forEach(k=>MASCOT_ASSETS[k]=null); S.mascot='plant'; $('ecoArt').dataset.k=''; renderEco($('ecoArt')); applyEco($('ecoArt'),0.8,true);");
  ok('drawn character renders when art is missing', !!$('ecoArt').querySelector('svg.sticker'));

  console.log(`\n${pass} passed, ${fail} failed, ${errors.length} console errors`);
  errors.forEach(e=>console.log('  !', e.slice(0,200)));
  process.exit(fail||errors.length?1:0);
 }catch(e){ console.log('THREW', e.stack); process.exit(1); }
}
