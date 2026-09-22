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
  beforeParse(w){ w.onerror=(m,s,l,c,e)=>errors.push(String(e&&e.stack||m)); }});
const w=dom.window;
w.addEventListener('load',()=>setTimeout(run,300));
const $=id=>w.document.getElementById(id);
const click=el=>el.dispatchEvent(new w.MouseEvent('click',{bubbles:true}));

function run(){
 const d=w.document;
 try{
  console.log('\nBOOT');
  $('ageIn').value='30'; $('ageGo').onclick();
  ok('dashboard shown', $('s-today').classList.contains('active'));
  ok('nav is today/simulate/about/settings', [...d.querySelectorAll('nav button')].map(b=>b.dataset.s).join(',')==='today,log,about,settings');
  ok('grove parked', !$('s-grove'));

  console.log('\nLAUNCH SEQUENCE');
  ok('plays on first launch', !!$('splash'));
  ok('all parts drawn', ['sp-rack','sp-glass','sp-robot','sp-human'].every(c=>d.querySelectorAll('.'+c).length===1));
  ok('grid of servers', d.querySelectorAll('.sp-grid .u').length===25);
  ok('end line present', /EVERY PROMPT/.test($('spEnd').textContent));
  $('spSkip').click();
  ok('skip removes it', !$('splash'));
  ok('seen flag saved', w.eval('S.splashSeen')===true);

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

  console.log('\nWEEKLY REVIEW');
  w.eval("show('today')"); $('weeklyBtn').onclick();
  const rep=$('reportSheet').textContent.replace(/\s+/g,' ');
  ok('heading appears once', (rep.match(/Weekly review/g)||[]).length===1);
  ok('reads "last 7 days"', /last 7 days/.test(rep) && !/this week/.test(rep));
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
