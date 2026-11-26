# VS-21 — Política de perfiles y cupos

Esta actualización parte de la entrega V6 de administración. Aplicar V8__politica_y_cupo_red.sql al esquema de laboratorio. VS-17 ya usa el número V7. Después, aplicar cupos-v6.patch seguido de modalidad-v6.patch en la raíz del código Spring. Comprobar cada parche con git apply --check antes de aplicarlo. Verificar las configuraciones y los QR generados antes de desplegar.

- GET /api/v1/redes/{redId}/limites devuelve limiteEquiposUsuario, ocupadosPorUsuario, modoTunel y version al propietario.
- POST en la misma ruta recibe limiteEquiposUsuario de 1 a 5, modoTunel FULL o SPLIT y la versión anterior de la red.
- Full usa la salida IPv4 de Azure, los DNS del perfil y la captura de IPv6 que filtra el servidor. Split envía solo la subred IPv4 de la red SecureLink. El cliente conserva sus rutas y DNS locales y su IPv6 fuera del túnel.
- El modo se guarda cuando se crea el registro de configuración. Los perfiles que ya tienen registro conservan su modalidad, también si se descargan más tarde. Las reglas del servidor siguen aislando las redes.
- El cupo cuenta los dispositivos con un cupo de red. El máximo de cinco equipos por red se conserva y la actualización y el alta toman el mismo bloqueo de fila. El límite por persona empieza en cinco también en redes existentes.
- Un límite inferior a una ocupación existente devuelve 409 LIMITE_INFERIOR_A_OCUPACION. El alta que rebasa el cupo devuelve 409 LIMITE_EQUIPOS_USUARIO. Una actualización con una versión obsoleta devuelve 409 VERSION_DESACTUALIZADA.

Verificar ambos perfiles y QR, las rutas y DNS efectivos de los clientes, el aislamiento, las descargas de perfiles existentes y dos altas concurrentes con un solo cupo libre. Quedan pendientes la validación contra el backend desplegado y la política de límites sobre actividad observada. La observación por handshake no identifica de forma exacta una sesión conectada.
