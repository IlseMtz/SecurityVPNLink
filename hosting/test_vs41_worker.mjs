import fs from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
const source=fs.readFileSync(new URL('./worker.mjs',import.meta.url),'utf8')
  .replace("import { assets, engineRevision } from './assets.generated.mjs';", "const assets={}; const engineRevision='test';");
const {crearWorker}=await import('data:text/javascript;base64,'+Buffer.from(source).toString('base64'));
const routes=[['POST','usuarios'],['GET','usuarios'],['GET','administracion/usuarios'],
 ['GET','administracion/usuarios/7'],['POST','administracion/usuarios/7/perfil'],
 ['POST','administracion/usuarios/7/estado'],['GET','administracion/usuarios/7/accesos-vpn'],
 ['POST','administracion/usuarios/7/roles'],['GET','administracion/permisos'],
 ['GET','administracion/roles'],['GET','administracion/roles/5'],['POST','administracion/roles'],
 ['POST','administracion/roles/5/edicion'],['POST','administracion/roles/5/eliminacion'],
 ['POST','administracion/grupos'],['GET','administracion/grupos'],['GET','administracion/grupos/9'],
 ['POST','administracion/grupos/9/edicion'],['POST','administracion/grupos/9/eliminacion'],
 ['GET','administracion/grupos/9/miembros'],['POST','administracion/grupos/9/miembros/7/alta'],
 ['POST','administracion/grupos/9/miembros/7/retiro']];
for(const [method,path] of routes) test(`VS41 contrato ${method} ${path}`,async()=>{
 let seen;
 const w=crearWorker({enviar:async(url,opts)=>{seen={url,opts};return new Response(null,{status:204});}});
 const r=await w.fetch(new Request('https://frontend.test/api/v1/'+path+'?page=1&size=20',
  {method,headers:{Authorization:'Bearer SINTETICO','Content-Type':'application/json'},
   ...(method==='POST'?{body:'{"version":4}'}:{})}));
 assert.equal(r.status,204);assert.equal(seen.opts.method,method);
 assert.equal(seen.opts.headers.get('Authorization'),'Bearer SINTETICO');
 assert.equal(new URL(seen.url).pathname,'/api/v1/'+path);
 assert.equal(new URL(seen.url).searchParams.get('page'),'1');
 if(method==='POST') assert.equal(await new Response(seen.opts.body).text(),'{"version":4}');
});
for(const [method,path] of [['GET','administracion/roles/5/eliminacion'],['POST','administracion/permisos'],
 ['DELETE','administracion/grupos/9'],['POST','administracion/grupos/9/miembros'],
 ['GET','administracion/grupos/9/miembros/7/alta'],['POST','administracion/usuarios/0/estado'],
 ['POST','administracion/grupos/9/redes/7/alta']]) test(`VS41 rechaza ${method} ${path}`,async()=>{
 let calls=0;const w=crearWorker({enviar:async()=>{calls++;return Response.json({});}});
 assert.equal((await w.fetch(new Request('https://frontend.test/api/v1/'+path,{method}))).status,404);
 assert.equal(calls,0);
});
test('VS41 conserva 409 del backend sin convertirlo en éxito',async()=>{
 const w=crearWorker({enviar:async()=>Response.json({error:'CONFLICTO'},{status:409})});
 const r=await w.fetch(new Request('https://frontend.test/api/v1/administracion/roles/5/edicion',{method:'POST'}));
 assert.equal(r.status,409);assert.deepEqual(await r.json(),{error:'CONFLICTO'});
});
