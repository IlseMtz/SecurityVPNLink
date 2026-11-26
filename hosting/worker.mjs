import { assets, engineRevision } from './assets.generated.mjs';

const upstream = 'https://nero.northcentralus.cloudapp.azure.com';
const headersPrivados = {'Cache-Control':'no-store, private', 'Pragma':'no-cache',
  'X-Content-Type-Options':'nosniff', 'Referrer-Policy':'no-referrer'};

function rutaPermitida(path, method) {
  if (/^\/api\/v1\/(auth\/(login|logout|registro)|usuarios\/me\/(perfil|contrasena))$/.test(path)) return method === 'POST';
  if (path === '/api/v1/usuarios/me') return method === 'GET';
  if (/^\/api\/v1\/redes\/[1-9]\d*\/limites$/.test(path)) return ['GET','POST'].includes(method);
  // Ampliación mínima para VS15 y VS24; Azure sigue autorizando cada operación.
  if (method === 'GET' && /^\/api\/v1\/(auditoria|administracion\/usuarios(?:\/[1-9]\d*(?:\/accesos-vpn)?)?)$/.test(path)) return true;
  if (method === 'POST' && /^\/api\/v1\/administracion\/usuarios\/[1-9]\d*\/estado$/.test(path)) return true;
  return /^\/api\/v1\/redes(?:\/\d+(?:\/(miembros|auditoria|dispositivos(?:\/\d+\/(configuracion(?:\/qr)?|vpn|conexion|revocacion))?|operaciones-vpn\/[0-9a-fA-F-]{36}))?)?$/.test(path);
}

export function crearWorker({assetsLocales=assets, revision=engineRevision, enviar=fetch}={}) {
  return {async fetch(request) {
    const url=new URL(request.url);
    if(url.pathname.startsWith('/api/')) {
      if(!rutaPermitida(url.pathname, request.method) || !['GET','POST'].includes(request.method))
        return Response.json({error:'RUTA_NO_PERMITIDA'},{status:404,headers:headersPrivados});
      const origin=request.headers.get('Origin');
      if(origin && origin!==url.origin)
        return Response.json({error:'ORIGEN_NO_PERMITIDO'},{status:403,headers:headersPrivados});
      const destino=new URL(url.pathname+url.search,upstream);
      const headers=new Headers();
      for(const name of ['Accept','Content-Type','Authorization']) {
        if(request.headers.has(name))headers.set(name,request.headers.get(name));
      }
      headers.set('Cache-Control','no-store');
      try {
        const respuesta=await enviar(destino.toString(),{method:request.method,headers,
          body:request.method==='POST'?request.body:undefined,redirect:'manual',
          signal:AbortSignal.timeout(25000),duplex:'half'});
        const salida=new Headers(headersPrivados);
        for(const name of ['Content-Type','Content-Disposition','Retry-After'])
          if(respuesta.headers.has(name))salida.set(name,respuesta.headers.get(name));
        // Nunca reenviar Location ni seguir una redirección que pueda llevar el token a otro host.
        return new Response(respuesta.body,{status:respuesta.status,headers:salida});
      } catch {
        return Response.json({error:'SERVICIO_NO_DISPONIBLE'},{status:502,headers:headersPrivados});
      }
    }
    if(!['GET','HEAD'].includes(request.method))return new Response('Método no permitido',{status:405});
    let ruta=url.pathname==='/'?'/index.html':url.pathname;
    // Recursos públicos de renderizado del SDK oficial, sin cookies ni token de la aplicación.
    if(ruta.startsWith('/canvaskit/') && !ruta.includes('..'))
      return Response.redirect('https://www.gstatic.com/flutter-canvaskit/'+revision+'/'+ruta.slice('/canvaskit/'.length),302);
    const recurso=assetsLocales[ruta];
    if(!recurso)return new Response('No encontrado',{status:404});
    const cuerpo=Uint8Array.from(atob(recurso.data),c=>c.charCodeAt(0));
    return new Response(request.method==='HEAD'?null:cuerpo,{headers:{'Content-Type':recurso.type,
      'Cache-Control':'no-cache','X-Content-Type-Options':'nosniff','Referrer-Policy':'no-referrer'}});
  }};
}
export default crearWorker();
