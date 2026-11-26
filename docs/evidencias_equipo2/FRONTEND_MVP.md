# Frontend MVP: revocación, cuentas y auditoría

Base: main, commit 0614115. Cambios preparados sobre una copia separada del repositorio; no se publicó el sitio ni se envió código a GitHub.

## Qué incluye

- VS15: revocar un dispositivo propio, confirmar/cancelar, mostrar pendiente/error/aplicada y consultar cada 3 segundos hasta un máximo de 20 consultas. Se puede actualizar manualmente después. Al cerrar se cancelan temporizadores. Se bloquea la entrega de configuración cuando el perfil tiene revocación deseada o aplicada; no se reemite el mismo perfil.
- VS15: administrar cuentas con ADMINISTRACION_GLOBAL. Listado paginado, detalle, suspensión con confirmación, seguimiento de retirada de perfiles y reactivación únicamente después de retiradaCompleta=true. No permite autosuspensión desde el panel. El servidor conserva la última palabra sobre roles y último administrador.
- VS24: auditoría global con AUDITORIA_LEER, auditoría de red para su propietario, filtros enviados al servidor, paginación, limpiar filtros, estados vacíos/carga/error. Usuario es el ID de actor; fechas de calendario interpretadas en UTC con el día final incluido hasta 23:59:59.999. No se renderizan campos extra de la respuesta.
- VS31: ampliación mínima de rutas del Worker para conectar estos flujos, preservando host fijo, Bearer, bloqueo de origen distinto, ausencia de cookies, no seguimiento de redirecciones y no-store.
- VS18: retirada la referencia al laboratorio en las pantallas. Los casos originales se conservan, sin alterar asserts, en test/diferidas/equipo2/vs18_recurso.dart; no se ejecutan por descubrimiento normal de *_test.dart. No se cambió el firewall.

Los permisos de menú se leen del array de códigos `permisos` devuelto para la cuenta autenticada. Si no contiene el código requerido, no se muestra la función. La propiedad de red no equivale a administración global. El backend autoriza cada petición independientemente de la interfaz.

## Rutas de la colección Postman V6 utilizadas

| Función | Método y ruta relativa a /api/v1 |
| --- | --- |
| Cuentas | GET /administracion/usuarios?page=0&size=20 |
| Detalle | GET /administracion/usuarios/{id} |
| Suspender/reactivar | POST /administracion/usuarios/{id}/estado; body estado=SUSPENDIDO o ACTIVO |
| Retirada de cuenta | GET /administracion/usuarios/{id}/accesos-vpn |
| Revocación | POST /redes/{redId}/dispositivos/{id}/revocacion |
| Operación | GET /redes/{redId}/operaciones-vpn/{uuid} |
| Auditoría global | GET /auditoria |
| Auditoría por red | GET /redes/{redId}/auditoria |

Auditoría admite page, size, usuarioId, desde y hasta. Estos últimos estaban desactivados en Params de Postman; sí están documentados. La búsqueda deja de limitarse a filtrar los primeros 20 eventos en memoria.

## Aplicar el paquete

Guarda o confirma tus modificaciones locales antes de integrar. Comprueba la base con `git log -1 --oneline`. Si otros compañeros cambiaron estos archivos después de 0614115, revisa CAMBIOS.patch para fusionar y no sobreescribir su trabajo.

Copia las carpetas lib, hosting, test y docs de este paquete sobre la raíz del proyecto. El archivo antiguo `test/tdd_rojo/equipo2/vs18_recurso_test.dart` se debe mover fuera del descubrimiento de pruebas; el paquete ya incluye su copia intacta en `test/diferidas/equipo2/vs18_recurso.dart`. Retira únicamente el archivo antiguo después de comprobar que está la copia diferida.

Alternativa para una base limpia idéntica: `git apply --check CAMBIOS.patch` y después `git apply CAMBIOS.patch` (en lugar de copiar archivos). El patch incluye el traslado de VS18.

## Verificar en Windows/PowerShell

```powershell
flutter pub get
flutter test test/frontend_mvp_test.dart --concurrency=1 --reporter expanded
flutter test test/sesion7_regresion_equipo2_test.dart --concurrency=1 --reporter expanded
flutter --% test test/tdd_rojo/equipo2 --concurrency=1 --reporter expanded --name "VS15-(R01|R02|C01|C02)|VS24-(R01|R02|C01|C02|C03)|VS31-(R01|R02|C01)"
flutter analyze --no-fatal-infos
node --test hosting/test_worker.mjs
flutter run -d chrome
```

La tercera prueba sigue siendo un subconjunto (12 casos) y no demuestra aceptación real. La suite completa incluye casos que necesitan registros de integración. No se fabricaron esos registros ni se marcaron como aprobados.

Este entorno no ejecutó Flutter porque su arranque fue bloqueado anteriormente por revisión automática debido a un intento de acceso a metadatos de nube. Se revisó la sintaxis de los archivos Dart con un parser independiente (no sustituye compilación ni análisis de tipos). Las 20 pruebas Node del intermediario sí se ejecutaron y pasaron. Las 8 pruebas nuevas de Dart están preparadas, pendientes de ejecutar en el equipo del desarrollador.

## Uso del panel

1. Inicia sesión. Para la propia red, abre un dispositivo → Revocar dispositivo → confirma. Observa PENDIENTE, EN_PROCESO o el resultado que devuelve el servidor. Si tarda o falla, no se afirma bloqueo efectivo. Si falla la consulta, usa Actualizar operación; si la operación termina FALLIDA/CANCELADA, existe reintento confirmado.
2. Con permiso administrativo, abre Administrar cuentas, selecciona otra cuenta y suspéndela. El estado de la cuenta y retiradaCompleta se muestran por separado. Usa Actualizar cuenta y retirada para recargar desde persistencia. Reactivar no restaura dispositivos revocados.
3. Con permiso de auditoría abre Auditoría global; como propietario puedes abrir Consultar auditoría de esta red. Escribe ID de usuario, Desde/Hasta, aplica filtros y navega entre páginas. Limpiar filtros vuelve a la primera página.
4. Sin esos permisos no aparecen las acciones administrativas. Un 403 se muestra sin conservar resultados del listado. El backend decide autorización en cada solicitud.

## Despliegue e integración real pendientes

El repositorio no contiene los servicios del backend/agente ni el Caddyfile de Azure. Tampoco hay contratos HTTP para ejecutar respaldo/restauración desde el frontend. VS31 requiere esos procedimientos protegidos en el servidor y sus evidencias; no se agregaron botones ficticios de respaldo ni se habilitaron comandos remotos.

Correr Flutter local puede encontrar la restricción CORS ya documentada. Para publicar en el sitio existente, seguir tool/preparar_web.ps1 y el README del repositorio, incluyendo el Worker actualizado. Un push a GitHub no despliega el sitio. Se conserva el project_id actual.

Antes de aceptar: comprobar con cuentas de laboratorio la suspensión y cascada, la revocación real en hasta 10 s, el aislamiento entre redes y la persistencia al reiniciar; respaldar/restaurar en aislamiento sin reactivar revocados. Se necesita una nueva sesión después de cambios de permisos. No se ejecutaron estas acciones contra Azure durante la preparación.
