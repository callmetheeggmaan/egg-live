import test from 'node:test';import assert from 'node:assert/strict';
import {GameBridge,packetViewer,actionPacket} from '../companion/game.mjs';import {defaults,ACTIONS} from '../companion/engine.mjs';import {EXTRAS} from '../companion/extras.mjs';
import fs from 'node:fs';import os from 'node:os';import path from 'node:path';
test('startup ignores historical test notices and heartbeats but reads new game output',()=>{
 const folder=fs.mkdtempSync(path.join(os.tmpdir(),'egg-live-fresh-log-'));const file=path.join(folder,'console_mp.log');
 try{fs.writeFileSync(file,'EGGLIVE1|ready|old_map|playing|1\nEGGLIVE1|notice|shown|points|test_viewer\n');const events=[];const b=new GameBridge({...defaults(),gamePath:folder},(...e)=>events.push(e));b.readLog();assert.equal(b.status().connected,false);assert.equal(events.length,0);
 fs.appendFileSync(file,'EGGLIVE1|ready|new_map|playing|2\n');b.readLog();assert.equal(b.status().connected,true);assert.equal(b.map,'new_map');
 }finally{fs.rmSync(folder,{recursive:true,force:true});}
});
test('notification overflow and expiry are visible separately from effect acknowledgements',()=>{
  const events=[];const b=new GameBridge(defaults(),(...e)=>events.push(e));
  b.pending={id:'burst_1',action:'points'};
  b.consume('EGGLIVE1|notice|full|points|viewer_one\nEGGLIVE1|notice|expired|ammo|viewer_two\nEGGLIVE1|ack|burst_1|ok|points\n');
  assert.equal(b.pending,null);assert.equal(events.length,3);assert.match(events[0][1],/effect already applied.*viewer_one/);assert.match(events[1][1],/expired.*viewer_two/);assert.equal(events[2][0],'applied');
});
test('Pause clears native messages without executing an effect or replaying queued actions',async()=>{
  const folder=fs.mkdtempSync(path.join(os.tmpdir(),'egg-live-pause-'));fs.mkdirSync(path.join(folder,'players'));
  try{
    const b=new GameBridge({...defaults(),gamePath:folder},()=>{});b.readLog=()=>{};b.beat=Date.now();let inputs=0;b.key=async()=>{inputs++;};
    b.arm();b.enqueue({action:'points',amount:1000,duration:0});b.pause();await b.tick();
    assert.equal(inputs,1);assert.equal(b.queue.length,0);assert.equal(b.pending,null);assert.equal(b.clearNotices,false);
    assert.equal(fs.readFileSync(path.join(folder,'players','egg_live_inbox.cfg'),'utf8'),'modvar egg_live_clear 1\n');
    await b.tick();assert.equal(inputs,1);
  }finally{fs.rmSync(folder,{recursive:true,force:true});}
});
test('viewer packet preserves real username and removes native command/HUD syntax',()=>{assert.equal(packetViewer({viewer:'@egg.viewer_21'}),'egg.viewer_21');assert.equal(packetViewer({viewer:'bad|name;quit\n^1 hi'}),'badnamequit1hi');assert.equal(packetViewer({viewer:'real_user',test:true}),'test_viewer');assert.equal(packetViewer({viewer:'|;'}),'Viewer');assert.equal(packetViewer({viewer:'x'.repeat(100)}).length,64);});
test('exactly fifty extras plus three nearby zombie presets',()=>{assert.equal(EXTRAS.length,53);assert.equal(ACTIONS.length,69);assert.equal(new Set(ACTIONS.map(a=>a.id)).size,69);assert.deepEqual(EXTRAS.filter(a=>a.id.startsWith('spawn_near_')).map(a=>a.amount),[1,10,50]);});
test('only the outstanding packet can be acknowledged',()=>{const events=[];const b=new GameBridge(defaults(),(...e)=>events.push(e));b.pending={id:'abc_1',action:'points'};b.consume('EGGLIVE1|ack|different_1|ok|points\n');assert.ok(b.pending);b.consume('EGGLIVE1|ack|abc_1|ok|points\n');assert.equal(b.pending,null);assert.equal(events[0][0],'applied');});
test('paused bridge rejects and pause clears queue',()=>{const b=new GameBridge(defaults(),()=>{});assert.equal(b.enqueue({action:'points'}),false);b.beat=Date.now();b.arm();assert.equal(b.enqueue({action:'points'}),true);b.pause();assert.equal(b.queue.length,0);assert.equal(b.armed,false);});
test('missing heartbeat prevents arming and queue is capped',()=>{const b=new GameBridge({...defaults(),queueLimit:1},()=>{});assert.throws(()=>b.arm());b.beat=Date.now();b.arm();assert.equal(b.enqueue({action:'points'}),true);assert.equal(b.enqueue({action:'points'}),false);});
test('game rejection is reported rather than called applied',()=>{const events=[];const b=new GameBridge(defaults(),(...e)=>events.push(e));b.pending={id:'abc_1',action:'spawn_near_50'};b.consume('EGGLIVE1|ack|abc_1|no_clear_space|spawn_near_50\n');assert.equal(events[0][0],'rejected');});

