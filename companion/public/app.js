import {connectionNotice} from './connection-status.js';
const $=s=>document.querySelector(s);
const esc=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
let state,config,token,dirty=false,picking=null,pickerLimit=60;
let audioSaving=false,audioTimer,audioVersion=0;
const coins=n=>`${n.toLocaleString()} coin${n===1?'':'s'}`;
function notice(s){$('#notice').textContent=s;clearTimeout(notice.timer);notice.timer=setTimeout(()=>$('#notice').textContent='',10000);}
async function api(route,data={}){const r=await fetch('/api/'+route,{method:'POST',headers:{'Content-Type':'application/json','X-Egg-Token':token},body:JSON.stringify(data)});const j=await r.json();if(!r.ok)throw Error(j.error);return j;}
function fields(){for(const id of ['username','profile','gamePath','queueLimit','eventMaxAge'])$('#'+id).value=config[id];$('#triggerVolume').value=config.triggerVolume??70;$('#triggerMuted').checked=config.triggerMuted===true;audioLabel();}
function audioLabel(){$('#triggerVolumeValue').textContent=$('#triggerVolume').value+'%';$('#triggerVolume').disabled=$('#triggerMuted').checked;}
function changeAudio(){
 config.triggerVolume=Number($('#triggerVolume').value);config.triggerMuted=$('#triggerMuted').checked;audioLabel();audioSaving=true;
 $('#audioStatus').textContent='Saving…';clearTimeout(audioTimer);const version=++audioVersion;
 audioTimer=setTimeout(async()=>{try{await api('audio',{triggerVolume:config.triggerVolume,triggerMuted:config.triggerMuted});if(version===audioVersion){audioSaving=false;await refresh();}}catch(e){if(version===audioVersion){$('#audioStatus').textContent='Not saved — '+e.message;}}},250);
}
$('#triggerVolume').oninput=changeAudio;$('#triggerMuted').onchange=changeAudio;
function readFields(){
 for(const row of document.querySelectorAll('.rule')){const r=config.mappings.find(r=>r.id===row.dataset.id);for(const input of row.querySelectorAll('[data-field]'))r[input.dataset.field]=input.type==='checkbox'?input.checked:input.type==='number'?Number(input.value):input.value;}
 for(const id of ['username','profile','gamePath'])config[id]=$('#'+id).value;
 for(const id of ['queueLimit','eventMaxAge'])config[id]=Number($('#'+id).value);
 return config;
}
function options(current){return [...new Set(state.actions.map(a=>a.category))].map(group=>`<optgroup label="${esc(group)}">${state.actions.filter(a=>a.category===group&&a.id!=='ping').map(a=>`<option value="${a.id}" ${a.id===current?'selected':''}>${a.kind==='help'?'＋':'⚡'} ${esc(a.label)}</option>`).join('')}</optgroup>`).join('');}
function giftArt(g){return `<span class="gift-art"><span aria-hidden="true">◇</span>${g?.image?`<img src="${esc(g.image)}" alt="" loading="lazy" referrerpolicy="no-referrer">`:''}</span>`;}
document.addEventListener('error',e=>{if(e.target.tagName==='IMG')e.target.hidden=true;},true);
function renderRules(){
 $('#empty').hidden=!!config.mappings.length;$('#ruleCount').textContent=`${config.mappings.length} action${config.mappings.length===1?'':'s'}`;
 $('#rules').innerHTML=config.mappings.map((r,i)=>{const a=state.actions.find(a=>a.id===r.action),g=state.gifts.find(g=>g.id===r.giftId);return `<article class="rule" data-id="${esc(r.id)}">
 <div class="rule-top"><span class="rule-title">Action ${i+1}</span><label class="check"><input data-field="enabled" type="checkbox" ${r.enabled?'checked':''}>On</label><button data-do="remove" aria-label="Remove action ${i+1}">×</button></div>
 <button class="gift-choice" data-do="gift" aria-label="Choose gift for action ${i+1}">${giftArt(g)}<span><strong>${esc(g?.name||r.giftName||'Choose a gift')}</strong><small>${g?coins(g.diamonds):'Browse the gift library'}</small></span><span class="gift-chevron">⌄</span></button>
 <label>Game effect<select aria-label="Game effect for action ${i+1}" data-field="action">${options(r.action)}</select></label>
 <div class="rule-values">${a.max>1&&!r.action.startsWith('spawn_near_')?`<label>Amount<input data-field="amount" type="number" min="1" max="${a.max}" value="${r.amount}"></label>`:''}${a.duration>0?`<label>Seconds / gift<input data-field="duration" type="number" min="1" max="120" value="${r.duration}"></label>`:''}<span class="effect-badge ${a.kind}">${a.kind==='help'?'Helps you':'Adds chaos'}</span></div>
 <div class="simple-bottom">${state.testTools?'<div class="testbuttons"><button data-do="preview">Preview</button><button data-do="test">Try in BO3</button></div>':''}<details><summary>Advanced</summary><div class="advanced-grid"><label>Cooldown (seconds)<input data-field="cooldown" type="number" min="0" max="300" value="${r.cooldown}"></label><label>Combo limit<input data-field="maxRepeat" type="number" min="1" max="20" value="${r.maxRepeat}"></label><label class="check"><input data-field="perGift" type="checkbox" ${r.perGift?'checked':''}>Repeat per gift</label><small>Gift ID: ${esc(r.giftId||'not selected')}</small>${a.duration>0?'<small>Each gift adds time. Live streaks update immediately; combo limit applies. Timers cap at 60 minutes. Conflicting movement speeds replace each other.</small>':''}</div></details></div></article>`;}).join('')+(config.mappings.length?'<button class="add-rule-card" data-add-rule><span>＋</span><strong>Add a gift action</strong><small>Choose from the gift library</small></button>':'');
}
function catalogue(){$('#giftHint').textContent=`${state.gifts.length.toLocaleString()} gifts ready · ${state.giftCatalog?.roomSynced?'LIVE room refreshed':'Preloaded library'} · No IDs needed`;}
function openPicker(id){readFields();picking=id;pickerLimit=60;$('#giftSearch').value='';$('#giftPrice').value='all';$('#giftSort').value='coins';renderPicker();$('#giftPicker').showModal();$('#giftSearch').focus();}
function renderPicker(){
 const query=$('#giftSearch').value.toLowerCase().trim(),price=$('#giftPrice').value;
 const gifts=state.gifts.filter(g=>(!query||g.name.toLowerCase().includes(query)||g.id.includes(query))&&(price==='all'||price==='small'&&g.diamonds<100||price==='medium'&&g.diamonds>=100&&g.diamonds<1000||price==='large'&&g.diamonds>=1000));
 gifts.sort($('#giftSort').value==='name'?(a,b)=>a.name.localeCompare(b.name):$('#giftSort').value==='high'?(a,b)=>b.diamonds-a.diamonds:(a,b)=>a.diamonds-b.diamonds);
 const current=config.mappings.find(r=>r.id===picking)?.giftId;
 $('#giftResults').textContent=`${gifts.length.toLocaleString()} gifts${query?' found':''}`;
 $('#giftGrid').innerHTML=gifts.slice(0,pickerLimit).map(g=>`<button class="gift-tile ${g.id===current?'selected':''}" data-gift-id="${g.id}" aria-label="Select ${esc(g.name)}, ${coins(g.diamonds)}, ID ${g.id}">${giftArt(g)}<strong>${esc(g.name)}</strong><small>${coins(g.diamonds)}</small></button>`).join('')||'<p class="muted">No gifts match. Try a different name or price range.</p>';
 $('#moreGifts').hidden=gifts.length<=pickerLimit;
}
$('#giftGrid').onclick=e=>{const button=e.target.closest('[data-gift-id]');if(!button)return;const g=state.gifts.find(g=>g.id===button.dataset.giftId),r=config.mappings.find(r=>r.id===picking);if(!g||!r)return;r.giftId=g.id;r.giftName=g.name;dirty=true;$('#giftPicker').close();renderRules();};
$('#closeGifts').onclick=()=>$('#giftPicker').close();
for(const id of ['giftSearch','giftPrice','giftSort'])$('#'+id).addEventListener(id==='giftSearch'?'input':'change',()=>{pickerLimit=60;renderPicker();});
$('#moreGifts').onclick=()=>{pickerLimit+=60;renderPicker();};
function statuses(){
 const t=state.tiktok,g=state.game;
 const connection=connectionNotice(t,state.gifts.length);
 $('#liveStatus').textContent=t.state[0].toUpperCase()+t.state.slice(1);$('#liveDetail').textContent=t.room?'Room '+t.room:(state.testOnly?'Local test mode':'Start your TikTok LIVE, then connect');$('#connectionError').textContent=connection.text;$('#connectionError').style.color=connection.warning?'#ffda70':'';
 $('#gameStatus').textContent=g.connected?'Mod connected':'Waiting for BO3';$('#gameDetail').textContent=g.connected?`${g.map} · ${g.state==='waiting'?'Connected at setup hub':g.state==='paused'?'Game paused / signal waiting':'Gameplay ready'}`:'Open BO3 with Egg LIVE';$('#queue').textContent=g.queue;
 $('#armedState').textContent=g.armed?'Actions enabled':g.autoEnable?'Auto-enable ready · waiting for BO3':'Actions paused';
 if(!audioSaving)$('#audioStatus').textContent=g.connected&&g.audioSynced?(config?.triggerMuted||config?.triggerVolume===0?'Muted in BO3':'Applied in BO3'):g.connected?'Saved · switch back to BO3 to apply':'Saved · applies when BO3 connects';
 $('#arm').disabled=g.armed||!g.connected;$('#arm').hidden=g.armed||g.autoEnable;$('#connect').disabled=['connected','connecting','reconnecting'].includes(t.state);
 if(state.testOnly){$('#connect').disabled=true;$('#connect').textContent='LIVE testing pending';$('#connect').title='This build uses local test gifts only.';}else{$('#connect').textContent='Connect TikTok LIVE';$('#connect').title='Connect to your active TikTok LIVE';}
 $('#enableTests').hidden=g.armed||g.autoEnable;$('#enableTests').disabled=!g.connected;
 $('#testState').textContent=!g.connected?(g.autoEnable?'Saved · automatically ready when BO3 connects.':'Open BO3 with the mod. Saving enables actions automatically.'):!g.armed?'Paused · save your actions to enable them.':g.state!=='playing'?'Mod connected · gifts are ready. Gameplay effects wait for an active player.':'Ready · gifts will trigger while BO3 is focused.';
}
function events(){$('#events').innerHTML=state.events.length?state.events.slice(0,25).map(e=>`<div class="event ${esc(e.kind)}"><time>${esc(new Date(e.time).toLocaleTimeString([], {hour:'2-digit',minute:'2-digit',second:'2-digit'}))}</time><span class="kind">${esc(e.kind)}</span><span>${esc(e.message)}</span></div>`).join(''):'<p class="muted">Tests and confirmed game actions appear here.</p>';}
async function save(){const result=await api('config',readFields());dirty=false;renderRules();catalogue();await refresh();notice(result.game.armed?'Saved — actions are enabled.':'Saved — actions enable automatically when BO3 connects.');}
$('#rules').addEventListener('input',()=>dirty=true);
$('#rules').addEventListener('change',e=>{if(e.target.dataset.field==='action'){readFields();const r=config.mappings.find(r=>r.id===e.target.closest('.rule').dataset.id),a=state.actions.find(a=>a.id===r.action);r.amount=a.amount;r.duration=a.duration;dirty=true;renderRules();}});
$('#rules').addEventListener('click',async e=>{
 if(e.target.closest('[data-add-rule]')){$('#add').click();return;}const button=e.target.closest('[data-do]');if(!button)return;const command=button.dataset.do,id=button.closest('.rule').dataset.id;
 try{readFields();if(command==='gift'){openPicker(id);return;}if(command==='remove'){config.mappings=config.mappings.filter(r=>r.id!==id);dirty=true;renderRules();return;}if(dirty)await save();const result=await api('test',{mapping:id,send:command==='test',count:1});notice(command==='test'?`${result.sent} test queued — switch back to BO3.`:'Preview only — nothing sent to BO3.');await refresh();}catch(e){notice(e.message);}
});
for(const [id,route]of [['enableTests','arm'],['connect','connect'],['disconnect','disconnect'],['pause','pause'],['arm','arm'],['setup','setup'],['launch','launch']])$('#'+id).onclick=async()=>{try{if(dirty&&['connect','setup','launch','arm'].includes(route))await save();await api(route);notice(route==='setup'?'Game setup prepared.':route==='launch'?'BO3 launch requested.':'Done');}catch(e){notice(e.message);}await refresh();};
$('#save').onclick=()=>save().catch(e=>notice(e.message));$('#saveRules').onclick=$('#save').onclick;
$('#add').onclick=()=>{readFields();const r={id:crypto.randomUUID(),giftId:'',giftName:'',action:'points',amount:1000,duration:0,cooldown:3,maxRepeat:5,perGift:true,enabled:true};config.mappings.push(r);dirty=true;renderRules();openPicker(r.id);};
for(const id of ['username','profile','gamePath','queueLimit','eventMaxAge'])$('#'+id).oninput=()=>dirty=true;
$('#export').onclick=()=>{const blob=new Blob([JSON.stringify(readFields(),null,2)],{type:'application/json'});const a=document.createElement('a');a.href=URL.createObjectURL(blob);a.download='egg-live-profile.json';a.click();setTimeout(()=>URL.revokeObjectURL(a.href),1000);};
$('#import').onchange=async e=>{try{const f=e.target.files[0];if(!f||f.size>100000)throw Error('Choose a profile JSON file under 100 KB');const c=JSON.parse(await f.text());await api('config',c);config=c;fields();renderRules();catalogue();dirty=false;await refresh();notice('Profile imported — automatic enabling ready.');}catch(e){notice(e.message);}e.target.value='';};
async function refresh(){try{state=await(await fetch('/api/state')).json();token=state.token;statuses();if(!config){config=structuredClone(state.config);fields();renderRules();catalogue();}if(refresh.catalogue!==state.giftCatalog?.revision){refresh.catalogue=state.giftCatalog?.revision;catalogue();if(!dirty)renderRules();if($('#giftPicker').open)renderPicker();}events();}catch{notice('Companion connection lost. Restart Egg LIVE.');}}
await refresh();setInterval(refresh,1500);



