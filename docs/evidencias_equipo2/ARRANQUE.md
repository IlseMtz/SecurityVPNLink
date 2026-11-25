# Arranque — VS31-R01

Guía parcial basada en este repositorio; pendiente de completar con infraestructura. No acredita un despliegue realizado.

## Frontend
Desde la raíz con Flutter/Dart compatibles con pubspec.yaml:

```powershell
flutter pub get
flutter test test/tdd_rojo/equipo2 --concurrency=1 --reporter expanded
flutter run -d chrome
```

La suite incluye verificaciones que fallan sin evidencia real. El empaquetado oficial está en `tool/preparar_web.ps1`; conserva `hosting/.openai/hosting.json`. La URL se configura con SECURELINK_API_URL. El README advierte que el backend restringe CORS; ejecutar localmente no garantiza integración HTTP.

## Backend
API documentada: https://nero.northcentralus.cloudapp.azure.com/api/v1. La colección Postman proporciona contratos HTTP, no el ejecutable ni sus servicios de arranque. Obtener repositorio/versión, requisitos, variables sin secretos y comando exacto del responsable. Verificar login, identidad y rechazo de accesos entre usuarios con cuentas de laboratorio.

## Agente
Falta su fuente y unidad de servicio. Obtener comando de arranque, identidad del proceso y canal autorizado backend-agente. Al iniciar debe reconciliar revocaciones actuales y no reactivar peers desde respaldos antiguos. Registrar retirada real del peer y comprobación de tráfico.

## MySQL
Confirmar versión y esquema con infraestructura. Respaldar primero; aplicar scripts oficiales revisados y verificar identidades, relaciones y unicidad de IP. Este repositorio no contiene migraciones SQL ni una instancia local reproducible.

## Caddy
El repositorio incluye el Worker del sitio actual, no el Caddyfile. Obtener y validar el archivo existente, TLS y origen permitido. Mantener MySQL y el agente fuera de exposición pública. No reemplazar el sitio existente para hacer pasar las pruebas.

## Orden de integración
1. Revisar versiones y respaldo; iniciar MySQL y verificar migraciones.
2. Iniciar el agente y reconciliar revocaciones; iniciar backend y verificar sus dependencias.
3. Validar Caddy existente y servir frontend con origen autorizado.
4. Verificar roles, alta, emisión, permisos, revocación y reinicio con evidencia sin secretos.

Pendiente: anexar comandos reales, rutas de configuración y versiones de backend/agente/MySQL/Caddy. La prueba original solo verifica secciones; no prueba que estos pasos se hayan ejecutado.
