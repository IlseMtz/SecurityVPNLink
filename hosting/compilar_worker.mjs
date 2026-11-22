import fs from 'node:fs';
import path from 'node:path';

const root=process.cwd();
const flutter=path.resolve(root,'web_build');
const assets={};
const tipos={'.html':'text/html; charset=utf-8','.js':'application/javascript; charset=utf-8',
  '.json':'application/json','.png':'image/png','.otf':'font/otf','.ttf':'font/ttf',
  '.woff2':'font/woff2','.bin':'application/octet-stream','.frag':'application/octet-stream',
  '.css':'text/css; charset=utf-8','.svg':'image/svg+xml','.wasm':'application/wasm'};
function recorrer(dir) {
  for(const item of fs.readdirSync(dir,{withFileTypes:true})) {
    const full=path.join(dir,item.name);
    const relativo=path.relative(flutter,full).split(path.sep).join('/');
    if(relativo.startsWith('canvaskit/') || relativo.endsWith('.map') || relativo==='flutter_service_worker.js')continue;
    if(item.isDirectory())recorrer(full);
    else assets['/'+relativo]={type:tipos[path.extname(full)]??'application/octet-stream',data:fs.readFileSync(full).toString('base64')};
  }
}
recorrer(flutter);
const bootstrap=fs.readFileSync(path.join(flutter,'flutter_bootstrap.js'),'utf8');
const revision=bootstrap.match(/"engineRevision"\s*:\s*"([0-9a-f]+)"/)?.[1];
if(!revision)throw new Error('No se encontró la revisión del motor Flutter.');
fs.writeFileSync('assets.generated.mjs',`export const assets=${JSON.stringify(assets)};\nexport const engineRevision=${JSON.stringify(revision)};\n`);
fs.mkdirSync('dist/server',{recursive:true});
// Un único módulo Worker ESM, sin secretos ni credenciales de revisión.
const fuente=fs.readFileSync('worker.mjs','utf8').replace("import { assets, engineRevision } from './assets.generated.mjs';",fs.readFileSync('assets.generated.mjs','utf8').replaceAll('export const ','const '));
fs.writeFileSync('dist/server/index.js',fuente);
fs.mkdirSync('dist/.openai',{recursive:true});
fs.copyFileSync('.openai/hosting.json','dist/.openai/hosting.json');
console.log(JSON.stringify({assets:Object.keys(assets).length,bytes:Buffer.byteLength(fuente)}));
