# SecureLink — guía corta de la entrega web

Historia: VS-35. Versión publicada: Sites 2. Fuente: bde5660d4f0b2ce827bef822bac5832a7008d81a.

Responsable y piloto de este ciclo: Ricardo Almada. Copiloto: Jaime López. Esta asignación no cambia la autoría de commits ni acredita reuniones anteriores. Implementación y documentación asistidas por Codex.

## Instalación

### Acceso a la web

Abrir https://securelink-equipo1-incremento1-20261122.khakihymn8.chatgpt.site en el navegador con conexión a Internet. Iniciar sesión con una cuenta SecureLink activa. La portada es pública; los datos y configuraciones requieren autenticación y autorización. No se incluye ninguna contraseña o token en esta guía.

La entrega comprobada es web. No hay un APK validado. La importación de configuraciones en WireGuard y la conectividad física deben verificarse en cada equipo.

### Preparar el código para desarrollo

Instalar Git, Flutter compatible con Dart ^3.13.7 y Node.js con node --test. La compilación anterior se realizó con Flutter 3.50.0 y Dart 3.14.0. Desde la raíz del repositorio:

```powershell
flutter pub get
flutter test --concurrency=1 --reporter expanded test/tdd_rojo/vs35_entrega_test.dart
```

El ciclo de aceptación sigue devolviendo fallo mientras falten registros de conexión, permisos, revocación, plataformas o aceptación humana. El comando tool/preparar_web.ps1 verifica la suite completa y compila; debe detener la publicación si falla alguna prueba. Un push al repositorio GitHub no actualiza automáticamente el sitio de Sites.

## Uso

1. Iniciar sesión. Elegir una red de la que se sea propietario o miembro autorizado.
2. El propietario registra el nombre y sistema operativo del dispositivo, asociado a un miembro activo. Los sistemas admitidos son WINDOWS, ANDROID, IOS, LINUX y MACOS. Consultar que los datos correspondan al propietario real.
3. Abrir el dispositivo y solicitar la configuración. PENDIENTE y EN_PROCESO no acreditan aplicación; FALLIDA y CANCELADA requieren revisión. APLICADA acredita la operación del servidor, no una conexión del cliente.
4. Con perfil y red activos, abrir Entregar archivo o QR. Comprobar presencialmente la identidad del destinatario antes de confirmar. Descargar el archivo o mostrar el QR solo para esa entrega y cerrar la vista al terminar.
5. En el dispositivo del propietario, importar el archivo o escanear el QR con WireGuard y activar el túnel. El archivo y el QR contienen secretos: conservarlos únicamente en el equipo o almacén protegido del propietario.
6. Abrir el recurso de laboratorio autorizado desde ese cliente. Registrar el resultado real y comprobar también el rechazo de un usuario sin autorización.
7. Para la demostración de revocación, utilizar un dispositivo de pruebas. El administrador debe revocarlo mediante la función autorizada disponible en su entorno y comprobar desde el cliente que deja de acceder. No se certifica bloqueo por recibir un 202 o por ver APLICADA. Documentar la operación y la prueba de tráfico.

El frontend de esta versión incorpora reposición de perfil perdido: espera revocación APLICADA, registra un reemplazo y solicita su configuración. Esa acción produce un dispositivo nuevo; no sustituye la demostración de una revocación independiente exigida por VS-15. La interfaz de revocación independiente y los permisos del recurso siguen teniendo casos rojos pendientes.

### Auditoría y diagnóstico

Consultar la auditoría de la red y el estado observado del dispositivo. Un último handshake muestra una observación y no garantiza acceso al recurso ni una sesión activa. Conservar en las evidencias solo información necesaria, sin contraseñas, claves, JWT ni el contenido del perfil.

Si el servidor devuelve 401, iniciar sesión nuevamente. Con 403, revisar propiedad de la red, membresía y permisos con el administrador. Si el agente está caído o una operación sigue pendiente, consultar su estado antes de repetir un alta. No publicar ni repetir operaciones destructivas para producir una captura.

## Respaldo y recuperación

### Código y documentación

Integrar primero la versión revisada y comprobar git status. Para respaldar una versión ya confirmada en Git, desde la raíz del repositorio:

```powershell
git status --short
git rev-parse HEAD
git archive --format=zip --output=../securelink-codigo.zip HEAD
```

El ZIP contiene lo confirmado en HEAD, no cambios sin commit ni secretos externos. Guardar junto al respaldo el SHA, la versión publicada y las instrucciones de compilación. Los archivos .conf, QR, entornos privados y credenciales no se incorporan a Git.

### Base de datos y configuración del servidor

El responsable de infraestructura debe realizar el respaldo manual de MySQL y de la configuración del servicio en un destino con acceso restringido, siguiendo las credenciales y herramientas del despliegue real. Registrar versión, fecha, responsable, método de protección y ubicación protegida. El repositorio frontend no contiene las credenciales ni comandos específicos de esa VM, por lo que no se inventa aquí un procedimiento ejecutado.

Comprobar la recuperación en un entorno aislado y verificar que identidades, dispositivos y revocaciones se conservan. No apuntar esa restauración a producción. El respaldo y la restauración reales forman parte de VS-31 y siguen requiriendo sus evidencias. Para recuperar un perfil perdido sin copia protegida, el propietario utiliza la reposición autorizada; no se reutilizan claves revocadas.

## Cambio de Endpoint

El Endpoint de WireGuard es la dirección pública y puerto UDP del servidor VPN. Es distinto de la URL HTTPS de la API y del dominio del frontend.

Cuando cambie la dirección pública del laboratorio, el administrador de infraestructura verifica la nueva dirección, el puerto UDP, el DNS y las reglas de red. Actualiza el parámetro que usa su backend/agente para generar perfiles públicos, con el nombre real de configuración de su instalación. Después valida la generación de un perfil para un dispositivo de pruebas y entrega el archivo o QR actualizado por el procedimiento de identidad. El cliente vuelve a importar o actualizar el Endpoint en su perfil según el procedimiento autorizado y comprueba acceso al recurso. Registrar el resultado; cambiar solo SECURELINK_API_URL no modifica el Endpoint de WireGuard.

Para cambiar la dirección HTTPS de la API, se actualiza el destino fijo del intermediario en hosting/worker.mjs y la compilación del frontend según el README. Azure aplica CORS: una web en otro origen necesita su intermediario y configuración correspondiente. No eliminar la autenticación o las restricciones de rutas para resolverlo.

## Estado de la entrega y evidencias

Se identificó la versión web publicada y se redactó esta guía. Los registros automáticos anteriores documentan provisión APLICADA, descarga de configuración, QR y rechazo sin token. No acreditan por sí mismos conexión WireGuard del cliente, acceso real al recurso, bloqueo posterior a revocación ni pruebas físicas en Windows 11, Android e iPhone.

Para terminar VS-35 hay que adjuntar registros verificables del flujo completo, de las tres plataformas y de la aceptación de la versión por el revisor. Los responsables propuestos son Ricardo Almada como piloto y Jaime López como copiloto. La decisión de aceptación pertenece al revisor; no se da por emitida mediante este documento.

