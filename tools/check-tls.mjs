import https from 'node:https';
import {readFileSync} from 'node:fs';
import assert from 'node:assert/strict';
const ca=readFileSync(new URL('../runtime/tls-cert.pem',import.meta.url));
await new Promise((resolve,reject)=>{
 https.get({hostname:'127.0.0.1',port:8788,path:'/',ca},res=>{
  if(!res.socket.authorized||res.statusCode!==200){reject(Error('TLS authorization failed'));return;}
  res.resume();res.on('end',()=>{console.log('VELUM_TLS_PASS trusted supplied certificate, hostname verified, HTTP 200');resolve();});
 }).on('error',reject);
});
const key=readFileSync(new URL('../runtime/host.key',import.meta.url),'utf8').trim();
const post=(route,body)=>new Promise((resolve,reject)=>{
 const req=https.request({hostname:'127.0.0.1',port:8788,path:route,ca,method:'POST',headers:{'Content-Type':'application/json',...(route.startsWith('/host/')?{Authorization:'Bearer '+key}:{})}},res=>{
  let text='';res.on('data',c=>text+=c);res.on('end',()=>resolve({status:res.statusCode,data:JSON.parse(text),cookie:res.headers['set-cookie']}));
 });req.on('error',reject);req.end(JSON.stringify(body));
});
await post('/host/code',{});
const info=await post('/host/inspect',{});
const paired=await post('/api/pair',{code:info.data.code,name:'QA-TLS-READ'});
assert.equal(paired.status,202);
assert.match(paired.cookie[0],/; Secure/);assert.match(paired.cookie[0],/HttpOnly/);assert.match(paired.cookie[0],/SameSite=Strict/);
await post('/host/revoke',{id:paired.data.id});
console.log('VELUM_TLS_COOKIE_PASS Secure, HttpOnly, SameSite=Strict; test request revoked');
