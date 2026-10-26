import test from 'node:test';import assert from 'node:assert/strict';import fs from 'node:fs';
import {PARTY} from '../companion/party.mjs';
import {ACTIONS,defaults,validateConfig,GiftRouter} from '../companion/engine.mjs';
import {groupedActions} from '../companion/public/action-options.js';
test('25 distinct party effects append to all 69 original actions without changing original IDs',()=>{
 assert.equal(PARTY.length,25);assert.equal(ACTIONS.length,94);assert.equal(new Set(ACTIONS.map(a=>a.id)).size,94);
 assert.equal(PARTY.filter(a=>a.kind==='help').length,12);assert.equal(PARTY.filter(a=>a.kind==='chaos').length,13);
 assert.equal(PARTY.every(a=>a.description.length>15&&a.amount===1&&a.max===1),true);
 const source=fs.readFileSync(new URL('../mod/scripts/zm/egg_live_party.gsc',import.meta.url),'utf8');
 const receiver=fs.readFileSync(new URL('../mod/scripts/zm/egg_live.gsc',import.meta.url),'utf8');
 for(const a of PARTY){assert.ok(source.includes('"'+a.id+'"'),a.id+' has native handling');assert.ok(receiver.includes('case "'+a.id+'":return'),a.id+' has a banner/timer title');}
});
test('selector groups every available action into Help then Chaos and sorts each alphabetically',()=>{
 const groups=groupedActions(ACTIONS);assert.deepEqual(groups.map(g=>g.label),['Help the player','Create chaos']);
 assert.equal(groups.flatMap(g=>g.actions).length,93);assert.equal(groups.flatMap(g=>g.actions).some(a=>a.id==='ping'),false);
 for(const g of groups){assert.ok(g.actions.every(a=>a.kind===g.kind));for(let i=1;i<g.actions.length;i++)assert.ok(g.actions[i-1].label.localeCompare(g.actions[i].label,'en',{sensitivity:'base',numeric:true})<=0);}
});
test('all new effects validate and route a labelled practice gift with the requested timer duration',()=>{
 for(const a of PARTY){const config=validateConfig({...defaults(),mappings:[{id:a.id,giftId:'6064',giftName:'GG',action:a.id,duration:a.duration,cooldown:0,maxRepeat:5}]});
 const sent=[];const router=new GiftRouter(config,item=>{sent.push(item);return true;},()=>{});
 const result=router.gift({giftId:'6064',giftType:1,repeatEnd:1,repeatCount:2,groupId:'test-'+a.id,userId:'practice',uniqueId:'Test viewer'},'practice',true);
 assert.ok(result.sent>0);assert.equal(sent[0].action,a.id);assert.equal(sent[0].test,true);
 if(a.duration>0){assert.equal(sent.length,1);assert.equal(sent[0].duration,a.duration*2);}else assert.equal(sent.length,2);
 }
});
