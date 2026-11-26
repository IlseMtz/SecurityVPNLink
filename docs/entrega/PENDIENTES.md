# Evidencias pendientes de VS-35

Responsable y piloto: Ricardo Almada. Copiloto: Jaime López.

## Qué significa flujo funcional

Es la ejecución comprobada de la secuencia: alta de dispositivo → generación e importación de configuración → conexión WireGuard → acceso al recurso permitido → revocación y bloqueo del acceso. Un diagrama describe el proceso; las evidencias demuestran que se ejecutó.

Para cada paso guardar una captura o un video que permita identificar la versión, fecha, dispositivo y resultado, ocultando claves, JWT, contraseñas y el contenido del QR o perfil. Una operación APLICADA no demuestra por sí sola conexión o acceso.

- Alta: dispositivo asociado al usuario activo, con nombre y SO.
- Configuración: operación aplicada e importación en el cliente.
- Conexión: túnel activo en el cliente y prueba de tráfico al laboratorio.
- Permiso: acceso permitido al recurso para el usuario autorizado y rechazado para quien no tiene concesión.
- Revocación: ejecución desde el panel y comprobación desde el cliente de que el tráfico queda bloqueado.

## Plataformas

Registrar por separado Windows 11, Android e iPhone: versión del sistema, fecha, persona que realizó la prueba, importación del perfil, conectividad y referencia a la evidencia. Abrir solamente la página web no acredita el uso de WireGuard en esa plataforma.

## Aceptación humana

El revisor registra su nombre, fecha, versión revisada, limitaciones, pendientes y decisión de aceptar o aceptar con condiciones. La ejecución de estas pruebas automatizadas no sustituye su decisión.

## Cómo completar los registros

Las plantillas de ejemplo se retiraron del proyecto y se conservaron en el respaldo de limpieza. Crear estos registros únicamente con información y referencias reales:

- flujo_funcional.json: objetos alta, configuracion, conexion, permisoRecurso y revocacion. Cada uno requiere resultado, evidencia, fecha y ejecutor; APROBADO solo después de comprobar el paso.
- plataformas.json: objetos Windows 11, Android e iPhone. Cada uno requiere resultado, versionSistema, evidencia y ejecutor.
- aceptacion.json: version, limitaciones (lista), pendientes (lista), revisor, fecha, evidencia y decision. La decisión puede ser ACEPTADO o ACEPTADO_CON_CONDICIONES; esta última requiere condiciones no vacías, emitidas por el revisor.

Los tres registros siguen pendientes. No basta con crear archivos o declarar resultados para demostrar que se realizaron las comprobaciones.

Ya existe evidencia técnica parcial de Azure y de la publicación web del 22/11/2026 en los entregables de esta conversación; no acredita por sí sola el flujo físico completo ni las tres plataformas.


