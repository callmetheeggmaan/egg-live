import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {randomBytes,randomUUID} from 'node:crypto';
import {ACTIONS,defaults,validateConfig,validateAudio,GiftRouter} from './engine.mjs';
import {GameBridge} from './game.mjs';
import {mergeGifts} from './gifts.mjs';
import {isGiftCatalogueError} from './public/connection-status.js';
const HERE=path.dirname(fileURLToPath(import.meta.url));
const testOnly=process.env.EGG_LIVE_ALLOW_LIVE==='0';
const testTools=process.env.EGG_LIVE_TEST_TOOLS==='1';
const version=JSON.parse(fs.readFileSync(path.join(HERE,'package.json'),'utf8')).version;
const DATA=process.env.EGG_LIVE_DATA||path.join(HERE,'..','data');fs.mkdirSync(DATA,{recursive:true});
const FILE=path.join(DATA,'settings.json');
let config=defaults();if(fs.existsSync(FILE)){try{config=validateConfig(JSON.parse(fs.readFileSync(FILE)));}catch(e){console.error('Config needs attention:',e.message);}}
const token=randomBytes(24).toString('hex');const events=[];const clients=new Set();let live=null,reconnect=null,stopped=true;
const bundled=JSON.parse(fs.readFileSync(path.join(HERE,'assets','gifts.json'),'utf8'));
const GIFT_CACHE=path.join(DATA,'gift-catalogue.json');
let cached=[];try{cached=JSON.parse(fs.readFileSync(GIFT_CACHE,'utf8'));}catch{}
let tiktok={state:'disconnected',error:'',room:''};let gifts=mergeGifts(bundled.gifts,cached);
let giftCatalog={updated:bundled.updated,source:bundled.source,roomSynced:false,revision:1};
function event(kind,message){const e={id:randomUUID(),time:new Date().toISOString(),kind,message:String(message).slice(0,500)};events.unshift(e);events.length=Math.min(events.length,150);for(const c of clients)c.write(`data: ${JSON.stringify(e)}\n\n`);}
const bridge=new GameBridge(config,event);const router=new GiftRouter(config,a=>bridge.enqueue(a),event);
bridge.setAudio(validateAudio(config));
setInterval(()=>bridge.tick(),100).unref();
bridge.checkProcess();setInterval(()=>bridge.checkProcess(),2000).unref();
function persist(c){const temp=FILE+'.tmp';fs.writeFileSync(temp,JSON.stringify(c,null,2));fs.renameSync(temp,FILE);}
async function disconnect(){stopped=true;clearTimeout(reconnect);const old=live;live=null;if(old)await old.disconnect();tiktok={state:'disconnected',error:'',room:''};bridge.pause();}
async function connect(){
  if(testOnly)throw Error('This preview is in test mode. Real TikTok LIVE testing has not been enabled.');
  if(!config.username)throw Error('Enter your TikTok username first');
  const resumeActions=bridge.autoEnable;
  await disconnect();stopped=false;tiktok={state:'connecting',error:'',room:''};
  try{
    const {TikTokLiveConnection,WebcastEvent}=await import('tiktok-live-connector');
    const connection=new TikTokLiveConnection(config.username,{processInitialData:false,enableExtendedGiftInfo:false});live=connection;
    connection.on('error',err=>{if(isGiftCatalogueError(err)){event('catalogue','Room gift-list refresh unavailable; the preloaded library remains available.');return;}tiktok.error=String(err?.message||err?.info||err);event('tiktok',tiktok.error);});
    connection.on(WebcastEvent.GIFT??'gift',e=>{if(live!==connection||!connection.isConnected)return;router.gift(e,String(connection.roomId||tiktok.room));});
    connection.on('disconnected',()=>{if(stopped||live!==connection)return;tiktok.state='reconnecting';bridge.pause();event('tiktok','Connection lost. Actions paused; reconnecting in 15 seconds.');reconnect=setTimeout(()=>connect().catch(e=>event('error',e.message)),15000);});
    const state=await connection.connect();if(live!==connection){await connection.disconnect();return;}
    tiktok={state:'connected',error:'',room:String(state.roomId||connection.roomId||'')};if(resumeActions)bridge.enableAfterSave();event('tiktok',`Connected to @${config.username}. ${resumeActions?'Saved actions are ready when BO3 connects.':'Save your gift actions when ready.'}`);
    // Room catalogue signing is a paid service. Gift websocket routing only needs IDs,
    // so use the bundled/cached catalogue without making that optional request.
    event('catalogue',`${gifts.length} preloaded gifts ready. No paid room catalogue request is made.`);
  }catch(e){tiktok={state:'error',error:e.message,room:''};stopped=true;event('error',`TikTok connection failed: ${e.message}`);throw e;}
}
const server=http.createServer(async(req,res)=>{
  const url=new URL(req.url,'http://127.0.0.1');
  const json=(status,data)=>{res.writeHead(status,{'Content-Type':'application/json','Cache-Control':'no-store'});res.end(JSON.stringify(data));};
  if(!/^127\.0\.0\.1(?::\d+)?$/.test(req.headers.host||''))return json(403,{error:'Local access only'});
  try{
    if(req.method==='GET'&&url.pathname==='/api/state')return json(200,{appId:'egg-live',version,token,config,actions:ACTIONS,tiktok,game:bridge.status(),gifts,giftCatalog,events,testOnly,testTools});
    if(req.method==='GET'&&url.pathname==='/api/events'){
      res.writeHead(200,{'Content-Type':'text/event-stream','Cache-Control':'no-cache','Connection':'keep-alive'});res.write(': connected\n\n');clients.add(res);req.on('close',()=>clients.delete(res));return;
    }
    if(req.method==='POST'&&url.pathname.startsWith('/api/')){
      if(req.headers['x-egg-token']!==token)return json(403,{error:'Refresh this local page'});
      const origin=req.headers.origin;if(origin&&origin!==`http://${req.headers.host}`)return json(403,{error:'Origin refused'});
      let body='';for await(const chunk of req){body+=chunk;if(body.length>100000)throw Error('Request too large');}const data=body?JSON.parse(body):{};
      switch(url.pathname){
        case '/api/audio':{const audio=validateAudio(data);config={...config,...audio};bridge.config=config;router.config=config;persist(config);bridge.setAudio(audio);return json(200,{ok:true,...audio});}
        case '/api/config':{const next=validateConfig(data);if(bridge.pending)throw Error('Wait for the current action before saving');if(next.username!==config.username)await disconnect();bridge.configure(next);bridge.setAudio(validateAudio(next));config=next;router.config=next;router.last.clear();persist(next);bridge.enableAfterSave();event('saved',bridge.armed?'Gift actions saved and enabled.':'Gift actions saved. They will enable automatically when BO3 connects.');return json(200,{ok:true,game:bridge.status()});}
        case '/api/connect':await connect();break;
        case '/api/disconnect':await disconnect();break;
        case '/api/arm':bridge.arm();break;
        case '/api/pause':bridge.pause();break;
        case '/api/setup':bridge.setup();break;
        case '/api/launch':bridge.launch();break;
        case '/api/test':{
          if(!testTools)return json(404,{error:'Test events are not available in the player release.'});
          const row=config.mappings.find(r=>r.id===data.mapping);if(!row)throw Error('Save and select a mapping first');
          const sample={giftId:row.giftId,giftName:row.giftName,repeatCount:Math.min(20,Number(data.count)||1),giftType:1,repeatEnd:true,msgId:randomUUID(),groupId:randomUUID(),userId:'demo',uniqueId:'Test viewer'};
          if(data.send!==true){event('preview',`${row.giftName} → ${ACTIONS.find(a=>a.id===row.action).label} • ${row.amount} • ${row.duration}s`);break;}
          if(!bridge.status().connected&&!(bridge.autoEnable&&bridge.map))throw Error('BO3 is not connected. Open BO3 with the Egg LIVE mod and enter Zombies first.');
          if(!bridge.armed&&!bridge.autoEnable)throw Error('Game actions are paused. Save your actions to enable them, then try again.');
          if(bridge.state!=='playing')throw Error('Enter a Zombies match before sending a test.');
          const result=router.gift(sample,'test',true);
          if(!result.sent)throw Error('No test action queued. Turn this rule on and check its cooldown.');
          return json(200,{ok:true,sent:result.sent});
        }
        default:return json(404,{error:'Unknown command'});
      }return json(200,{ok:true});
    }
    if(req.method==='GET'){
      const files={'/':'index.html','/app.js':'app.js','/connection-status.js':'connection-status.js','/style.css':'style.css'};const file=files[url.pathname];
      if(file){res.writeHead(200,{'Content-Type':file.endsWith('.html')?'text/html; charset=utf-8':file.endsWith('.css')?'text/css':'text/javascript','Content-Security-Policy':"default-src 'self'; img-src 'self' https:; connect-src 'self'; style-src 'self'; script-src 'self'; frame-ancestors 'none'",'X-Content-Type-Options':'nosniff','Referrer-Policy':'no-referrer'});return fs.createReadStream(path.join(HERE,'public',file)).pipe(res);}
    }json(404,{error:'Not found'});
  }catch(e){event('error',e.message);json(400,{error:e.message});}
});
server.listen(Number(process.env.PORT||8790),'127.0.0.1',()=>console.log('Egg LIVE: http://127.0.0.1:'+server.address().port));
process.on('SIGINT',()=>{bridge.pause();bridge.child?.kill();server.close();process.exit(0);});

