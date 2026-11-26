# SecureLink — Equipo 1

Frontend Flutter de VS-11 (entrega de configuración VPN) y VS-14 (registro y consulta de dispositivos).

Sitio actual: https://securelink-equipo1-incremento1-20261122.khakihymn8.chatgpt.site

## Para trabajar en equipo

1. El propietario del repositorio debe dar acceso de colaborador a Ricardo Almada y Jaime López en GitHub. Cada persona clona el repositorio y trabaja en su propia rama.
2. Instalar Git, Flutter con Dart compatible con `^3.13.7` y Node.js con soporte de `node --test`. Esta entrega se verificó con Flutter 3.50.0 y Dart 3.14.0. No necesitan Android Studio para compilar web.
3. Desde la carpeta del proyecto:

```powershell
git pull origin main
git switch -c feature/nombre-del-cambio
flutter pub get
flutter test --concurrency=1
flutter analyze --no-fatal-infos
node --test hosting/test_worker.mjs
```

Si la rama principal del equipo tiene otro nombre, sustituir `main`. Modificar pantallas en `lib/incremento_app.dart`, contrato HTTP en `lib/azure_api.dart` y añadir pruebas en `test/`. La sesión está en `lib/sesion_azure.dart`; la reposición de perfiles, en `lib/reposicion_perfil.dart`. `lib/dispositivos.dart` valida el formulario. `hosting/worker.mjs` protege el acceso al backend y sirve la web.

4. La pareja revisa el cambio y ejecuta las verificaciones antes de integrarlo:

```powershell
git status
git diff
git add -A
git diff --cached --stat
git commit -m "VS-14: describir el cambio realizado"
git push -u origin feature/nombre-del-cambio
```

Abrir un pull request en GitHub, solicitar revisión al compañero e integrar en la rama principal. Cada integrante utiliza su propia identidad Git. Los roles de piloto y copiloto se anotan según el trabajo real realizado; no se cambian autores de commits para simular participación.

## Preparar una nueva versión web

Desde la raíz del repositorio:

```powershell
.\tool\preparar_web.ps1
```

Si los programas no están en PATH:

```powershell
.\tool\preparar_web.ps1 -Flutter 'C:\ruta\flutter\bin\flutter.bat' -Node 'C:\ruta\node.exe'
```

El script obtiene dependencias, ejecuta las pruebas Flutter y Node, analiza y compila la web; se detiene ante errores. Copia los recursos a `hosting/web_build` y genera el Worker en `hosting/dist/server/index.js` con el manifiesto `hosting/dist/.openai/hosting.json`. Son archivos generados e ignorados por Git.

## Subir cambios al MISMO sitio

**Un push a GitHub no actualiza automáticamente este despliegue.** El repositorio GitHub y el repositorio de publicación de Sites son destinos distintos; no hay CI configurada entre ellos.

El propietario del sitio o alguien con permiso de edición en Sites debe publicar. Tener acceso al GitHub, o conocer la URL pública, no otorga ese permiso. Si el compañero no tiene acceso a Sites, integra su pull request y el propietario publica la versión revisada.

En el chat con Sites conectado, pedir:

> Actualiza el sitio existente appgprj_6b0313ccc5d081919910e30c7f9ece80 con la versión de este repositorio. Ejecuta tool/preparar_web.ps1. Conserva el project_id, la URL y la audiencia pública. Sincroniza la fuente con el repositorio de publicación, guarda una nueva versión y despliégala. No crees otro sitio.

El flujo de publicación debe abrir el repositorio fuente del sitio usando una credencial temporal de Sites, copiar la fuente revisada y los recursos de hosting, ejecutar las pruebas y el empaquetado, guardar la versión con su commit y desplegarla. En el repositorio fuente del sitio, `hosting` se publica como raíz del Worker; el código Flutter puede conservarse en `flutter_src`. Nunca copiar `.git`, credenciales, tokens, cuentas de revisión ni archivos VPN. Las credenciales de publicación se pasan temporalmente por stdin, sin guardarlas en Git.

Después comprobar la URL existente, login, consulta de dispositivos y una validación de formulario. Si falla, volver a desplegar la versión anterior del mismo sitio. No enviar una URL nueva por cada actualización.

El dominio `chatgpt.site` pertenece al alojamiento actual. Cambiar de proveedor/dominio es una tarea de infraestructura separada; editar el título de Flutter no cambia ese dominio.

## Backend y desarrollo local

Para ejecutar la aplicación web en Windows, desde la raíz del proyecto:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tool\ejecutar_web.ps1
```

Abre `http://127.0.0.1:8765` y deja la terminal abierta. El script usa Flutter desde `.tools/flutter` si existe, o desde el PATH, y requiere Node.js. Sirve la aplicación y el intermediario de Azure en la misma dirección. Para reutilizar la última compilación, agrega `-SinCompilar`. Para usar otro puerto, agrega `-Puerto 8766`. Detén el servidor con `Ctrl+C`.

Backend: https://nero.northcentralus.cloudapp.azure.com/api/v1

El contrato vigente usa `/redes/{redId}/dispositivos`, configuración, QR, operaciones VPN y auditoría. El formulario usa WINDOWS, ANDROID, IOS, LINUX o MACOS. No utiliza el antiguo POST `/dispositivos`.

Azure rechaza CORS desde orígenes nuevos, incluido localhost. `flutter run -d chrome` permite revisar la interfaz local, pero la integración HTTP requiere un origen permitido por Azure o servir la web y el Worker juntos mediante una herramienta local compatible con Workers. El script prepara la compilación con `/api/v1` del sitio publicado; no configura CORS en Azure. Para otro despliegue, usar `-ApiUrl 'https://nuevo-origen/api/v1'` y publicar el intermediario en ese mismo origen.

