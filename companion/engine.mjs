import {randomUUID} from 'node:crypto';
import {EXTRAS} from './extras.mjs';
export const ACTIONS = [
  ['points','Give points','help',1000,100000,0],
  ['take_points','Take points','chaos',1000,100000,0],
  ['ammo','Refill ammunition','help',1,1,0],
  ['empty_ammo','Empty ammunition','chaos',1,1,0],
  ['heal','Heal host','help',1,1,0],
  ['hurt','Damage host (non-lethal)','chaos',25,100,0],
  ['down','Down host','chaos',1,1,0],
  ['extra_zombies','Add zombies to this wave','chaos',5,50,0],
  ['slow','Slow host','chaos',1,1,10],
  ['spin','Turn host around','chaos',180,180,0],
  ['max_ammo','Drop Max Ammo','help',1,1,0],
  ['insta_kill','Drop Insta-Kill','help',1,1,0],
  ['double_points','Drop Double Points','help',1,1,0],
  ['nuke','Drop Nuke','help',1,1,0],
  ['all_perks','Give available map perks','help',1,1,0],
  ['ping','Test game connection','help',1,1,0]
].map(([id,label,kind,amount,max,duration])=>({id,label,kind,amount,max,duration,category:kind==='help'?'Help':'Chaos'})).concat(EXTRAS);
export const defaults = () => ({version:1,username:'',gamePath:'E:\\steam\\steamapps\\common\\Call of Duty Black Ops III',
  profile:'EggArmy',queueLimit:50,eventMaxAge:30,triggerVolume:70,triggerMuted:false,mappings:[]});
export function validateAudio(c){
  const volume=Number(c.triggerVolume??70);
  if(!Number.isFinite(volume)||volume<0||volume>100)throw Error('Trigger volume must be 0–100');
  if(c.triggerMuted!==undefined&&typeof c.triggerMuted!=='boolean')throw Error('Invalid trigger mute setting');
  return {triggerVolume:Math.round(volume/10)*10,triggerMuted:c.triggerMuted===true};
}
export function validateConfig(c) {
  if(!c || typeof c!=='object') throw Error('Invalid configuration');
  if(!Array.isArray(c.mappings)||c.mappings.length>100)throw Error('Use at most 100 mappings');
  const ids=new Set();
  const mappings=c.mappings.map(r=>{
    const a=ACTIONS.find(a=>a.id===r.action);if(!a)throw Error('Choose an available action');
    const id=String(r.id||randomUUID());if(ids.has(id))throw Error('Duplicate mapping');ids.add(id);
    const giftId=String(r.giftId||'');if(!/^\d{1,20}$/.test(giftId))throw Error('Choose a gift or enter its numeric ID');
    const number=(v,lo,hi)=>{v=Number(v);if(!Number.isFinite(v)||v<lo||v>hi)throw Error(`Value must be ${lo}–${hi}`);return Math.floor(v);};
    return {id,giftId,giftName:String(r.giftName||giftId).slice(0,80),action:a.id,enabled:r.enabled!==false,
      amount:number(r.amount??a.amount,1,a.max),duration:number(r.duration??a.duration,a.duration>0?1:0,120),
      cooldown:number(r.cooldown??3,0,300),maxRepeat:number(r.maxRepeat??5,1,20),perGift:r.perGift!==false};
  });
  const username=String(c.username||'').replace(/^@/,'');if(username&&!/^[\w.]{1,64}$/.test(username))throw Error('Enter only your TikTok username');
  const gamePath=String(c.gamePath||'');if(!gamePath||gamePath.includes('\0'))throw Error('Choose the BO3 installation folder');
  return {...defaults(),...validateAudio(c),username,gamePath,profile:String(c.profile||'EggArmy').slice(0,40),
    queueLimit:Math.max(1,Math.min(100,Number(c.queueLimit)||50)),eventMaxAge:Math.max(5,Math.min(60,Number(c.eventMaxAge)||30)),mappings};
}
// Both the installed 2.x payload and the current typed payload are normalized here.
export function normalizeGift(e,room='',incremental=false) {
  const gift=e.giftDetails||e.gift||{};
  const giftId=String(e.giftId??gift.id??gift.gift_id??'');
  const type=Number(e.giftType??gift.type??gift.gift_type??0);
  const ended=e.repeatEnd===true||e.repeatEnd===1||e.repeatEnd==='1';
  if(type===1 && !ended && !(incremental&&e.groupId))return null;
  if(!/^\d{1,20}$/.test(giftId))return null;
  const sender=String(e.userId??e.user?.userId??e.user?.id??e.uniqueId??'unknown');
  const message=String(e.msgId??e.common?.msgId??e.common?.messageId??'');
  const group=String(e.groupId??'');
  // Without a stable transaction identifier we cannot safely replay a paid event.
  if(!group&&!message)return null;
  return {key:`${room}:${sender}:${giftId}:${type===1&&group?'g'+group:'m'+message}`,
    giftId,name:String(e.giftName??gift.name??e.extendedGiftInfo?.name??giftId),
    count:Math.max(1,Math.min(10000,Math.floor(Number(e.repeatCount)||1))),
    viewer:String(e.uniqueId??e.user?.uniqueId??e.user?.displayId??'Viewer').slice(0,60)};
}
export class GiftRouter {
  constructor(config,onAction,onEvent,now=()=>Date.now()){this.config=config;this.onAction=onAction;this.onEvent=onEvent;this.now=now;this.seen=new Map();this.last=new Map();}
  gift(raw,room='',test=false){
    const g=normalizeGift(raw,room,true);if(!g)return {ignored:true};
    const now=this.now();for(const [k,t]of this.seen)if(now-t.time>3600000)this.seen.delete(k);
    const previous=this.seen.get(g.key)?.count||0;
    if(g.count<=previous)return {duplicate:true};this.seen.set(g.key,{time:now,count:g.count});
    let sent=0;
    for(const r of this.config.mappings){
      if(!r.enabled||r.giftId!==g.giftId)continue;
      const timed=ACTIONS.find(a=>a.id===r.action).duration>0;
      // A growing combo and timed top-ups must not lose gifts to a reset cooldown.
      if(!previous&&!timed&&now-(this.last.get(r.id)??-Infinity)<r.cooldown*1000){this.onEvent('cooldown',`${g.name}: mapping cooling down`);continue;}
      this.last.set(r.id,now);
      const repeats=r.perGift?Math.max(0,Math.min(g.count,r.maxRepeat)-Math.min(previous,r.maxRepeat)):(previous?0:1);
      if(!repeats)continue;
      const base={action:r.action,amount:r.amount,duration:r.duration,viewer:g.viewer,gift:r.giftName||g.name,test};
      if(timed&&!['panic_pack','chaos_roulette'].includes(r.action)){if(this.onAction({...base,duration:r.duration*repeats,giftCount:repeats})!==false)sent++;}
      else for(let i=0;i<repeats;i++){if(this.onAction({...base,giftCount:1})!==false)sent++;}
      if(r.perGift&&g.count>r.maxRepeat&&previous<=r.maxRepeat)this.onEvent('capped',`${g.name}: combo limit ${r.maxRepeat} reached; extra gifts do not add effects`);
    }
    this.onEvent(test?'test':'gift',`${g.viewer} • ${g.name} ×${g.count} • ${sent} action(s)`);return {sent};
  }
}
