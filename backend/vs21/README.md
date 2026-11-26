# VS-21 — Cupos por usuario

Esta actualización parte de NetworkService y ManagementController de la entrega V6 de administración. Aplicar la migración al esquema de laboratorio antes de arrancar el backend con el parche. Desde la raíz del código Spring, ejecutar primero git apply --check con el parche y aplicar solo si la revisión pasa.

- GET /api/v1/redes/{redId}/limites devuelve limiteEquiposUsuario, ocupadosPorUsuario y version al propietario.
- POST /api/v1/redes/{redId}/limites recibe limiteEquiposUsuario entre 1 y 5 y la version anterior de la red. Devuelve los límites y la nueva versión.
- El cupo por usuario cuenta dispositivos que conservan un cupo de red. El máximo de cinco equipos por red se mantiene. La revisión y el alta toman el mismo bloqueo de fila de la red.
- Las redes existentes conservan un límite de cinco. Reducir el límite por debajo de una ocupación existente devuelve 409. Un alta por encima del límite devuelve 409 LIMITE_EQUIPOS_USUARIO. Cambiar con una versión obsoleta devuelve 409 VERSION_DESACTUALIZADA.
- Validar con dos solicitudes paralelas para el mismo usuario cuando quede un cupo, con otro usuario en la misma red y con un actor ajeno. Verificar que revocar un perfil solo libera cupo cuando el flujo de baja del dispositivo efectivamente lo vacía.

Pendiente del resto de VS-21: colección Postman, selección de Split/Full por perfil nuevo, política DNS e IPv6 y límite sobre actividad de WireGuard. La actividad observada por handshake requiere una ventana definida y no equivale a una sesión. Estos cambios se verifican en otro incremento antes de cerrar la historia.