test('saving enables immediately with a connected mod',()=>{const b=new GameBridge(defaults(),()=>{});b.beat=Date.now();b.configure(defaults());b.enableAfterSave();assert.equal(b.armed,true);assert.equal(b.status().autoEnable,true);});
test('saved actions wait for the mod and enable when its heartbeat arrives',async()=>{const b=new GameBridge(defaults(),()=>{});b.readLog=()=>{};b.enableAfterSave();assert.equal(b.armed,false);b.consume('EGGLIVE1|ready|test_map|playing|1\n');await b.tick();assert.equal(b.armed,true);});
test('explicit pause cancels automatic enabling until the next save',async()=>{const b=new GameBridge(defaults(),()=>{});b.readLog=()=>{};b.key=async()=>{};b.enableAfterSave();b.pause();b.beat=Date.now();await b.tick();assert.equal(b.armed,false);b.enableAfterSave();assert.equal(b.armed,true);});
test('saved actions can wait for a previously connected game to resume, without sending input while stale',async()=>{const b=new GameBridge(defaults(),()=>{});b.readLog=()=>{};b.map='known_map';b.state='playing';b.enableAfterSave();let sent=false;b.key=async()=>{sent=true;};assert.equal(b.enqueue({action:'points'}),true);await b.tick();assert.equal(sent,false);assert.equal(b.queue.length,1);b.pause();assert.equal(b.queue.length,0);});
test('waiting actions expire even before BO3 reconnects',async()=>{const b=new GameBridge(defaults(),()=>{});b.readLog=()=>{};b.map='known_map';b.enableAfterSave();b.enqueue({action:'points'});b.queue[0].created=Date.now()-31000;await b.tick();assert.equal(b.queue.length,0);});


test('v3 sends combined duration, real sender, safe gift and count without clipping at120seconds',()=>{
 const a=ACTIONS.find(a=>a.id==='no_ads');const packet=actionPacket({action:'no_ads',amount:1,duration:600,viewer:'@viewer.one',gift:'Rose|;\n^1',giftCount:5},a,'safe_1',3).split('|');
 assert.equal(packet[3],'600');assert.equal(packet[5],'v3');assert.equal(packet[6],'viewer.one');assert.equal(packet[7],'Rose1');assert.equal(packet[8],'5');assert.equal(packet.length,9);
 const b=new GameBridge(defaults(),()=>{});b.consume('EGGLIVE1|ready|map|playing|1|v3\n');assert.equal(b.status().protocol,3);b.consume('EGGLIVE1|ready|map|playing|2\n');assert.equal(b.status().protocol,2);
});
test('legacy receiver refuses timed stacking with an actionable error instead of silently resetting it',async()=>{
 const messages=[];const b=new GameBridge(defaults(),(...e)=>messages.push(e));b.readLog=()=>{};b.beat=Date.now();b.state='playing';b.arm();b.enqueue({action:'slow',amount:1,duration:50});b.key=async()=>{throw Error('must not dispatch');};await b.tick();assert.equal(b.queue.length,0);assert.ok(messages.some(e=>e[0]==='rejected'&&/update the Workshop/.test(e[1])));
});

test('spawn hub connects before difficulty selection and paused signals keep session identity',()=>{
 const b=new GameBridge(defaults(),()=>{});b.consume('EGGLIVE1|ready|zm_eggstinction|waiting|1|v3\n');
 assert.equal(b.status().connected,true);assert.equal(b.status().state,'waiting');
 b.beat=Date.now()-9000;assert.equal(b.status().connected,true);assert.equal(b.status().signalFresh,false);assert.equal(b.status().state,'paused');assert.throws(()=>b.arm());
 b.gameRunning=false;assert.equal(b.status().connected,false);
});
