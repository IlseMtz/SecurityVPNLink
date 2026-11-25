# Migraciones y recuperación — VS31-R02

Procedimiento de revisión pendiente de concretar con los scripts del backend. No hay migraciones SQL en este repositorio ni se ha realizado una restauración durante esta preparación.

1. Identificar MySQL, esquema, versión del backend y última migración aplicada. Obtener scripts oficiales y checksum.
2. Crear respaldo manual de DB y configuración en almacenamiento protegido y restringido. Mantener credenciales fuera de Git y de la línea de comandos. Registrar fecha, identificador y checksum sin publicar datos privados.
3. Restaurar primero en instancia aislada sin conexión al agente de producción ni rutas a la VPN real.
4. Comparar identidades (usuarios, roles, grupos), dispositivos, IP únicas, operaciones y revocaciones antes/después. No recrear identidades para simplificar una migración.
5. Ejecutar scripts revisados en orden. No asumir rollback transaccional de todo DDL de MySQL; definir recuperación por paso.
6. Ante fallo detener escrituras y preservar registros. Restaurar DB/configuración en aislamiento y reconciliar todas las revocaciones posteriores al respaldo antes de permitir tráfico. Un respaldo antiguo nunca debe reactivar dispositivos revocados después de crearlo.
7. Verificar revocados bloqueados tras reinicio y documentar resultados antes de recuperar servicio.

Completar con infraestructura: esquema, comandos reales de respaldo/restauración, scripts/versiones, rutas protegidas y resultados. Los JSON de evidencia se llenan después de ejecutar, no con resultados esperados. La prueba documental solo comprueba presencia de temas.
