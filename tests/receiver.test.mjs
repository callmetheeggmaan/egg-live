import test from 'node:test';import assert from 'node:assert/strict';
import fs from 'node:fs';import os from 'node:os';import path from 'node:path';
import {receiverName} from '../companion/game.mjs';
test('receiver discovery supports subscribed Workshop installs and the local preview',()=>{
  const base=fs.mkdtempSync(path.join(os.tmpdir(),'egg-live-receiver-'));
  try{
    const game=path.join(base,'steamapps/common/Call of Duty Black Ops III');fs.mkdirSync(game,{recursive:true});
    assert.throws(()=>receiverName(game),/receiver is missing/);
    fs.mkdirSync(path.join(game,'mods/egg_live/zone'),{recursive:true});fs.writeFileSync(path.join(game,'mods/egg_live/zone/zm_mod.ff'),'fixture');
    assert.equal(receiverName(game),'egg_live');
    const subscribed=path.join(base,'steamapps/workshop/content/311210/123456789');fs.mkdirSync(subscribed,{recursive:true});
    fs.writeFileSync(path.join(subscribed,'workshop.json'),JSON.stringify({FolderName:'other_mod',Type:'mod'}));fs.writeFileSync(path.join(subscribed,'zm_mod.ff'),'fixture');
    assert.equal(receiverName(game),'egg_live');
    fs.writeFileSync(path.join(subscribed,'workshop.json'),JSON.stringify({FolderName:'egg_live',Type:'mod'}));assert.equal(receiverName(game),'123456789');
  }finally{fs.rmSync(base,{recursive:true,force:true});}
});
