import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {spawn} from 'node:child_process';
import {once} from 'node:events';
import {defaults} from '../companion/engine.mjs';

test('HTTP test endpoint never claims a disconnected, paused or cooldown-blocked test was queued',async()=>{
  // Isolated fake game log: endpoint regression coverage, not gameplay proof.
  const folder=fs.mkdtempSync(path.join(os.tmpdir(),'egg-live-feedback-'));
  fs.mkdirSync(path.join(folder,'players'));
  const child=spawn(process.execPath,['--import',new URL('./fake-process-probe.mjs',import.meta.url).href,new URL('../companion/server.mjs',import.meta.url).pathname.replace(/^\/([A-Za-z]:)/,'$1')],{env:{...process.env,PORT:'0',EGG_LIVE_DATA:folder,EGG_LIVE_ALLOW_LIVE:'0',EGG_LIVE_TEST_TOOLS:'0'},stdio:['ignore','pipe','pipe'],windowsHide:true});
  try{
    const [output]=await once(child.stdout,'data',{signal:AbortSignal.timeout(10000)});
    const base=String(output).match(/http:\/\/127\.0\.0\.1:\d+/)[0];
    const state=await(await fetch(base+'/api/state')).json();
    assert.equal(state.testOnly,true);
    const post=(route,body)=>fetch(base+'/api/'+route,{method:'POST',headers:{'Content-Type':'application/json','X-Egg-Token':state.token},body:JSON.stringify(body)});
    const blockedLive=await post('connect',{});assert.equal(blockedLive.status,400);assert.match((await blockedLive.json()).error,/test mode/);
    const config={...defaults(),uncappedGifts:false,gamePath:folder,mappings:[{id:'regression',giftId:'5655',giftName:'Rose',action:'points',amount:1000,duration:0,cooldown:60,enabled:true}]};
    assert.equal((await post('config',config)).status,200);
    const audio=await post('audio',{triggerVolume:40,triggerMuted:true});assert.equal(audio.status,200);
    const afterAudio=await(await fetch(base+'/api/state')).json();
    assert.equal(afterAudio.config.triggerVolume,40);assert.equal(afterAudio.config.triggerMuted,true);
    assert.equal(afterAudio.config.mappings[0].id,'regression');assert.equal(afterAudio.game.autoEnable,true);
    assert.equal(JSON.parse(fs.readFileSync(path.join(folder,'settings.json'),'utf8')).triggerVolume,40);
    assert.equal((await post('audio',{triggerVolume:101})).status,400);
    let response=await post('test',{mapping:'regression',send:true});
    assert.equal(response.status,400);assert.match((await response.json()).error,/not connected/);
    fs.writeFileSync(path.join(folder,'console_mp.log'),'EGGLIVE1|ready|fixture_only|playing|1\n');
    for(let i=0;i<30;i++){if((await(await fetch(base+'/api/state')).json()).game.armed)break;await new Promise(resolve=>setTimeout(resolve,100));}
    assert.equal((await(await fetch(base+'/api/state')).json()).game.armed,true);
    await post('pause',{});
    response=await post('test',{mapping:'regression',send:true});
    assert.equal(response.status,400);assert.match((await response.json()).error,/paused/);
    const saved=await post('config',config);
    assert.equal(saved.status,200);assert.equal((await saved.json()).game.armed,true);
    response=await post('test',{mapping:'regression',send:true});
    assert.equal(response.status,200);assert.equal((await response.json()).sent,1);
    const practiceState=await(await fetch(base+'/api/state')).json();assert.equal(practiceState.tiktok.state,'disconnected');
    assert.equal(practiceState.events.some(e=>e.kind==='test'&&e.message.includes('Test viewer')),true);
    response=await post('test',{mapping:'regression',send:true});
    assert.equal(response.status,400);assert.match((await response.json()).error,/No test action queued/);
    await post('pause',{});
  }finally{child.kill();}
});
