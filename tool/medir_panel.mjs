import { performance } from 'node:perf_hooks';

const [destino, muestrasTexto = '40', concurrenciaTexto = '4'] = process.argv.slice(2);
const muestras = Number(muestrasTexto);
const concurrencia = Number(concurrenciaTexto);
const url = destino && URL.canParse(destino) ? new URL(destino) : null;
if (!url || !['http:', 'https:'].includes(url.protocol) || url.username || url.password ||
    !Number.isInteger(muestras) || muestras < 1 || muestras > 1000 ||
    !Number.isInteger(concurrencia) || concurrencia < 1 || concurrencia > Math.min(20, muestras)) {
  console.error('Uso: node tool/medir_panel.mjs <URL de laboratorio> [muestras 1-1000] [concurrencia 1-20]');
  process.exit(2);
}

const precisiones = [];
const errores = new Map();
let porIniciar = muestras;

async function medir() {
  while (porIniciar > 0) {
    porIniciar--;
    const inicio = performance.now();
    try {
      const respuesta = await fetch(url, {
        redirect: 'error',
        signal: AbortSignal.timeout(10000),
      });
      await respuesta.arrayBuffer();
      if (respuesta.ok) {
        precisiones.push(performance.now() - inicio);
      } else {
        const codigo = String(respuesta.status);
        errores.set(codigo, (errores.get(codigo) ?? 0) + 1);
      }
    } catch {
      errores.set('red_o_timeout', (errores.get('red_o_timeout') ?? 0) + 1);
    }
  }
}

await Promise.all(Array.from({ length: concurrencia }, medir));
precisiones.sort((a, b) => a - b);
const p95 = precisiones.length ? precisiones[Math.ceil(precisiones.length * 0.95) - 1] : null;
console.log(JSON.stringify({
  fechaUTC: new Date().toISOString(),
  muestras,
  concurrencia,
  exitosas: precisiones.length,
  errores: Object.fromEntries(errores),
  p95Ms: p95 === null ? null : Math.round(p95),
}, null, 2));
process.exitCode = precisiones.length === muestras && p95 <= 2000 ? 0 : 1;
