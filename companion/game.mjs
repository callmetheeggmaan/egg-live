import fs from 'node:fs';
import path from 'node:path';
import {spawn,execFile} from 'node:child_process';
import readline from 'node:readline';
import {fileURLToPath} from 'node:url';
import {ACTIONS} from './engine.mjs';
const HERE=path.dirname(fileURLToPath(import.meta.url));
function logBaseline(root){try{return fs.statSync(path.join(root,'console_mp.log')).size;}catch{return 0;}}
// Only TikTok username characters enter the native config packet, never commands or HUD colour codes.
export function packetViewer(item){return item.test?'test_viewer':String(item.viewer||'Viewer').replace(/^@/,'').replace(/[^a-zA-Z0-9_.]/g,'').slice(0,64)||'Viewer';}
export function actionPacket(item,spec,id,protocol=2){
  const seconds=Math.max(0,Math.min(protocol>=3?3600:120,Number(item.duration)||0));
  const base=`${id}|${spec.id}|${Math.min(spec.max,item.amount)}|${seconds}|${Math.floor(Date.now()/1000)+5}`;
  if(protocol<3)return `${base}|v2|${packetViewer(item)}`;
  const gift=String(item.gift||'Gift').replace(/[^a-zA-Z0-9 _.-]/g,'').trim().slice(0,28).replace(/ /g,'_')||'Gift';
  return `${base}|v3|${packetViewer(item)}|${gift}|${Math.max(1,Math.min(20,Number(item.giftCount)||1))}`;
}
export function receiverName(root){  const local=path.join(root,'mods','egg_live');  try{const meta=JSON.parse(fs.readFileSync(path.join(local,'workshop.json'),'utf8').replace(/^\uFEFF/,''));if(meta.ReceiverProtocol>=3&&fs.existsSync(path.join(local,'zone','zm_mod.ff')))return 'egg_live';}catch{}
  const workshop=path.resolve(root,'../../workshop/content/311210');
  if(fs.existsSync(workshop))for(const entry of fs.readdirSync(workshop,{withFileTypes:true})){
    if(!entry.isDirectory()||!/^\d+$/.test(entry.name))continue;
    try{const dir=path.join(workshop,entry.name),meta=JSON.parse(fs.readFileSync(path.join(dir,'workshop.json'),'utf8').replace(/^\uFEFF/,''));
      if(meta.FolderName==='egg_live'&&meta.Type==='mod'&&(fs.existsSync(path.join(dir,'zm_mod.ff'))||fs.existsSync(path.join(dir,'zone','zm_mod.ff'))))return entry.name;
    }catch{}
  }
  if(fs.existsSync(path.join(root,'mods','egg_live','zone','zm_mod.ff')))return 'egg_live';
  throw Error('Egg LIVE receiver is missing. Subscribe in Workshop, or install the included preview receiver. See START-HERE.txt.');
}
export class GameBridge {
  constructor(config,event){this.config=config;this.event=event;this.armed=false;this.queue=[];this.pending=null;this.beat=0;this.state='waiting';this.map='';this.sequence=0;this.session=Date.now().toString(36);this.logSize=logBaseline(config.gamePath);this.child=null;this.keyboardWait=null;this.processing=false;}
  configure(c){if(this.pending)throw Error('Wait for the current action');const changed=c.gamePath!==this.config.gamePath;this.config=c;this.armed=false;this.queue=[];if(changed){this.beat=0;this.logSize=logBaseline(c.gamePath);this.fragment='';}}
  setAudio(audio){this.audioDesired={...audio};this.audioToken=`${this.session}_${++this.sequence}`;this.audioAck='';this.audioSent=0;}
  checkProcess(){
    if(process.platform!=='win32'||this.probing)return;
    this.probing=true;
    execFile('tasklist.exe',['/FI','IMAGENAME eq BlackOps3.exe','/FO','CSV','/NH'],{windowsHide:true,timeout:3000},(error,stdout)=>{
      this.probing=false;if(error)return;
      this.gameRunning=/"BlackOps3\.exe"/i.test(stdout);
      if(!this.gameRunning&&this.map){this.beat=0;this.map='';this.protocol=2;this.state='waiting';this.pending=null;const resume=this.autoEnable;this.pause();this.autoEnable=resume;}
    });
  }
  setup(){
    const root=this.config.gamePath;if(!fs.existsSync(path.join(root,'BlackOps3.exe')))throw Error('BlackOps3.exe was not found in this folder');
    const players=path.join(root,'players');fs.mkdirSync(players,{recursive:true});
    const cfg='bind F10 "exec egg_live_inbox.cfg"\nlogfile "2"\n';
    fs.writeFileSync(path.join(players,'egg_live_setup.cfg'),cfg);
    this.event('setup','Setup file prepared. Load Egg LIVE mod; run /exec egg_live_setup.cfg once in BO3 console, or use Launch BO3 while the game is closed. F10 is reserved for the bridge.');
  }
  launch(){
    const exe=path.join(this.config.gamePath,'BlackOps3.exe');if(!fs.existsSync(exe))throw Error('Invalid BO3 folder');
    const steam=path.resolve(this.config.gamePath,'../../..','steam.exe');if(!fs.existsSync(steam))throw Error('Steam.exe not found; launch BO3 normally and use the setup command');
    const mod=receiverName(this.config.gamePath);
    this.setup();spawn(steam,['-applaunch','311210','+set','fs_game',mod,'+set','logfile','2','+set','scr_mod_enable_devblock','1','+exec','egg_live_setup.cfg'],{detached:true,stdio:'ignore',windowsHide:true}).unref();
  }
  enqueue(a){
    if(!this.armed&&!(this.autoEnable&&this.map)){this.event('skipped',`${a.gift||'Test'}: game actions paused`);return false;}
    if(this.queue.length>=this.config.queueLimit){this.event('skipped','Queue limit reached');return false;}
    this.queue.push({...a,created:Date.now()});return true;
  }
  pause(){this.autoEnable=false;this.armed=false;this.queue=[];this.clearNotices=true;this.event('paused','Game actions paused; queued actions cleared');}
  enableAfterSave(){this.autoEnable=true;if(Date.now()-this.beat<6000)this.arm();else this.event('waiting','Saved actions will enable automatically when BO3 connects.');}
  arm(){if(Date.now()-this.beat>6000)throw Error('No recent mod heartbeat. Load the mod and enter a solo/private Zombies match first.');this.armed=true;this.event('armed','Game actions enabled');}
  consume(text){
    for(const m of text.matchAll(/EGGLIVE1\|audio\|([a-z0-9_]+)\|(\d+)\|([01])/g)){
      if(m[1]===this.audioToken){this.audioAck=m[1];this.event('audio',`Trigger sound ${m[3]==='1'||m[2]==='0'?'muted':m[2]+'%'} applied in BO3`);}
    }
    for(const m of text.matchAll(/EGGLIVE1\|notice\|(shown|full|expired)\|([a-z_0-9]+)\|([a-zA-Z0-9_.]+)/g)){
      const message=m[1]==='shown'?'Notification shown':m[1]==='full'?'Notification queue full; effect already applied':'Old notification expired; effect already applied';
      this.event('notification',`${message}: ${m[2]} / @${m[3]}`);
    }
    for(const m of text.matchAll(/EGGLIVE1\|ready\|([^|\r\n]*)\|(playing|waiting)\|(\d+)(?:\|v([23]))?/g)){if(this.audioDesired&&this.audioAck&&Date.now()-this.beat>6000)this.setAudio(this.audioDesired);this.map=m[1];this.state=m[2];this.protocol=Number(m[4]||2);this.beat=Date.now();}
    for(const m of text.matchAll(/EGGLIVE1\|ack\|([a-z0-9_]+)\|([a-z_]+)\|([a-z_]+)/g)){
      if(this.pending?.id!==m[1])continue;
      this.event(m[2]==='ok'?'applied':'rejected',`${this.pending.action}: ${m[2]} · ${Date.now()-(this.pending.created??this.pending.sent??Date.now())} ms since queued`);this.pending=null;
    }
  }
  readLog(){
    const p=path.join(this.config.gamePath,'console_mp.log');if(!fs.existsSync(p))return;
    const size=fs.statSync(p).size;
    if(size===this.logSize)return;
    if(size<this.logSize){const resume=this.autoEnable;this.logSize=0;this.beat=0;this.pause();this.autoEnable=resume;}
    const fd=fs.openSync(p,'r');try{
      const h=Buffer.alloc(2);fs.readSync(fd,h,0,2,0);const utf16=h[0]===255&&h[1]===254;
      const start=this.logSize||Math.max(0,size-65536);const offset=utf16?start-start%2:start;
      const b=Buffer.alloc(size-offset);fs.readSync(fd,b,0,b.length,offset);this.logSize=size;
      // Preserve partial lines across polls so split ACKs are not lost.
      const text=(this.fragment||'')+b.toString(utf16?'utf16le':'utf8');const end=text.lastIndexOf('\n');
      if(end>=0){this.consume(text.slice(0,end+1));this.fragment=text.slice(end+1);}else this.fragment=text.slice(-4096);
    }finally{fs.closeSync(fd);}
  }
  key(){
    return new Promise((resolve,reject)=>{
      if(!this.child){
        this.child=spawn(process.env.EGG_LIVE_PYTHON||'python',[path.join(HERE,'keyboard.py')],{stdio:['pipe','pipe','pipe'],windowsHide:true});
        readline.createInterface({input:this.child.stdout}).on('line',line=>{let r;try{r=JSON.parse(line);}catch{return;}const w=this.keyboardWait;this.keyboardWait=null;if(w){clearTimeout(w.timer);r.ok?w.resolve():w.reject(Error(r.error));}});
        const stop=()=>{const w=this.keyboardWait;this.keyboardWait=null;this.child=null;if(w){clearTimeout(w.timer);w.reject(Error('Keyboard bridge stopped'));}};
        this.child.on('error',stop);this.child.on('exit',stop);
      }
      this.keyboardWait={resolve,reject,timer:setTimeout(()=>{this.keyboardWait=null;reject(Error('Keyboard bridge timed out'));},2000)};
      this.child.stdin.write(JSON.stringify({gamePath:this.config.gamePath})+'\n');
    });
  }
  async tick(){
    if(this.processing)return;this.processing=true;
    try{
      this.readLog();
      if(this.autoEnable&&!this.armed&&Date.now()-this.beat<6000)this.arm();
      if(this.pending){if(Date.now()-this.pending.sent>4000){this.event('unconfirmed',`${this.pending.action}: no game acknowledgement; actions paused to prevent repeats`);this.pending=null;this.pause();}return;}
      if(this.clearNotices){
        if(Date.now()-this.beat>6000)return;
        const dest=path.join(this.config.gamePath,'players','egg_live_inbox.cfg');
        fs.writeFileSync(dest+'.tmp','modvar egg_live_clear 1\n');fs.renameSync(dest+'.tmp',dest);
        try{await this.key();this.clearNotices=false;}
        catch(e){if(!/active window|focus changed/.test(e.message))this.event('error',e.message);}
        return;
      }
      if(this.audioDesired&&this.audioAck!==this.audioToken&&Date.now()-this.audioSent>2000&&Date.now()-this.beat<6000){
        const desired=this.audioDesired,token=this.audioToken;
        const dest=path.join(this.config.gamePath,'players','egg_live_inbox.cfg');
        const cfg=`modvar egg_live_volume ${desired.triggerVolume}\nmodvar egg_live_mute ${desired.triggerMuted?1:0}\nmodvar egg_live_audio ${token}\n`;
        fs.writeFileSync(dest+'.tmp',cfg);fs.renameSync(dest+'.tmp',dest);
        try{await this.key();if(token===this.audioToken)this.audioSent=Date.now();}
        catch(e){if(!/active window|focus changed/.test(e.message))this.event('error',e.message);}
        return;
      }
      while(this.queue.length&&Date.now()-this.queue[0].created>this.config.eventMaxAge*1000){this.queue.shift();this.event('expired','Queued action expired');}
      if(!this.armed||!this.queue.length)return;
      const item=this.queue[0];if(Date.now()-item.created>this.config.eventMaxAge*1000){this.queue.shift();this.event('expired','Queued action expired');return;}
      if(Date.now()-this.beat>6000|| (this.state!=='playing'&&item.action!=='ping'))return;
      const spec=ACTIONS.find(a=>a.id===item.action);if(!spec){this.queue.shift();return;}
      if(spec.duration>0&&(this.protocol||2)<3){this.queue.shift();this.event('rejected',`${spec.label}: update the Workshop mod and restart BO3 to enable stacking timers.`);return;}
      const id=`${this.session}_${++this.sequence}`;
      const packet=actionPacket(item,spec,id,this.protocol||2);
      const dest=path.join(this.config.gamePath,'players','egg_live_inbox.cfg');
      fs.writeFileSync(dest+'.tmp',`modvar egg_live_command ${packet}\n`);fs.renameSync(dest+'.tmp',dest);
      // One request outstanding; never retry an unconfirmed game action.
      try{await this.key();this.focusWait=false;this.queue.shift();this.pending={...item,id,sent:Date.now()};}
      catch(e){if(/active window|focus changed/.test(e.message)){if(!this.focusWait)this.event('waiting',e.message);this.focusWait=true;}else{this.event('error',e.message);this.pause();}}
    }catch(e){this.event('error',e.message);this.pause();}finally{this.processing=false;}
  }
  status(){const fresh=Date.now()-this.beat<6000;return {armed:this.armed,autoEnable:!!this.autoEnable,queue:this.queue.length,pending:this.pending?.action||'',connected:!!this.map&&this.gameRunning!==false,signalFresh:fresh,map:this.map,state:fresh?this.state:'paused',protocol:this.protocol||2,audioSynced:!!this.audioToken&&this.audioAck===this.audioToken};}
}
