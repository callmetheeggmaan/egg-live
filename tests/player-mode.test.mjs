import test from 'node:test';import assert from 'node:assert/strict';
import fs from 'node:fs';import os from 'node:os';import path from 'node:path';import {spawn} from 'node:child_process';import {once} from 'node:events';
test('player release enables the real connection path, starts disconnected and rejects synthetic test events',async()=>{
 const folder=fs.mkdtempSync(path.join(os.tmpdir(),'egg-live-player-'));
 const child=spawn(process.execPath,[new URL('../companion/server.mjs',import.meta.url).pathname.replace(/^\/([A-Za-z]:)/,'$1')],{env:{...process.env,PORT:'0',EGG_LIVE_DATA:folder,EGG_LIVE_ALLOW_LIVE:'1',EGG_LIVE_TEST_TOOLS:'0'},stdio:['ignore','pipe','pipe'],windowsHide:true});
 try{
  const [output]=await once(child.stdout,'data',{signal:AbortSignal.timeout(10000)}),base=String(output).match(/http:\/\/127\.0\.0\.1:\d+/)[0];
  const state=await(await fetch(base+'/api/state')).json();assert.equal(state.testOnly,false);assert.equal(state.testTools,false);assert.equal(state.tiktok.state,'disconnected');
  const post=(route,data)=>fetch(base+'/api/'+route,{method:'POST',headers:{'Content-Type':'application/json','X-Egg-Token':state.token},body:JSON.stringify(data)});
  const fake=await post('test',{});assert.equal(fake.status,404);
  const connect=await post('connect',{});assert.equal(connect.status,400);assert.match((await connect.json()).error,/username first/);
  const after=await(await fetch(base+'/api/state')).json();assert.equal(after.tiktok.state,'disconnected');
 }finally{child.kill();}
});