El Worker reenvía solo rutas permitidas al host fijo de Azure; no reenvía cookies ni sigue redirecciones. La autorización real la aplica Azure. No quitar estas restricciones para resolver un error CORS.

## Alcance y pruebas

### VS-39: administrar redes, miembros y equipos

Desde el panel, usa **Crear red** para indicar nombre y descripción. Selecciona una red propia y abre **Administrar red** para editarla, administrar miembros por ID y solicitar suspensión, reactivación o eliminación. La ventana muestra el UUID y consulta la operación cada cuatro segundos mientras esté abierta. Desde **Operación de …** puedes retomar la consulta durante la sesión, incluso si la red eliminada dejó de aparecer en el selector. En caso de `FALLIDA`, reintenta la misma solicitud. El icono de lápiz del dispositivo permite editar su nombre y sistema operativo. Si el servidor responde `VERSION_SUPERADA`, actualiza los datos antes de volver a enviar.

```powershell
.\.tools\flutter\bin\flutter.bat test test/vs39_red_test.dart --reporter expanded
node --test hosting/test_worker.mjs
```

La aceptación de Azure y WireGuard debe hacerse con cuentas y redes de prueba autorizadas. Usa una cuenta propietaria, una miembro activa y otra ajena. Conserva los UUID y códigos de respuesta como evidencia, sin incluir tokens, archivos de configuración ni QR en las capturas.

1. Crea tres redes propias y verifica que la cuarta se rechaza en Azure. Una red nueva debe comenzar `PENDIENTE` sin CIDR. Comprueba que la cuenta miembro solo vea las redes a las que pertenece. Edita una red y un equipo con su versión vigente, luego verifica `409 VERSION_SUPERADA` con la anterior. Repite la edición como miembro y comprueba el rechazo del servidor.
2. Agrega a la cuenta miembro y registra equipos hasta cinco habilitados. Comprueba en Azure el rechazo del sexto. Solicita un perfil, espera `APLICADA` en `operaciones-vpn` y confirma que la red ya tiene CIDR. Descarga el `.conf` u obtén el QR desde Flutter e impórtalo en WireGuard. Comprueba handshake, salida IPv4 por Azure y acceso permitido dentro de la red. Usa un recurso de prueba de otra red para verificar aislamiento. La cuenta ajena debe recibir un rechazo al solicitar el perfil o la consulta de operaciones.
3. Suspende y reactiva la red de prueba. Anota el UUID de cada acción y confirma `APLICADA` en `operaciones-administrativas`. Comprueba que la suspensión conserva cupos y que la reactivación solo restaura perfiles vigentes. Ante un `FALLIDA` en un entorno de pruebas, corrige la causa y reintenta la misma acción.
4. Retira al miembro de una red de prueba y verifica que sus peers de esa red se revocan y los cupos se liberan después de `APLICADA`. Comprueba que su perfil en otra red sigue vigente y que el propietario no puede retirarse a sí mismo. Por último, elimina una red de prueba y verifica la retirada de sus peers y la liberación del cupo de red al confirmarse la operación.

### VS-8: cuenta propia y autenticación

VS-8 cubre las peticiones 02–07 de la guía V6. Usa **Crear cuenta** desde el inicio de sesión y **Mi cuenta** desde la barra del panel para consultar el perfil, editar el nombre o correo y cambiar la contraseña. Las dos ediciones y el cierre de todas las sesiones requieren volver a entrar. El registro deja al usuario en el formulario de acceso. La asignación del rol `USUARIO_VPN`, la emisión del JWT y su invalidación corresponden a Azure.

Para reproducir la evidencia automatizada de VS-8 desde PowerShell:

```powershell
.\.tools\flutter\bin\flutter.bat test test/vs8_cuenta_test.dart --reporter expanded
node --test hosting/test_worker.mjs
```

Las pruebas de Flutter usan respuestas HTTP controladas de la API V6. Para la aceptación en Azure, utiliza una cuenta de prueba y dos sesiones independientes. Registra y verifica el rol, inicia sesión y comprueba `expiresIn: 3600`. Repite con credenciales inválidas. Consulta el perfil, verifica el rechazo de una contraseña actual incorrecta y confirma cada operación de invalidación por separado (edición de perfil, cambio de contraseña y logout). Tras cada operación, `GET /usuarios/me` debe devolver `401` al usar el token de la otra sesión. Registra códigos y pantallas sin capturar contraseñas ni JWT. La entrega de archivo y QR se verifica en VS-14.

Se conservan las pruebas del contrato Azure, pantallas, sesión, reposición y del intermediario. Usan dobles controlados: no demuestran por sí mismas conectividad real de WireGuard. La integración Azure y la aceptación física deben verificarse por separado. La entrega presencial requiere comprobar identidad; la importación del perfil y el acceso al laboratorio se prueban en el equipo del propietario.

La limpieza retiró pantallas demo y el contrato local anterior, junto con sus pruebas específicas. También retiró del frontend los esqueletos RED de VS-12/VS-13, que no eran usados por la aplicación. Se respaldaron fuera del repositorio: no se presentan como funcionalidades implementadas ni como pruebas convertidas a verde.

Se mantiene Android como estructura de plataforma Flutter; esta entrega está validada para web, sin APK validado. El adaptador nativo de guardado necesita implementación específica antes de ofrecer descargas nativas.

No guardar contraseñas, tokens, `.conf`, QR, entornos Postman con secretos ni datos privados de revisión en Git o en logs. Mantener `pubspec.lock`, pruebas, `analysis_options.yaml`, `.metadata`, archivos web referenciados y manifiesto de hosting: son necesarios para mantener y reproducir el proyecto.

