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
for(const ruta of ['/api/v1/administracion/servidores','/api/v1/redes/3/../../admin','/api/v1/dispositivos','/api/v1/redes/3/eliminacion']) {
 test('rechaza ruta fuera del alcance '+ruta,async()=>{
  const w=crearWorker({enviar:async()=>{throw new Error('No debe reenviar');}});
  const r=await w.fetch(new Request('https://frontend.test'+ruta));assert.equal(r.status,404);
 });
}
test('otro origen no puede usar el proxy para el login',async()=>{
 const w=crearWorker();const r=await w.fetch(new Request('https://frontend.test/api/v1/auth/login',{method:'POST',headers:{Origin:'https://otro.test'}}));assert.equal(r.status,403);
});
test('VS-8 reenvía cuenta propia solo con los métodos del contrato', async () => {
  const rutas = [
    ['POST', '/auth/login'], ['POST', '/auth/registro'], ['POST', '/auth/logout'],
    ['GET', '/usuarios/me'], ['POST', '/usuarios/me/perfil'],
    ['POST', '/usuarios/me/contrasena'],
  ];
  const llamadas = [];
  const worker = crearWorker({enviar: async (url, opciones) => {
    llamadas.push([opciones.method, new URL(url).pathname]);
    return new Response(null, {status: 204});
  }});
  for (const [method, ruta] of rutas) {
    const url = 'https://frontend.test/api/v1' + ruta;
    assert.equal((await worker.fetch(new Request(url, {method}))).status, 204);
    const otro = method === 'GET' ? 'POST' : 'GET';
    assert.equal((await worker.fetch(new Request(url, {method: otro}))).status, 404);
  }
  assert.deepEqual(llamadas, rutas.map(([method, ruta]) => [method, '/api/v1' + ruta]));
});
test('VS-17 usa las rutas y métodos exactos desde el origen local', async () => {
  const origen = 'http://127.0.0.1:8765';
  const rutas = [
    ['GET', '/administracion/recursos'], ['POST', '/administracion/recursos'],
    ['POST', '/administracion/recursos/1'], ['GET', '/redes/2/recursos'],
    ['POST', '/redes/2/recursos/concesiones'],
    ['POST', '/redes/2/recursos/1/usuarios/3/retiro'],
  ];
  const llamadas = [];
  const worker = crearWorker({enviar: async (url, opciones) => {
    assert.equal(opciones.headers.get('Authorization'), 'Bearer FICTICIO');
    assert.equal(opciones.headers.get('Origin'), null);
    llamadas.push([opciones.method, url]);
    return new Response(null, {status: 204});
  }});
  for (const [method, ruta] of rutas) {
    const url = origen + '/api/v1' + ruta;
    const headers = {Origin: origen, Authorization: 'Bearer FICTICIO'};
    assert.equal((await worker.fetch(new Request(url, {method, headers}))).status, 204);
    assert.equal((await worker.fetch(new Request(url, {method: 'DELETE', headers}))).status, 404);
  }
  assert.equal((await worker.fetch(new Request(origen + '/api/v1/redes/2/recursos/desconocida'))).status, 404);
  assert.deepEqual(llamadas, rutas.map(([method, ruta]) => [method, 'https://nero.northcentralus.cloudapp.azure.com/api/v1' + ruta]));
});
test('VS-39 reenvía únicamente las rutas y métodos administrativos acordados', async () => {
  const uuid = '01234567-89ab-4def-8123-0123456789ab';
  const posts = ['edicion', 'suspension', 'reactivacion', 'eliminacion',
    'dispositivos/20/edicion', 'miembros/2/retiro'];
  const calls = [];
  const worker = crearWorker({enviar: async (url, opciones) => {
    calls.push([new URL(url).pathname, opciones.method, opciones.headers.get('Authorization')]);
    return Response.json({});
  }});
  const request = (ruta, method) => new Request(`https://frontend.test/api/v1/redes/10/${ruta}`, {
    method, headers: {Authorization: 'Bearer ficticio'},
  });
  for (const ruta of posts) {
    assert.equal((await worker.fetch(request(ruta, 'POST'))).status, 200);
    assert.equal((await worker.fetch(request(ruta, 'GET'))).status, 404);
  }
  const operacion = `operaciones-administrativas/${uuid}`;
  assert.equal((await worker.fetch(request(operacion, 'GET'))).status, 200);
  assert.equal((await worker.fetch(request(operacion, 'POST'))).status, 404);
  assert.equal((await worker.fetch(request('operaciones-administrativas/incorrecto', 'GET'))).status, 404);
  assert.deepEqual(calls, [...posts.map(ruta => [`/api/v1/redes/10/${ruta}`, 'POST', 'Bearer ficticio']),
    [`/api/v1/redes/10/${operacion}`, 'GET', 'Bearer ficticio']]);
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
for(const [method,path] of [['POST','/api/v1/administracion/usuarios'],['POST','/api/v1/auditoria'],['GET','/api/v1/administracion/usuarios/2/estado'],['DELETE','/api/v1/administracion/usuarios/2'],['GET','/api/v1/administracion/usuarios/2/roles']]) {
 test(`bloquea método o ruta no necesarios: ${method} ${path}`,async()=>{
  const w=crearWorker({enviar:async()=>{throw Error('No reenviar');}});
  assert.equal((await w.fetch(new Request('https://frontend.test'+path,{method}))).status,404);
 });
}
