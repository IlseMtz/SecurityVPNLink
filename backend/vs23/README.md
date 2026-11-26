# VS-23 — Auditoría por dispositivo

El parche parte del backend V6. Desde la raíz del código Spring, comprobar con git apply --check y después aplicar auditoria-dispositivo-v6.patch. Las consultas GET /api/v1/auditoria y GET /api/v1/redes/{id}/auditoria aceptan dispositivoId. El filtro aplica a los eventos persistidos cuyo objeto es el dispositivo. Los filtros de usuario y fecha siguen funcionando con el alcance y los permisos de cada ruta.

Flutter Web exporta en CSV y PDF una página de las coincidencias. Los reportes incluyen fecha, actor, acción, tipo, ID de objeto y resultado.

Para completar la historia faltan retención, persistencia de observaciones con huecos y vigencia, alertas atendibles y métricas reales de CPU, memoria, tráfico y disponibilidad mensual.
