import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';import os from 'node:os';import path from 'node:path';
import {defaults,validateConfig,validateAudio} from '../companion/engine.mjs';
import {GameBridge} from '../companion/game.mjs';

test('old profiles get the current mix; volume and mute validate and survive export',()=>{
  const profile=validateConfig(defaults());assert.equal(profile.triggerVolume,70);assert.equal(profile.triggerMuted,false);
  assert.deepEqual(validateAudio({triggerVolume:0,triggerMuted:false}),{triggerVolume:0,triggerMuted:false});
  assert.deepEqual(validateAudio({triggerVolume:100,triggerMuted:true}),{triggerVolume:100,triggerMuted:true});
  for(const triggerVolume of [-1,101,Infinity,'quit'])assert.throws(()=>validateAudio({triggerVolume}));
  assert.throws(()=>validateAudio({triggerMuted:'false'}));
  const muted=validateConfig({...profile,triggerVolume:40,triggerMuted:true});
  assert.equal(validateConfig(JSON.parse(JSON.stringify(muted))).triggerVolume,40);
});

test('audio changes use their own acknowledged packet and do not arm or discard actions',async()=>{
  const folder=fs.mkdtempSync(path.join(os.tmpdir(),'egg-live-audio-'));fs.mkdirSync(path.join(folder,'players'));
  try{
    const bridge=new GameBridge({...defaults(),gamePath:folder},()=>{});bridge.readLog=()=>{};bridge.beat=Date.now();bridge.key=async()=>{};
    bridge.queue=[{action:'points'}];bridge.setAudio({triggerVolume:40,triggerMuted:true});const oldToken=bridge.audioToken;
    await bridge.tick();
    assert.equal(bridge.armed,false);assert.equal(bridge.queue.length,1);assert.equal(bridge.pending,null);
    assert.equal(fs.readFileSync(path.join(folder,'players','egg_live_inbox.cfg'),'utf8'),`modvar egg_live_volume 40\nmodvar egg_live_mute 1\nmodvar egg_live_audio ${oldToken}\n`);
    assert.equal(bridge.status().audioSynced,false);
    bridge.setAudio({triggerVolume:90,triggerMuted:false});
    bridge.consume(`EGGLIVE1|audio|${oldToken}|40|1\n`);assert.equal(bridge.status().audioSynced,false);
    await bridge.tick();bridge.consume(`EGGLIVE1|audio|${bridge.audioToken}|90|0\n`);
    assert.equal(bridge.status().audioSynced,true);assert.equal(bridge.queue.length,1);
  }finally{fs.rmSync(folder,{recursive:true,force:true});}
});

test('audio changes wait while a gameplay acknowledgement is outstanding',async()=>{
  const bridge=new GameBridge(defaults(),()=>{});bridge.readLog=()=>{};bridge.beat=Date.now();let inputs=0;bridge.key=async()=>{inputs++;};
  bridge.pending={id:'existing_1',action:'points',sent:Date.now()};bridge.setAudio({triggerVolume:0,triggerMuted:false});await bridge.tick();
  assert.equal(inputs,0);assert.equal(bridge.pending.id,'existing_1');
});
test('a reconnect resends persisted sound settings instead of trusting the old acknowledgement',()=>{
  const bridge=new GameBridge(defaults(),()=>{});bridge.setAudio({triggerVolume:30,triggerMuted:true});const previous=bridge.audioToken;
  bridge.audioAck=previous;bridge.beat=Date.now()-7000;
  bridge.consume('EGGLIVE1|ready|zm_factory|playing|1\n');
  assert.notEqual(bridge.audioToken,previous);assert.equal(bridge.status().audioSynced,false);
  assert.deepEqual(bridge.audioDesired,{triggerVolume:30,triggerMuted:true});
});
