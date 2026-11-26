import { createServer } from 'node:http';
import { Readable } from 'node:stream';
import { pipeline } from 'node:stream/promises';
import worker from '../build/worker-local.mjs';

const puerto = Number(process.argv[2] ?? 8765);
const origen = `http://127.0.0.1:${puerto}`;

const servidor = createServer(async (entrada, salida) => {
  if (entrada.headers.host !== `127.0.0.1:${puerto}` ||
      !entrada.url?.startsWith('/') || entrada.url.startsWith('//')) {
    salida.writeHead(400).end();
    return;
  }

  try {
    const url = new URL(origen + entrada.url);
    const opciones = { method: entrada.method, headers: entrada.headers };
    if (entrada.method !== 'GET' && entrada.method !== 'HEAD') {
      opciones.body = Readable.toWeb(entrada);
      opciones.duplex = 'half';
    }
    const respuesta = await worker.fetch(new Request(url, opciones));
    salida.writeHead(respuesta.status, Object.fromEntries(respuesta.headers));
    if (respuesta.body) await pipeline(Readable.fromWeb(respuesta.body), salida);
    else salida.end();
  } catch {
    if (salida.headersSent) salida.destroy();
    else salida.writeHead(500).end('Error del servidor local');
  }
});

servidor.listen(puerto, '127.0.0.1', () => {
  console.log(`SecureLink está disponible en ${origen}. Presiona Ctrl+C para detenerlo.`);
});
