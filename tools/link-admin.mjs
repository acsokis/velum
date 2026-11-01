// Local test harness. The host key stays on disk and is never printed.
import {readFileSync} from 'node:fs';
const key=readFileSync(new URL('../runtime/host.key',import.meta.url),'utf8').trim();
const call=async(route,body={})=>{const r=await fetch('http://127.0.0.1:8787/host/'+route,{method:'POST',headers:{Authorization:'Bearer '+key,'Content-Type':'application/json'},body:JSON.stringify(body)});if(!r.ok)throw Error('Host request failed '+r.status);return r.json();};
const action=process.argv[2];
if(action==='code'){await call('code');console.log((await call('inspect')).code);}
else if(action==='approve-tests'){
 const s=await call('inspect');
 for(const p of s.pending)if(p.name.startsWith('QA-')){await call('approve',{id:p.id,permission:p.name.includes('READ')?'read':'control'});console.log('Approved test device '+p.name);}
}else if(action==='status'){
 const s=await call('inspect');console.log(JSON.stringify({pending:s.pending,devices:s.devices}));
}else if(action==='message'){await call('chat',{channel:'global',text:'QA native message — preview privacy test'});console.log('Local QA message delivered');}
else if(action==='revoke-tests'){const s=await call('inspect');for(const d of s.devices)if(d.name.startsWith('QA-'))await call('revoke',{id:d.id});console.log('QA sessions revoked');}
else throw Error('Use code, approve-tests, revoke-tests, message or status');
