# VS-37 — Validación y entrega de SecureLink

Preparar una versión candidata con el SHA del frontend y del backend, la versión de WireGuard, la región y tamaño de la VM y la fecha UTC. Usar una instancia de pruebas autorizada y cuentas de laboratorio. Guardar las evidencias en el espacio del equipo con acceso restringido.

## Seguridad y operación

| Caso | Comprobación |
| --- | --- |
| Sesión y permisos | Comprobar inicio de sesión y expiración. Verificar que una cuenta ajena recibe 403 o 404 al consultar redes, operaciones y perfiles ajenos. |
| Intentos fallidos | Validar el umbral de la configuración desplegada con una cuenta de pruebas y registrar cuándo recupera el acceso. |
| Revocación | Con un dispositivo autorizado, comprobar tráfico antes y después de que la revocación quede aplicada. |
| HTTPS y secretos | Validar el certificado sin excepciones de confianza. Revisar que MySQL, Spring Boot y el socket del agente quedan en el alcance de red previsto, que cada servicio usa permisos mínimos y que los artefactos compartidos excluyen secretos. |

## Rendimiento

Ejecutar el medidor con Node.js 22 desde una máquina cliente del laboratorio. Conservar su salida junto con el SHA, la red de acceso y la hora UTC. El medidor registra latencia de una ruta; para el panel, repetir por operación representativa y documentar la mezcla de solicitudes. Las solicitudes fallidas se reportan por separado y hacen fallar la ejecución.

```powershell
node tool/medir_panel.mjs http://127.0.0.1:8765/ 40 4
```

| Objetivo | Método y evidencia |
| --- | --- |
| Panel ≤2 s en el 95 % de solicitudes | Medir operaciones habituales con varios administradores de prueba. Guardar p95, errores, muestra, concurrencia y origen. |
| Conexión ≤5 s | Medir desde la activación del túnel hasta el primer tráfico útil. Guardar versión de cliente y tiempos individuales. |
| Cambios ≤10 s | Medir desde el envío de un cambio hasta su efecto observable. Para una operación asíncrona, correlacionar con su UUID y comprobar el efecto. |
| 100 conexiones simultáneas | Usar pares independientes, distribuidos en las redes y cuentas necesarias. Acreditar concurrencia con tráfico de prueba en una ventana común y registrar CPU, memoria, errores y latencia. Coordinar capacidad con infraestructura antes de ejecutar. |

## Compatibilidad

Registrar resultado, versión, ejecutor y evidencia para cada fila. El recorrido del panel abarca acceso, alta de equipo, generación y descarga. El recorrido WireGuard abarca importación, conexión, tráfico y aislamiento respecto de otra red.

| Cliente | Panel | WireGuard | Estado |
| --- | --- | --- | --- |
| Windows 11 | Chrome, Edge y Firefox | Importar archivo | Pendiente de evidencia |
| Android | Navegador aprobado | Importar archivo o QR | Pendiente de evidencia |
| iPhone | Safari | Importar archivo o QR | Pendiente de evidencia |
| Windows 10 | Navegador aprobado | Importar archivo | Pendiente de evidencia o ajuste de alcance |
| Linux | Chrome o Firefox | Importar archivo | Pendiente de evidencia o ajuste de alcance |
| macOS | Navegador aprobado | Importar archivo | Pendiente de evidencia o ajuste de alcance |

## Entrega y mantenimiento

Usar [la guía de instalación, usuario, administración y recuperación](GUIA.md) y [el registro de evidencias de VS-35](PENDIENTES.md). Entregar código por SHA, configuración sin secretos e inventario de versiones. Registrar fecha de capacitación, participantes y evidencia de demostración. La persona revisora registra su decisión, defectos abiertos y condiciones. El equipo confirma responsables de operación y seguimiento mensual.

El PR prepara la validación. Las evidencias de carga, clientes físicos, capacitación y aceptación se recogen en el ambiente de pruebas.
