import {test} from 'node:test';
import assert from 'node:assert/strict';
import http from 'node:http';
import {createLink} from '../server.mjs';

test('LINK security, routing and two simultaneous clients',async t=>{
 let now=1000000;
 const app=createLink({hostKey:'test-host-key',clock:()=>now});
 const server=http.createServer(app.handler);await new Promise(r=>server.listen(0,'127.0.0.1',r));
 t.after(()=>server.close());const base=`http://127.0.0.1:${server.address().port}`;
 async function request(route,body,client=null,extra={}){
  const headers={...extra};if(body)headers['Content-Type']='application/json';
  if(route.startsWith('host/'))headers.Authorization='Bearer test-host-key';
  if(client){headers.Cookie=client.cookie;headers['X-Velum-CSRF']=client.csrf;}
  const res=await fetch(base+'/'+route,{method:body?'POST':'GET',headers,body:body?JSON.stringify(body):undefined});
  return {status:res.status,data:await res.json(),cookie:res.headers.get('set-cookie')};
 }
 const host=(route,b={})=>request('host/'+route,b);
 const sync=()=>host('state',{x:0,z:0,energy:85,ack:0});
 const code=async()=>{await host('code');return (await sync()).data.code;};
 async function pair(name,permission='control'){
  const res=await request('api/pair',{name,code:await code()});
  assert.equal(res.status,202);const c={id:res.data.id,csrf:res.data.csrf,cookie:res.cookie.split(';')[0]};
  await host('approve',{id:c.id,permission});return c;
 }
 await t.test('unpaired access denied',async()=>assert.equal((await request('api/state')).status,401));
 await t.test('origin attack denied',async()=>assert.equal((await request('api/pair',{code:'000000'},null,{Origin:'https://evil.example'})).status,403));
 let a,b;
 await t.test('approval is mandatory and code expires',async()=>{
  const valid=await code();const p=await request('api/pair',{name:'Pending',code:valid});
  const c={cookie:p.cookie.split(';')[0],csrf:p.data.csrf};
  assert.equal((await request('api/state',null,c)).status,202);
  assert.equal((await request('api/control',{action:'mount'},c)).status,403);
  now+=121000;assert.equal((await request('api/pair',{code:valid})).status,403);
  assert.equal((await request('api/state',null,c)).status,401);
 });
 await t.test('two independent sessions and read-only enforcement',async()=>{
  a=await pair('Laptop','read');b=await pair('Tablet');
  assert.equal((await request('api/state',null,a)).status,200);
  assert.equal((await request('api/state',null,b)).status,200);
  assert.equal((await request('api/control',{action:'mount'},a)).status,403);
  assert.equal((await request('api/chat',{channel:'global',text:'Denied'},a)).status,403);
 });
 await t.test('CSRF denied even for approved control session',async()=>{
  assert.equal((await request('api/control',{action:'mount'},{...b,csrf:'wrong'})).status,403);
 });
 await t.test('control lease arbitration and acknowledgement',async()=>{
  await host('approve',{id:'invalid'}); // Must not alter approved devices.
  const c=await pair('Second controller');await sync();
  assert.equal((await request('api/control',{action:'probe',value:0.2},b)).status,200);
  assert.equal((await request('api/control',{action:'mount'},c)).status,409);
  const commands=(await sync()).data.commands;assert.equal(commands.length,1);
  assert.equal((await host('state',{ack:commands[0].id})).data.commands.length,0);
  now+=900;await sync();assert.equal((await request('api/control',{action:'mount'},c)).status,200);
 });
 await t.test('global delivery, reconnect without duplicate history',async()=>{
  const result=await host('chat',{channel:'global',text:'Shell signal'});assert.equal(result.status,200);
  const first=(await request('api/state',null,a)).data.messages;
  const second=(await request('api/state',null,a)).data.messages;
  assert.deepEqual(first,second);assert.equal(new Set(second.map(m=>m.id)).size,second.length);
 });
 let observer;
 await t.test('two-client chat actor and private conversation isolation',async()=>{
  observer=(await request('api/test-player',{party:'other',x:90,z:90},b)).data.player;
  now+=1000;await host('chat',{channel:'direct',to:observer,text:'Private to observer'});
  const c=await pair('Unrelated actor');await request('api/test-player',{},c);
  assert((await request('api/state',null,b)).data.messages.some(m=>m.text==='Private to observer'));
  assert(!(await request('api/state',null,c)).data.messages.some(m=>m.text==='Private to observer'));
 });
 await t.test('party and proximity isolation',async()=>{
  now+=1000;await host('chat',{channel:'party',text:'Hatch party only'});
  now+=1000;await host('chat',{channel:'local',text:'Near shell only'});
  const ms=(await request('api/state',null,b)).data.messages;
  assert(!ms.some(m=>m.text==='Hatch party only'));assert(!ms.some(m=>m.text==='Near shell only'));
 });
 await t.test('unread state synchronizes across paired devices',async()=>{
  now+=1000;await request('api/chat',{channel:'global',text:'Observer to shell'},b);
  assert((await request('api/state',null,a)).data.unread>0);
  await request('api/read',{},a);
  const c=await pair('Same player');assert.equal((await request('api/state',null,c)).data.unread,0);
 });
 await t.test('per-device privacy preferences and block',async()=>{
  await request('api/preferences',{dnd:true,preview:false,muted:[observer],blocked:[observer]},a);
  const va=(await request('api/state',null,a)).data,vb=(await request('api/state',null,b)).data;
  assert(va.preferences.dnd);assert(!vb.preferences.dnd);
  assert(!va.messages.some(m=>m.sender===observer));
 });
 await t.test('report is explicitly local and rate limiting works',async()=>{
  const ms=(await request('api/state',null,b)).data.messages;
  const v=await request('api/report',{id:ms[0].id,reason:'Test'},b);assert.match(v.data.status,/no moderation backend/);
  now+=1000;await request('api/chat',{channel:'global',text:'one'},b);
  assert.equal((await request('api/chat',{channel:'global',text:'two'},b)).status,429);
 });
 await t.test('offline control rejected; state stays readable',async()=>{
  now+=4000;assert.equal((await request('api/control',{action:'mount'},b)).status,409);
  assert.equal((await request('api/state',null,b)).data.gameOnline,false);
 });
 await t.test('revocation immediately rejects existing cookie',async()=>{
  await host('revoke',{id:b.id});assert.equal((await request('api/state',null,b)).status,401);
 });
 await t.test('external mock events remain distinct and never enter native chat',async()=>{
  const c=await pair('Service test');
  const before=(await request('api/state',null,c)).data.messages.length;
  for(const service of ['twitch','discord']){
   assert.equal((await request('api/service',{service,action:'connect'},c)).data.mode,'mock');
   const event=(await request('api/service',{service,action:'simulate'},c)).data;
   assert.equal(event.mode,'MOCK');assert.equal(event.service.toLowerCase(),service);
   await request('api/service',{service,action:'disconnect'},c);
  }
  const after=(await request('api/state',null,c)).data;
  assert.equal(after.messages.length,before);assert.equal(after.services.twitch.connected,false);assert.equal(after.services.discord.events.length,0);
 });
 await t.test('session expires after eight hours',async()=>{
  now+=8*3600000+1;assert.equal((await request('api/state',null,a)).status,401);
 });
});
