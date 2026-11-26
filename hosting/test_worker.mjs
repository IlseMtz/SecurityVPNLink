import fs from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
const fuente=fs.readFileSync(new URL('./worker.mjs',import.meta.url),'utf8')
 .replace("import { assets, engineRevision } from './assets.generated.mjs';","const assets={}; const engineRevision='revision';");
const {crearWorker}=await import('data:text/javascript;base64,'+Buffer.from(fuente).toString('base64'));
test('proxy fija host Azure, conserva Bearer y no envía cookies',async()=>{
 let vista;
 const w=crearWorker({enviar:async(url,op)=>{vista={url,op};return new Response('{"ok":true}',{headers:{'content-type':'application/json','set-cookie':'secreto'}});}});
 const r=await w.fetch(new Request('https://frontend.test/api/v1/redes/3/dispositivos',{headers:{Authorization:'Bearer FICTICIO',Cookie:'no-reenviar'}}));
 assert.equal(vista.url,'https://nero.northcentralus.cloudapp.azure.com/api/v1/redes/3/dispositivos');
 assert.equal(vista.op.headers.get('Authorization'),'Bearer FICTICIO');assert.equal(vista.op.headers.get('Cookie'),null);
 assert.equal(r.headers.get('set-cookie'),null);assert.match(r.headers.get('cache-control'),/no-store/);
});
for(const ruta of ['/api/v1/administracion/roles','/api/v1/redes/3/../../admin','/api/v1/dispositivos','/api/v1/redes/3/eliminacion']) {
 test('rechaza ruta fuera del alcance '+ruta,async()=>{
  const w=crearWorker({enviar:async()=>{throw new Error('No debe reenviar');}});
  const r=await w.fetch(new Request('https://frontend.test'+ruta));assert.equal(r.status,404);
 });
}
test('otro origen no puede usar el proxy para el login',async()=>{
 const w=crearWorker();const r=await w.fetch(new Request('https://frontend.test/api/v1/auth/login',{method:'POST',headers:{Origin:'https://otro.test'}}));assert.equal(r.status,403);
});
test('no sigue redirecciones ni expone Location con tokens',async()=>{
 const w=crearWorker({enviar:async(_,op)=>{assert.equal(op.redirect,'manual');return new Response(null,{status:302,headers:{Location:'https://otro.test'}});}});
 const r=await w.fetch(new Request('https://frontend.test/api/v1/usuarios/me'));assert.equal(r.status,302);assert.equal(r.headers.get('location'),null);
});
test('PNG y archivo se conservan binarios sin caché',async()=>{
 const bytes=new Uint8Array([137,80,78,71,13,10,26,10]);
 const w=crearWorker({enviar:async()=>new Response(bytes,{headers:{'content-type':'image/png'}})});
 const r=await w.fetch(new Request('https://frontend.test/api/v1/redes/3/dispositivos/6/configuracion/qr?endpoint=public'));
 assert.deepEqual(new Uint8Array(await r.arrayBuffer()),bytes);assert.equal(r.headers.get('content-type'),'image/png');assert.match(r.headers.get('cache-control'),/no-store/);
});
test('error de conexión no refleja detalles de infraestructura o secretos',async()=>{
 const w=crearWorker({enviar:async()=>{throw new Error('NO MOSTRAR SECRETO');}});
 const r=await w.fetch(new Request('https://frontend.test/api/v1/redes'));assert.equal(r.status,502);assert.doesNotMatch(await r.text(),/SECRETO/);
});
test('sirve estáticos sin auth embebida y redirige solo recursos públicos del motor',async()=>{
 const w=crearWorker({assetsLocales:{'/index.html':{type:'text/html',data:Buffer.from('SecureLink').toString('base64')}}});
 assert.equal(await (await w.fetch(new Request('https://frontend.test/'))).text(),'SecureLink');
 const r=await w.fetch(new Request('https://frontend.test/canvaskit/canvaskit.wasm'));
 assert.equal(r.headers.get('location'),'https://www.gstatic.com/flutter-canvaskit/revision/canvaskit.wasm');
});

for (const [method,path] of [['GET','/api/v1/auditoria'],['GET','/api/v1/administracion/usuarios'],['GET','/api/v1/administracion/usuarios/2'],['GET','/api/v1/administracion/usuarios/2/accesos-vpn'],['POST','/api/v1/administracion/usuarios/2/estado']]) {
 test(`VS15/24 reenvía ${method} ${path} con autorización`, async()=>{
  let seen;
  const w=crearWorker({enviar:async(url,op)=>{seen={url,op};return Response.json({});}});
  const r=await w.fetch(new Request('https://frontend.test'+path+'?page=2&usuarioId=4',{method,headers:{Authorization:'Bearer FICTICIO','Content-Type':'application/json'},...(method==='POST'?{body:'{"estado":"SUSPENDIDO"}'}:{})}));
  assert.equal(r.status,200);assert.equal(seen.op.headers.get('Authorization'),'Bearer FICTICIO');
  assert.equal(new URL(seen.url).searchParams.get('usuarioId'),'4');
 });
}
for(const [method,path] of [['POST','/api/v1/administracion/usuarios'],['POST','/api/v1/auditoria'],['GET','/api/v1/administracion/usuarios/2/estado'],['DELETE','/api/v1/administracion/usuarios/2'],['POST','/api/v1/administracion/usuarios/2/roles']]) {
 test(`bloquea método o ruta no necesarios: ${method} ${path}`,async()=>{
  const w=crearWorker({enviar:async()=>{throw Error('No reenviar');}});
  assert.equal((await w.fetch(new Request('https://frontend.test'+path,{method}))).status,404);
 });
}
