import test from 'node:test';import assert from 'node:assert/strict';
import fs from 'node:fs';import os from 'node:os';import path from 'node:path';import {spawn} from 'node:child_process';import {once} from 'node:events';
import {defaults} from '../companion/engine.mjs';
test('player release starts disconnected and allows explicit local practice without connecting TikTok',async()=>{
 const folder=fs.mkdtempSync(path.join(os.tmpdir(),'egg-live-player-'));
 fs.writeFileSync(path.join(folder,'settings.json'),JSON.stringify({...defaults(),mappings:[{id:'saved',giftId:'6064',giftName:'GG',action:'points',amount:1000,cooldown:0}]}));
 const child=spawn(process.execPath,[new URL('../companion/server.mjs',import.meta.url).pathname.replace(/^\/([A-Za-z]:)/,'$1')],{env:{...process.env,PORT:'0',EGG_LIVE_DATA:folder,EGG_LIVE_ALLOW_LIVE:'1',EGG_LIVE_TEST_TOOLS:'0'},stdio:['ignore','pipe','pipe'],windowsHide:true});
 try{
  const [output]=await once(child.stdout,'data',{signal:AbortSignal.timeout(10000)}),base=String(output).match(/http:\/\/127\.0\.0\.1:\d+/)[0];
  const state=await(await fetch(base+'/api/state')).json();assert.equal(state.testOnly,false);assert.equal(state.testTools,false);assert.equal(state.tiktok.state,'disconnected');
  assert.equal(state.game.autoEnable,true,'saved actions are ready at startup without pressing Enable');
  const post=(route,data)=>fetch(base+'/api/'+route,{method:'POST',headers:{'Content-Type':'application/json','X-Egg-Token':state.token},body:JSON.stringify(data)});
  const fake=await post('test',{});assert.equal(fake.status,400);assert.match((await fake.json()).error,/Save and select a mapping/);
  const unauthenticated=await fetch(base+'/api/test',{method:'POST',headers:{'Content-Type':'application/json'},body:'{}'});assert.equal(unauthenticated.status,403);
  const connect=await post('connect',{});assert.equal(connect.status,400);assert.match((await connect.json()).error,/username first/);
  assert.equal((await post('disconnect',{})).status,200);
  const after=await(await fetch(base+'/api/state')).json();assert.equal(after.tiktok.state,'disconnected');
  assert.equal(after.game.autoEnable,true,'disconnecting TikTok does not disable offline practice or automatic game readiness');
 }finally{child.kill();}
});
