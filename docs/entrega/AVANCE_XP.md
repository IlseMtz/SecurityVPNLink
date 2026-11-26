# Avance XP de VS-35 — 25/11/2026

Historia: demostrar y entregar el MVP de SecureLink. Responsable y piloto asignado: Ricardo Almada. Copiloto asignado: Jaime López.

## Reorganización del entregable

Se centralizó la identificación de la versión web en version.json y se documentaron instalación, uso, respaldo y cambio de Endpoint en GUIA.md. PENDIENTES.md conserva las verificaciones que requieren evidencia real. Se retiraron del proyecto tres plantillas de ejemplo que no utilizaban las pruebas y se archivaron las copias antiguas del avance con un respaldo verificable.

Esto es una reorganización de documentación y del material de entrega. No se modificó la lógica de la aplicación ni se afirma una refactorización de código funcional durante esta limpieza. Las aserciones de las cinco pruebas VS-35 se conservan; los nombres identifican el piloto y el copiloto asignados.

## Validación y límites

VS35-R01 y VS35-R02 están aprobadas por la versión identificada y la guía entregada. VS35-R03, R04 y R05 continúan pendientes por falta de evidencia del flujo físico completo, Windows 11/Android/iPhone y aceptación del revisor. Las capturas disponibles acreditan registro e importación en Windows, y documentan un intento TCP fallido. La causa universitaria es una restricción reportada, no una causa técnica demostrada solo por esas capturas.

No se modifica el resultado de las pruebas para hacer pasar una entrega incompleta. El avance sigue siendo 2 de 5 comprobaciones aprobadas. No se despliega ni se cambia el estado de Jira mediante esta limpieza.

## Roles y rotación

En este ciclo se asignó Ricardo Almada como piloto y responsable de VS-35, y Jaime López como copiloto. Las actividades previstas para el piloto son organizar los documentos, ejecutar las comprobaciones y registrar evidencias; el copiloto debe revisar la correspondencia con los criterios, la claridad de la guía y la ausencia de secretos en las capturas.

Para el siguiente ciclo se propone intercambiar: Jaime López como piloto y Ricardo Almada como copiloto, al realizar las pruebas de conectividad y revisar los registros pendientes. El cambio debe anotarse con fecha, actividad y resultado cuando se efectúe.

No se dispone de un registro que acredite un intercambio efectivo de roles ya realizado. Esta asignación no atribuye commits, reuniones ni ejecución humana previa. La preparación de archivos y ejecución automatizada de esta sesión fue asistida por Codex.

## Texto breve para el reporte

“En VS-35 se reorganizó el material de entrega, conservando la identificación de versión, la guía y los pendientes. Se retiraron plantillas sin uso y se respaldaron las copias anteriores. Dos comprobaciones están aprobadas y tres continúan pendientes de evidencia real. Se asignó a Ricardo Almada como piloto y a Jaime López como copiloto; para el siguiente ciclo se propone intercambiar los roles y registrar la rotación cuando se realice.”

