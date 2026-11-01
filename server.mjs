import http from 'node:http';
import https from 'node:https';
import {randomBytes, randomInt, timingSafeEqual} from 'node:crypto';
import {mkdirSync, writeFileSync, readFileSync, existsSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
import path from 'node:path';
import {MockService} from './integrations.mjs';

const root = path.dirname(fileURLToPath(import.meta.url));
const token = () => randomBytes(32).toString('hex');
const hashEqual = (a,b) => typeof a === 'string' && a.length === b.length && timingSafeEqual(Buffer.from(a),Buffer.from(b));
export function createLink({hostKey=token(), clock=Date.now, secure=false}={}) {
  let code='', codeUntil=0, state={sector:'Game not connected'}, gameSeen=0, sequence=0, commandId=0;
  const sessions=new Map(), pending=new Map(), messages=[], commands=[], reports=[], rates=new Map();
  const reads=new Map(), players=new Map([['shell-01',{party:'hatch',x:0,z:0}]]);
  const services={twitch:new MockService('Twitch'),discord:new MockService('Discord')};
  const preferences=()=>({dnd:false,preview:false,sound:false,popups:true,muted:[],blocked:[]});
  const publicDevice=s=>({id:s.id,name:s.name,permission:s.permission,player:s.player,lastSeen:s.seen});
  const visible=(m,s)=>{
    if(s.prefs.blocked.includes(m.sender)) return false;
    if(m.channel==='direct') return m.sender===s.player||m.to===s.player;
    if(m.channel==='party') return m.party===players.get(s.player)?.party;
    if(m.channel==='local') {
      const a=players.get(s.player),b=m.position;
      return a&&b&&Math.hypot(a.x-b.x,a.z-b.z)<=35;
    }
    return m.channel==='global';
  };
  const history=s=>messages.filter(m=>visible(m,s));
  const record=(s,b)=>{
    if(!['global','local','party','direct'].includes(b.channel)||typeof b.text!=='string'||!b.text.trim()||b.text.length>500) throw [400,'Invalid message'];
    if(b.channel==='direct'&&(!players.has(b.to)||b.to===s.player)) throw [400,'Choose another connected player'];
    const now=clock();
    if(now-(s.lastSend??-Infinity)<800) throw [429,'Message rate limited'];
    s.lastSend=now;
    const m={id:++sequence,channel:b.channel,text:b.text.trim(),sender:s.player,to:b.to||'',party:players.get(s.player)?.party,position:players.get(s.player),timestamp:new Date(now).toISOString(),status:'delivered',service:'VELUM'};
    messages.push(m); if(messages.length>500) messages.shift(); return m;
  };
  const headers={'Content-Type':'application/json','Cache-Control':'no-store','X-Content-Type-Options':'nosniff','Referrer-Policy':'no-referrer','Content-Security-Policy':"default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self' data:; connect-src 'self'; frame-ancestors 'none'; base-uri 'none'; form-action 'self'"};
  async function handler(req,res) {
    const send=(status,data,extra={})=>{res.writeHead(status,{...headers,...extra});res.end(typeof data==='string'?data:JSON.stringify(data));};
    try {
      const url=new URL(req.url,'http://localhost');
      for(const [id,p] of pending) if(p.expires<clock()){sessions.delete(p.token);pending.delete(id);}
      for(const [key,s] of sessions) if(s.expires<clock())sessions.delete(key);
      const host=req.headers.host||'';
      // Same-origin requests only. No permissive CORS; host credentials never enter the browser.
      const tls=secure||Boolean(req.socket.encrypted);
      if(!/^(127\.0\.0\.1|localhost|\[::1\]|\d{1,3}(?:\.\d{1,3}){3})(:\d+)?$/.test(host)) throw [403,'Host denied'];
      if(req.headers.origin&&req.headers.origin!==`${tls?'https':'http'}://${host}`) throw [403,'Origin denied'];
      if(req.method==='GET'&&['/','/app.js','/style.css'].includes(url.pathname)) {
        const name=url.pathname==='/'?'index.html':url.pathname.slice(1);
        return send(200,readFileSync(path.join(root,'companion',name),'utf8'),{'Content-Type':name.endsWith('.js')?'text/javascript':name.endsWith('.css')?'text/css':'text/html'});
      }
      let body={};
      if(req.method==='POST') {
        let raw='';
        for await(const chunk of req) {raw+=chunk;if(raw.length>(url.pathname==='/host/state'?524288:16384)) throw [413,'Request too large'];}
        try {body=JSON.parse(raw||'{}');} catch {throw [400,'Invalid JSON'];}
      }
      const isHost=url.pathname.startsWith('/host/');
      if(isHost) {
        if(!['127.0.0.1','::1','::ffff:127.0.0.1'].includes(req.socket.remoteAddress)||!hashEqual((req.headers.authorization||'').replace(/^Bearer /,''),hostKey)) throw [403,'Host only'];
        if(req.method!=='POST') throw [405,'POST required'];
        switch(url.pathname) {
          case '/host/inspect': return send(200,{code:clock()<codeUntil?code:'—',pending:[...pending.values()].filter(p=>p.expires>clock()).map(p=>({id:p.id,name:p.name})),devices:[...sessions.values()].filter(s=>s.approved).map(publicDevice)});
          case '/host/code': code=String(randomInt(100000,1000000));codeUntil=clock()+120000;return send(200,{ok:true});
          case '/host/approve': {
            const p=pending.get(body.id);if(!p||p.expires<clock()) throw [404,'Request expired'];
            const s=sessions.get(p.token);s.permission=body.permission==='control'?'control':'read';s.approved=true;pending.delete(body.id);return send(200,{ok:true});
          }
          case '/host/revoke':
            for(const [key,s] of sessions) if(body.id==='all'||s.id===body.id) {sessions.delete(key);pending.delete(s.id);}
            commands.length=0;return send(200,{ok:true});
          case '/host/chat': return send(200,record(hostSession,body));
          case '/host/preferences':
            for(const k of ['dnd','preview','sound','popups']) if(typeof body[k]==='boolean') hostSession.prefs[k]=body[k];
            for(const k of ['muted','blocked']) if(Array.isArray(body[k])) hostSession.prefs[k]=body[k].filter(v=>typeof v==='string').slice(0,50);
            return send(200,{ok:true});
          case '/host/read': {
            const r=reads.get('shell-01')||{};
            for(const m of history(hostSession)) {const ch=m.channel==='direct'?`direct:${m.sender}`:m.channel;r[ch]=Math.max(r[ch]||0,m.id);}
            reads.set('shell-01',r);return send(200,{ok:true});
          }
          case '/host/report':
            if(!history(hostSession).some(m=>m.id===Number(body.id))) throw [404,'Message unavailable'];
            reports.push({id:Number(body.id),reason:String(body.reason||'').slice(0,300),at:clock()});
            return send(200,{status:'Local volatile report only; no moderation backend'});
          case '/host/state': {
            state=body;gameSeen=clock();players.set('shell-01',{party:'hatch',x:state.x||0,z:state.z||0});
            const ack=Number(body.ack)||0;while(commands.length&&commands[0].id<=ack) commands.shift();
            return send(200,{code:clock()<codeUntil?code:'—',pending:[...pending.values()].filter(p=>p.expires>clock()).map(p=>({id:p.id,name:p.name})),devices:[...sessions.values()].filter(s=>s.approved).map(publicDevice),messages:history(hostSession),reads:reads.get('shell-01')||{},preferences:hostSession.prefs,commands});
          }
          default: throw [404,'Unknown host route'];
        }
      }
      if(url.pathname==='/api/pair'&&req.method==='POST') {
        const ip=req.socket.remoteAddress,limit=rates.get(ip)||{count:0,start:clock()};
        if(clock()-limit.start>60000){limit.count=0;limit.start=clock();}limit.count++;rates.set(ip,limit);
        if(limit.count>10) throw [429,'Pairing rate limited'];
        if(clock()>codeUntil||!code||body.code!==code) throw [403,'Code invalid or expired'];
        if(pending.size>=8) throw [429,'Too many pending requests'];
        const key=token(),id=randomBytes(6).toString('hex');
        const s={id,name:String(body.name||'Browser').slice(0,40),permission:'read',approved:false,player:'shell-01',prefs:preferences(),expires:clock()+8*3600000,seen:clock(),csrf:token()};
        sessions.set(key,s);pending.set(id,{id,name:s.name,token:key,expires:clock()+120000});
        return send(202,{id,csrf:s.csrf},{'Set-Cookie':`velum=${key}; HttpOnly; SameSite=Strict; Path=/; Max-Age=28800${tls?'; Secure':''}`});
      }
      const key=(req.headers.cookie||'').split(';').map(v=>v.trim()).find(v=>v.startsWith('velum='))?.slice(6);
      const s=sessions.get(key);
      if(!s||s.expires<clock()) throw [401,'Pair this device'];
      s.seen=clock();
      if(!s.approved) {
        const p=pending.get(s.id);if(!p||p.expires<clock()){sessions.delete(key);pending.delete(s.id);throw [401,'Approval expired'];}
        if(url.pathname==='/api/state') return send(202,{pending:true});
        throw [403,'Waiting for explicit approval in game'];
      }
      if(req.method==='POST'&&!hashEqual(req.headers['x-velum-csrf'],s.csrf)) throw [403,'CSRF check failed'];
      switch(url.pathname) {
        case '/api/state': {
          const ms=history(s),read=reads.get(s.player)||{};
          return send(200,{state,gameOnline:clock()-gameSeen<3000,device:publicDevice(s),csrf:s.csrf,preferences:s.prefs,messages:ms,reads:read,unread:ms.filter(m=>m.sender!==s.player&&m.id>(read[m.channel==='direct'?`direct:${m.sender}`:m.channel]||0)).length,players:[...players.keys()],services:Object.fromEntries(Object.entries(services).map(([k,v])=>[k,v.snapshot()]))});
        }
        case '/api/control': {
          if(req.method!=='POST') throw [405,'POST required'];
          if(s.permission!=='control') throw [403,'Read-only device'];
          if(!['panel','probe','mount'].includes(body.action)) throw [400,'Unsupported control'];
          if(clock()-gameSeen>=3000) throw [409,'Game offline'];
          if(clock()-(s.lastControl??-Infinity)<150) throw [429,'Control rate limited'];
          if(commands.some(c=>c.device!==s.id&&clock()-c.at<750)) throw [409,'Another device owns a 750ms control lease'];
          const value=Number(body.value||0);if(!Number.isFinite(value)) throw [400,'Invalid value'];
          if(commands.length>=100) throw [429,'Queue full'];s.lastControl=clock();
          commands.push({id:++commandId,device:s.id,action:body.action,value,at:clock()});return send(200,{queued:commandId});
        }
        case '/api/chat':
          if(req.method!=='POST') throw [405,'POST required'];
          if(s.permission!=='control') throw [403,'Read-only device'];
          return send(200,record(s,body));
        case '/api/read': {
          if(req.method!=='POST') throw [405,'POST required'];
          const r=reads.get(s.player)||{};
          for(const m of history(s)) {const ch=m.channel==='direct'?`direct:${m.sender===s.player?m.to:m.sender}`:m.channel;r[ch]=Math.max(r[ch]||0,m.id);}
          reads.set(s.player,r);return send(200,{ok:true});
        }
        case '/api/preferences':
          if(req.method!=='POST') throw [405,'POST required'];
          for(const k of ['dnd','preview','sound','popups']) if(typeof body[k]==='boolean') s.prefs[k]=body[k];
          for(const k of ['muted','blocked']) if(Array.isArray(body[k])) s.prefs[k]=body[k].filter(v=>typeof v==='string').slice(0,50);
          return send(200,{ok:true});
        case '/api/report':
          if(req.method!=='POST') throw [405,'POST required'];
          if(!history(s).some(m=>m.id===Number(body.id))) throw [404,'Message unavailable'];
          reports.push({id:Number(body.id),reason:String(body.reason||'').slice(0,300),at:clock()});
          return send(200,{status:'stored in volatile local memory only; no moderation backend'});
        case '/api/test-player':
          if(req.method!=='POST'||s.permission!=='control') throw [403,'Control permission required'];
          // Explicit second native-chat actor, not a second playable multiplayer world.
          s.player='observer-'+s.id;players.set(s.player,{party:body.party==='other'?'other':'hatch',x:Number(body.x)||0,z:Number(body.z)||0});
          return send(200,{player:s.player});
        case '/api/service': {
          if(req.method!=='POST'||s.permission!=='control')throw [403,'Control permission required'];
          const adapter=services[body.service];if(!adapter)throw [400,'Unknown service'];
          if(body.action==='connect')return send(200,adapter.connect());
          if(body.action==='disconnect')return send(200,adapter.disconnect());
          if(body.action==='simulate')return send(200,adapter.emit());
          throw [400,'Only labeled mock actions are available'];
        }
        case '/api/disconnect':
          if(req.method!=='POST') throw [405,'POST required'];
          sessions.delete(key);return send(200,{ok:true},{'Set-Cookie':`velum=; HttpOnly; SameSite=Strict; Path=/; Max-Age=0${tls?'; Secure':''}`});
        default: throw [404,'Unknown route'];
      }
    } catch(e) {const [status,message]=Array.isArray(e)?e:[500,'Internal error'];send(status,{error:message});}
  }
  const hostSession={player:'shell-01',prefs:preferences()};
  return {handler,hostKey};
}

if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url)) {
  mkdirSync(path.join(root,'runtime'),{recursive:true});
  const key=token();
  const app=createLink({hostKey:key});
  http.createServer(app.handler).listen(8787,'127.0.0.1',()=>{
    writeFileSync(path.join(root,'runtime','host.key'),key,{mode:0o600});
    console.log('VELUM LINK: http://127.0.0.1:8787 • approve devices inside the game');
  });
  // LAN is intentionally TLS-only. Supply your own trusted cert; no account credentials required.
  const cert=path.join(root,'runtime','tls-cert.pem'),priv=path.join(root,'runtime','tls-key.pem');
  if(existsSync(cert)&&existsSync(priv)) {
    https.createServer({cert:readFileSync(cert),key:readFileSync(priv)},app.handler).listen(8788,'0.0.0.0',()=>console.log('VELUM LINK: HTTPS LAN enabled on port 8788'));
  } else console.log('LAN disabled: put trusted TLS certificate/key in runtime to enable HTTPS on 8788.');
}
