import test from 'node:test';
import assert from 'node:assert/strict';
import {defaults,validateConfig,GiftRouter,ACTIONS} from '../companion/engine.mjs';
import {GameBridge,actionPacket} from '../companion/game.mjs';
const gift=(count,group='roses')=>({giftId:5655,giftType:1,groupId:group,repeatCount:count,repeatEnd:0,userId:'1',uniqueId:'rose_viewer'});
const config=(action='weapon_jam')=>validateConfig({...defaults(),mappings:[{id:'rose',giftId:'5655',action,duration:5,cooldown:300,maxRepeat:5,perGift:false}]});
test('150 progressive roses add exactly 750 seconds despite legacy cap, cooldown and once-per-combo settings',()=>{
 const calls=[];const r=new GiftRouter(config(),a=>calls.push(a),()=>{});
 for(const n of [1,5,20,100,150])r.gift(gift(n));
 assert.equal(calls.reduce((n,a)=>n+a.duration,0),750);
 assert.equal(calls.reduce((n,a)=>n+a.giftCount,0),150);
 assert.equal(r.gift({...gift(150),repeatEnd:1}).duplicate,true);
 r.gift(gift(10,'next'));assert.equal(calls.at(-1).duration,50);
});
test('a 150-gift instant streak queues every action without the old queue limit or cooldown loss',()=>{
 const c=config('points');const b=new GameBridge(c,()=>{});b.beat=Date.now();b.arm();
 const r=new GiftRouter(c,a=>b.enqueue(a),()=>{});assert.equal(r.gift(gift(150)).sent,150);
 assert.equal(b.queue.length,150);r.gift(gift(2,'next'));assert.equal(b.queue.length,152);
});
test('uncapped queued gifts do not expire while waiting for game readiness',async()=>{
 const b=new GameBridge(config(),()=>{});b.readLog=()=>{};b.queue=[{action:'weapon_jam',created:Date.now()-120000}];
 await b.tick();assert.equal(b.queue.length,1);b.pause();assert.equal(b.queue.length,0);
});
test('v4 preserves long durations and the full displayed gift count',()=>{
 const spec=ACTIONS.find(a=>a.id==='weapon_jam');const packet=actionPacket({duration:7500,amount:1,giftCount:1500,viewer:'viewer',gift:'Rose'},spec,'example',4).split('|');
 assert.equal(packet[3],'7500');assert.equal(packet[5],'v4');assert.equal(packet[8],'1500');
 const b=new GameBridge(config(),()=>{});b.consume('EGGLIVE1|ready|map|playing|1|v4\n');assert.equal(b.protocol,4);
});
test('progressive timed bursts combine queued top-ups without losing any gift or duration',()=>{
 const c=config();const b=new GameBridge(c,()=>{});b.beat=Date.now();b.arm();
 const r=new GiftRouter(c,a=>b.enqueue(a),()=>{});
 for(let n=1;n<=150;n++)r.gift(gift(n));
 assert.equal(b.queue.length,1);assert.equal(b.queue[0].duration,750);assert.equal(b.queue[0].giftCount,150);
});
