# VS-41 — Cuentas, roles, permisos y grupos

Rama: `feature/equipo2-vs41`. Base: `0be2e25` de `main` (incluye VS-8 y el avance anterior VS15/24/31).
Contrato: colección «SecureLink API completa hasta V6», peticiones 08–17 y 44–57 entregadas por el equipo.
VS18 permanece fuera del alcance. Este cambio no modifica reglas de firewall ni membresías de redes.

## Comportamiento

- El panel muestra cuentas si la sesión tiene ADMINISTRACION_GLOBAL, USUARIOS_LEER o USUARIOS_GESTIONAR. Las acciones se separan: USUARIOS_GESTIONAR permite alta; USUARIOS_LEER permite el listado inicial; ADMINISTRACION_GLOBAL permite consulta administrativa, edición, estado y roles.
- Alta: POST /usuarios con nombre, correo y contraseña inicial; no envía un rol arbitrario. El backend crea USUARIO_VPN. La contraseña solo vive en el formulario.
- Listado inicial: GET /usuarios (array); listado global: GET /administracion/usuarios (Page). Ambos paginan desde cero.
- Perfil administrado: editar nombre/correo invalida sesiones por contrato. Si se edita la cuenta actual, la sesión local se limpia y se regresa al acceso.
- Suspensión/baja: estado de cuenta y retirada VPN se muestran por separado; un 202 no se presenta como bloqueo aplicado. Se consulta retirada cada 3 s hasta 20 intentos y se permite consulta manual. Reactivar exige SUSPENDIDO y retiradaCompleta=true. DADO_DE_BAJA no ofrece recuperación. No se ofrece autodesactivación.
- Roles: catálogo, detalle, creación, edición por versión vigente y eliminación mediante POST. Roles de sistema o con protección desconocida son de solo lectura. ADMINISTRACION_GLOBAL no aparece entre permisos asignables. Ante versión incompatible, el formulario exige cerrarse y consultar de nuevo.
- Asignación: carga todas las páginas de roles (límite defensivo de 100 páginas; falla explícitamente si se supera), conserva selección actual y exige 1–10 IDs distintos. Reemplaza todas las asignaciones, con confirmación de invalidación de sesiones. Para la cuenta propia limpia sesión local.
- Grupos: altas, listado, detalle, edición/reactivación con versión, desactivación con historial. Integrantes paginados. Para agregar se consulta la cuenta por ID y se confirma nombre/correo. Grupo inactivo no permite altas. Retirar solo llama la ruta administrativa de asociación.
- Permisos: se actualiza el perfil antes de entrar a administración y al regresar; el backend vuelve a autorizar cada solicitud. No se deducen permisos por propiedad de red.
- La protección del último ADMIN activo, eliminación de roles sin asignaciones e invalidación efectiva de JWT son responsabilidad transaccional del backend. Flutter informa el rechazo; no intenta reproducir con conteos de una página una regla global que puede cambiar concurrentemente.

## Verificación realizada aquí

- 51 pruebas Node aprobadas: intermediario existente y nuevas rutas V6, métodos rechazados, Bearer, cuerpos, paginación y conservación de respuesta 409.
- Sintaxis de Dart revisada con parser. Esto NO es compilación ni análisis de tipos.
- Flutter no está disponible en este entorno: las pruebas Dart añadidas están pendientes de ejecución. No se declara VS-41 terminada, ni ciclo TDD rojo/verde demostrado.
- No se realizaron operaciones contra Azure ni se usaron cuentas o JWT reales.

## Ejecutar en el equipo de desarrollo

Desde la raíz del proyecto, después de copiar los archivos:

```powershell
flutter pub get
flutter test test/vs41_administracion_test.dart --concurrency=1 --reporter expanded
flutter test test/frontend_mvp_test.dart test/sesion7_regresion_equipo2_test.dart test/vs8_cuenta_test.dart --concurrency=1 --reporter expanded
flutter analyze --no-fatal-infos
node --test hosting/test_worker.mjs hosting/test_vs41_worker.mjs
```

No interpretar `flutter test` sin selección como validación exclusiva de VS41: existen pruebas históricas rojas y VS18 diferida que esta rama no cambia.

## Demostración real pendiente para VS-35 / VS-7

| Escenario | Evidencia esperada |
| --- | --- |
| Usuario sin permisos / lector / gestor / ADMIN | Acciones visibles correspondientes; backend rechaza acceso directo no autorizado. |
| Alta y listado | 201; cuenta nueva con USUARIO_VPN; array inicial y Page global, siguiente/anterior. |
| Editar perfil / reemplazar roles | 200; un JWT anterior de la cuenta objetivo es rechazado; nuevo login refleja permisos; cuenta propia regresa al acceso. |
| Último ADMIN activo | Backend rechaza suspensión, baja o retirada de ADMIN; cuenta y asignaciones se conservan. Usar entorno aislado. |
| Suspensión o baja con retirada pendiente | 202/pendiente visible; después estado persistido confirma retirada; comprobar tráfico real y tiempo conforme a VS15. |
| Reactivación | Pendiente no permite reactivar; completada permite cuenta suspendida sin resucitar peers; baja definitiva siempre rechazada. |
| Rol de sistema / permiso reservado | UI no permite editar sistema ni asignar reservado a personalizado; backend también rechaza peticiones manipuladas. |
| Rol personalizado | Alta y edición con permisos válidos; conflicto entre dos sesiones devuelve 409; rol asignado no se elimina; libre sí. |
| Grupos | Crear, paginar, consultar, editar, desactivar conservando historial y reactivar con versión vigente. |
| Integrantes | Alta solo en activo, duplicado no duplica, paginación y retiro; comparar membresías de redes antes/después, sin cambios. |

Registrar commit desplegado, rol de prueba, fecha, resultado esperado/obtenido y captura sin contraseñas/JWT. Coordinar el bloque de grupos con Equipo 1 antes de fusionar; no se ha enviado ningún mensaje al equipo desde aquí.

## Integración y PR

No hay merge ni publicación de esta rama desde este entorno. La conexión GitHub previamente devolvió 403 al escribir. Se entrega ZIP con los archivos modificados y parche para revisión. Validar localmente, subir únicamente la rama VS41 y abrir PR hacia main; el equipo realiza el merge.
