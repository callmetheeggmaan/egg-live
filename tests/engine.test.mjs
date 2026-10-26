import test from 'node:test';import assert from 'node:assert/strict';
import {defaults,validateConfig,normalizeGift,GiftRouter} from '../companion/engine.mjs';
const config=()=>validateConfig({...defaults(),uncappedGifts:false,mappings:[{id:'rose',giftId:'5655',action:'points',amount:1000,duration:0,cooldown:0,maxRepeat:5,perGift:true}]});
const event=(extra={})=>({giftId:5655,giftType:1,repeatEnd:1,repeatCount:3,user:{id:'123',displayId:'viewer'},groupId:'abc',common:{msgId:'1'},...extra});
test('streak increases dispatch immediately and final frames never double count',()=>{const calls=[];const r=new GiftRouter(config(),a=>calls.push(a),()=>{});assert.equal(r.gift(event({repeatEnd:0,repeatCount:1})).sent,1);assert.equal(calls.length,1);assert.equal(r.gift(event({repeatEnd:0,repeatCount:2})).sent,1);assert.equal(r.gift(event()).sent,1);assert.equal(r.gift(event()).duplicate,true);assert.equal(r.gift(event({repeatCount:2})).duplicate,true);assert.equal(calls.length,3);});
test('separate non-streak gifts with same gift ID stay separate',()=>{const calls=[];const r=new GiftRouter(config(),a=>calls.push(a),()=>{});r.gift(event({giftType:4,repeatCount:1,msgId:'1'}));r.gift(event({giftType:4,repeatCount:1,msgId:'2'}));assert.equal(calls.length,2);});
test('modern typed gift fields normalize',()=>{const g=normalizeGift({giftId:'5655',gift:{type:1,name:'Rose'},repeatEnd:1,repeatCount:8,user:{id:'a'},groupId:'g'});assert.equal(g.count,8);assert.equal(g.name,'Rose');});
test('gift sender username reaches the routed action without using their nickname',()=>{const calls=[];const r=new GiftRouter(config(),a=>calls.push(a),()=>{});r.gift(event({uniqueId:'actual.viewer_12',nickname:'Different Display Name'}));assert.equal(calls[0].viewer,'actual.viewer_12');const g=normalizeGift(event({user:{id:'1',uniqueId:'typed.username',nickname:'Other Name'}}));assert.equal(g.viewer,'typed.username');});
test('repeat cap and once-per-combo mode',()=>{let calls=[];const c=config();const r=new GiftRouter(c,a=>calls.push(a),()=>{});r.gift(event({repeatCount:999}));assert.equal(calls.length,5);c.mappings[0].perGift=false;calls=[];r.gift(event({groupId:'b',repeatCount:999}));assert.equal(calls.length,1);});
test('cooldown, disabled rules and unknown gifts do not execute',()=>{let calls=[];let now=10000;const c=config();c.mappings[0].cooldown=3;const r=new GiftRouter(c,a=>calls.push(a),()=>{},()=>now);r.gift(event());r.gift(event({groupId:'b'}));assert.equal(calls.length,3);now+=3100;r.gift(event({groupId:'c',giftId:4}));c.mappings[0].enabled=false;r.gift(event({groupId:'d'}));assert.equal(calls.length,3);});
test('distinct senders cannot collide on a combo group',()=>{const calls=[];const r=new GiftRouter(config(),a=>calls.push(a),()=>{});r.gift(event());r.gift(event({user:{id:'456'}}));assert.equal(calls.length,6);});
test('settings reject command injection, unsupported action and invalid bounds',()=>{for(const field of [{giftId:'5655;quit'},{action:'quit'},{amount:Infinity},{amount:-1},{maxRepeat:99}]){const c=config();Object.assign(c.mappings[0],field);assert.throws(()=>validateConfig(c));}});
test('unidentifiable gifts and paused dispatch never claim execution',()=>{assert.equal(normalizeGift(event({groupId:'',common:{},msgId:''})),null);const r=new GiftRouter(config(),()=>false,()=>{});assert.equal(r.gift(event()).sent,0);});

test('five timed gifts produce one exact fifty-second addition and separate combos top up inside cooldown',()=>{
 const c=config();Object.assign(c.mappings[0],{action:'no_ads',duration:10,cooldown:60,giftName:'Rose'});
 const calls=[];const r=new GiftRouter(c,a=>calls.push(a),()=>{});
 assert.equal(r.gift(event({repeatCount:5})).sent,1);assert.equal(calls[0].duration,50);assert.equal(calls[0].giftCount,5);
 r.gift(event({repeatCount:2,groupId:'next'}));assert.equal(calls[1].duration,20);
 r.gift(event({repeatCount:5}));assert.equal(calls.length,2);
});
test('timed progressive combo respects total combo cap and does not add the cumulative count twice',()=>{
 const c=config();Object.assign(c.mappings[0],{action:'slow',duration:120,cooldown:3,maxRepeat:5});
 const calls=[];const r=new GiftRouter(c,a=>calls.push(a),()=>{});
 for(const count of [1,3,5,9])r.gift(event({repeatEnd:0,repeatCount:count}));r.gift(event({repeatCount:9}));
 assert.deepEqual(calls.map(a=>a.duration),[120,240,240]);assert.equal(calls.reduce((n,a)=>n+a.duration,0),600);
});
test('two viewers and two timed rules keep their own duration budgets',()=>{
 const c=config();Object.assign(c.mappings[0],{action:'slow',duration:10});c.mappings.push({...c.mappings[0],id:'jump',action:'no_jump',duration:3});
 const calls=[];const r=new GiftRouter(c,a=>calls.push(a),()=>{});r.gift(event({repeatCount:5}));r.gift(event({user:{id:'other'},uniqueId:'second',repeatCount:2}));
 assert.deepEqual(calls.map(a=>[a.action,a.duration]),[['slow',50],['no_jump',15],['slow',20],['no_jump',6]]);
});
test('unstable streak frames wait for their final event rather than risk duplicate paid gifts',()=>{
 const calls=[];const r=new GiftRouter(config(),a=>calls.push(a),()=>{});assert.equal(r.gift(event({groupId:'',repeatEnd:0})).ignored,true);assert.equal(calls.length,0);r.gift(event({groupId:''}));assert.equal(calls.length,3);
});
