# VS-17 Recursos internos y horarios

La extensión añade un catálogo para administradores globales y concesiones directas para miembros de una red, gestionadas por su propietario. La regla exige que la cuenta, membresía, red, dispositivo y perfil VPN estén habilitados. MySQL guarda las concesiones y audita las modificaciones. El agente de Azure comprueba que la clave pública corresponda a la IP aplicada en `wg0` y actualiza una lista con caducidad en el firewall. El filtro comprueba origen, destino, protocolo y puerto en cada paquete, incluidas las respuestas de conexiones existentes. Cambiar rutas en el cliente no reemplaza los permisos del servidor.

El único segmento de recursos de esta versión es `172.30.77.0/24` en `br-sl-lab`. El recurso inicial es `172.30.77.10 TCP/80`. La lista se renueva cada segundo y una autorización dura hasta cinco segundos desde que el backend tomó la política. Los intervalos incluyen el inicio y excluyen el fin, admiten cruzar medianoche y usan zona IANA. Horas iguales representan 24 h desde la hora inicial en los días habilitados. Cambiar destino o desactivar un recurso elimina sus concesiones. Tras retirar y volver a incorporar un miembro hay que conceder el acceso otra vez.

## Instalación en Azure

Requiere el backend y agente V6 ya instalados, `wg0`, Docker con cadena `DOCKER-USER`, `ipset` y acceso SSH administrativo. Desde la VM verifica `ip -4 route`, `docker network ls` y la configuración de ZeroTier. El puente de esta extensión toma una ruta más específica dentro del rango anterior de ZeroTier `172.30.0.0/16`. Confirma que ninguna máquina de ZeroTier use `172.30.77.0/24` antes de crear el puente. Si existe un conflicto, acuerda con el equipo un segmento alternativo y ajusta concertadamente SQL, firewall, agente y formulario antes del despliegue.

1. Copia esta carpeta a la VM. Instala `ipset` con el gestor de paquetes de Ubuntu.
2. En `lab`, configura `SL17_LAB_IMAGE` con el digest de la imagen Nginx aprobada para su arquitectura y ejecuta `sudo --preserve-env=SL17_LAB_IMAGE docker compose up -d`. No publiques el puerto en la interfaz pública. El host debe poder consultar `http://172.30.77.10/`.
3. En esta carpeta ejecuta `bash instalar.sh` como `Nero`. El script guarda un respaldo protegido bajo `/root`, compila con las fuentes reales, aplica V7 y añade los componentes VS-17. Si falla, revisa la etapa y el respaldo impreso antes de repetir. El ejecutable anterior en memoria sigue atendiendo hasta que se reinicia el backend.
4. Compila y publica Flutter con el procedimiento del repositorio. El catálogo aparece en el panel de administración y el control de concesiones en las redes propias.

Para revertir, deja expirar las autorizaciones, conserva el bloqueo predeterminado, recupera `agent.py` y el JAR identificados en el respaldo y retira únicamente el drop-in `vs17-resources.conf`. Restaura las fuentes desde su respaldo. La migración V7 es aditiva y se puede conservar para retomar el despliegue. Evita restaurar MySQL sobre datos de producción sin planificar la recuperación.

## Contrato HTTP

| Método y ruta relativa a `/api/v1` | Acceso | Resultado |
|---|---|---|
| `GET /administracion/recursos` | Administrador global | Catálogo con `id`, `nombre`, `direccion`, `protocolo`, `puerto`, `activo` |
| `POST /administracion/recursos` | Administrador global | Crea un recurso y audita el cambio |
| `POST /administracion/recursos/{id}` | Administrador global | Edita o desactiva y audita |
| `GET /redes/{red}/recursos` | Propietario | `recursos`, `concesiones`, `agenteDisponible` |
| `POST /redes/{red}/recursos/concesiones` | Propietario | Concede o reemplaza el horario, registra auditoría |
| `POST /redes/{red}/recursos/{recurso}/usuarios/{usuario}/retiro` | Propietario | Retira una concesión y registra auditoría si existía |

Ejemplo de catálogo: `{"nombre":"Laboratorio HTTP","direccion":"172.30.77.10","protocolo":"TCP","puerto":80,"activo":true}`.

Ejemplo de concesión: `{"recursoId":1,"usuarioId":2,"dias":31,"inicio":"09:00:00","fin":"18:00:00","zona":"America/Mexico_City"}`. `dias` es una máscara con lunes en el primer bit y domingo en el séptimo. `31` selecciona lunes a viernes. Una respuesta HTTP exitosa confirma persistencia. `agenteDisponible` reporta una sincronización reciente y debe complementarse con la prueba de tráfico.

El archivo `SecureLink_VS17.postman_collection.json` se importa adicionalmente a la colección V6. Usa las variables del entorno Azure y define `accessToken` en la colección nueva o en su entorno local.

## Aceptación con tráfico real

Usa dos dispositivos autorizados en WireGuard con usuarios distintos, una red activa y el laboratorio levantado. Guarda evidencia sin tokens, QR ni claves.

1. Confirma que ambos dispositivos pierden acceso al laboratorio cuando carecen de una concesión. Concede `TCP/80` a uno y comprueba que solo ese equipo alcanza `http://172.30.77.10/`. Prueba intentos a otro destino o puerto del laboratorio y una ruta más amplia en el cliente de prueba.
2. Retira la concesión desde Flutter y mide desde la respuesta hasta el primer acceso bloqueado con el agente disponible. Comprueba bloqueo dentro de 10 s, incluso con una conexión abierta, y registra la entrada `RECURSO_RETIRADO` en auditoría.
3. Configura una ventana corta válida y verifica el inicio y el cierre. Reinicia el agente y repite la consulta antes y fuera del horario. Repite tras suspender o retirar una membresía. Comprueba que se mantiene la navegación IPv4 y el aislamiento de las redes.
4. Adjunta las evidencias de destino, aislamiento y retirada que consume `test/tdd_rojo/equipo2/vs18_recurso_test.dart`. Usa resultados obtenidos de la VM y los clientes reales.
