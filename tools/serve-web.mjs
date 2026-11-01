import http from 'node:http';
import {createReadStream, statSync} from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const root = fileURLToPath(new URL('../build-web/', import.meta.url));
const port = Number(process.env.VELUM_WEB_PORT || 8789);
if (!Number.isInteger(port) || port < 1024 || port > 65535) throw new Error('Invalid VELUM_WEB_PORT');
const types = {'.html':'text/html; charset=utf-8','.js':'text/javascript','.wasm':'application/wasm','.pck':'application/octet-stream','.png':'image/png','.svg':'image/svg+xml'};
http.createServer((req,res)=>{
  try {
    if(req.method !== 'GET' && req.method !== 'HEAD') {res.writeHead(405);return res.end();}
    const requestPath = decodeURIComponent(new URL(req.url,'http://localhost').pathname);
    const file = path.resolve(root,'.'+(requestPath==='/'?'/index.html':requestPath));
    if(!file.startsWith(root)) {res.writeHead(403);return res.end();}
    const stat=statSync(file);
    if(!stat.isFile()) throw new Error('Not a file');
    const isolation=requestPath.startsWith('/fast/')?{'Cross-Origin-Opener-Policy':'same-origin','Cross-Origin-Embedder-Policy':'require-corp','Cross-Origin-Resource-Policy':'same-origin'}:{};
    res.writeHead(200,{'Content-Type':types[path.extname(file)]||'application/octet-stream','Content-Length':stat.size,'X-Content-Type-Options':'nosniff','Cache-Control':'no-store',...isolation});
    if(req.method==='HEAD') return res.end();
    createReadStream(file).pipe(res);
  } catch {res.writeHead(404);res.end('Not found');}
}).listen(port,'127.0.0.1',()=>console.log(`VELUM WEB: http://127.0.0.1:${port} (game; LINK companion remains on 8787)`));
