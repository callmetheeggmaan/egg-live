import test from 'node:test';
import assert from 'node:assert/strict';
import {defaults,validateConfig,GiftRouter} from '../companion/engine.mjs';
import {GameBridge} from '../companion/game.mjs';

test('five different gifts retain their own action and sender once each under a burst',()=>{
  const actions=['points','ammo','heal','take_points','spin'];
  const config=validateConfig({...defaults(),mappings:actions.map((action,i)=>({id:`rule${i}`,giftId:String(5655+i),action,cooldown:0,maxRepeat:5}))});
  const bridge=new GameBridge(config,()=>{});bridge.beat=Date.now();bridge.arm();
  const router=new GiftRouter(config,item=>bridge.enqueue(item),()=>{});
  for(let i=0;i<5;i++){
    const gift={giftId:5655+i,giftType:4,repeatCount:1,msgId:`burst${i}`,uniqueId:`viewer_${i}`,userId:String(i)};
    assert.equal(router.gift(gift,'local-test',true).sent,1);
    assert.equal(router.gift(gift,'local-test',true).duplicate,true);
  }
  assert.deepEqual(bridge.queue.map(item=>item.action),actions);
  assert.deepEqual(bridge.queue.map(item=>item.viewer),actions.map((_,i)=>`viewer_${i}`));
});

test('streak caps and global backpressure report the exact accepted effect count',()=>{
  const events=[];
  const config=validateConfig({...defaults(),queueLimit:3,mappings:[{id:'rose',giftId:'5655',action:'points',cooldown:0,maxRepeat:5}]});
  const bridge=new GameBridge(config,(...e)=>events.push(e));bridge.beat=Date.now();bridge.arm();
  const router=new GiftRouter(config,item=>bridge.enqueue(item),(...e)=>events.push(e));
  const gift={giftId:5655,giftType:1,groupId:'streak',repeatCount:50,userId:'1',uniqueId:'viewer'};
  assert.equal(router.gift({...gift,repeatEnd:0}).ignored,true);
  assert.equal(router.gift({...gift,repeatEnd:1}).sent,3);
  assert.equal(bridge.queue.length,3);
  assert.equal(events.filter(e=>e[0]==='skipped').length,2);
  assert.ok(events.some(e=>e[0]==='capped'));
  bridge.pause();assert.equal(bridge.queue.length,0);
});
