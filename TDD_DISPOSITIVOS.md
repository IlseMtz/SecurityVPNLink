# Dispositivos asociados a usuarios activos — fase roja de TDD

## Entrega

- `lib/dispositivos.dart`: contrato de dominio, repositorios y servicio pendiente.
- `test/dispositivos_test.dart`: 43 casos de comportamiento con `flutter_test`.
- No se implementa la funcionalidad: ambos métodos del servicio lanzan `UnimplementedError`.
- Los dobles en memoria sustituyen almacenamiento y auditoría; no validan permisos ni campos.
- No se cambia el inicio de sesión, las pantallas, el pubspec ni la prueba anterior del contador.

## Decisiones propuestas para precisar los criterios

Estos puntos son supuestos de esta suite, no requisitos adicionales confirmados:

1. Campos de alta: `usuarioId`, `nombre`, `tipo`, `identificador`, todos obligatorios y no compuestos solo por espacios. El servicio genera un ID no vacío y único.
2. Tipos permitidos: `laptop`, `escritorio`, `movil`, `tablet`.
3. Se recortan espacios del nombre e identificador; este último se almacena en minúsculas. Su unicidad es global, incluso entre usuarios distintos. No se presupone que sea una MAC o un IMEI.
4. El actor debe existir y estar `ACTIVO`. El ID del actor representa una identidad ya autenticada por la capa de acceso; no debe tomarse libremente de un formulario. La autenticación real queda fuera de esta suite.
5. `Administrador` puede registrar y consultar dispositivos de cualquier usuario activo. `Soporte` puede consultar. `Usuario VPN` puede consultar únicamente sus dispositivos. Un actor sin rol no tiene acceso. Un ID ausente o desconocido produce `sinSesion`.
6. El propietario debe existir y estar `ACTIVO` tanto al registrar como al consultar. `SUSPENDIDO` y `DADO_DE_BAJA` provocan rechazo. La consulta de un usuario activo sin dispositivos devuelve una lista vacía.
7. Cada operación exitosa o rechazada genera exactamente un evento con acción, resultado, actor, propietario y fecha. El alta exitosa incluye el ID generado; un rechazo incluye motivo y no incluye ID de dispositivo. Se conserva el `usuarioId` recibido en eventos de validación, incluso si está vacío.
8. Ante rechazo de alta no se escribe ningún dispositivo. Ante rechazo de consulta no se llama al repositorio de dispositivos. Un rechazo no elimina registros anteriores.

## Cobertura: 43 pruebas

- Registro válido: 8 casos. Cuatro tipos admitidos, normalización, IDs únicos en altas consecutivas, consulta posterior al alta y auditoría exitosa.
- Validación de campos: 11 casos. Cuatro campos vacíos y con espacios, tipo desconocido y duplicados del mismo o de otro propietario; verifican rechazo, ausencia de alta y auditoría.
- Propietario: 6 casos. Registro y consulta para usuario inexistente, suspendido o dado de baja; verifican auditoría y ausencia de efectos.
- Permisos de registro: 6 casos. Sin sesión, actor desconocido, administrador inactivo, soporte, usuario VPN y actor sin rol.
- Consulta válida: 5 casos. Administrador, soporte y propietario consultan únicamente los dispositivos solicitados; lista vacía; revocación del estado activo después de una consulta permitida.
- Permisos y campos de consulta: 7 casos. Sin sesión, actor desconocido, administrador inactivo, acceso a dispositivos ajenos, actor sin rol y propietario vacío o con espacios.

## Ejecutar la fase roja

Desde PowerShell, una vez instalado Flutter y configurado el PATH:

```powershell
cd C:\Users\ricar\SecurityVPNLink
flutter --version
flutter pub get
flutter test test/dispositivos_test.dart --reporter expanded
```

El proyecto exige Dart `>=3.13.7 <4.0.0`. Flutter debe incluir una versión compatible antes de resolver dependencias.

**Resultado esperado, pendiente de verificar:** 43 pruebas fallidas por `UnimplementedError`, con código de salida distinto de cero. Los casos negativos esperan `ExcepcionDispositivos` con un motivo concreto, por lo que el stub también debe hacerlos fallar. No se usan aserciones artificiales como `expect(false, true)`.

La suite debe compilar antes de considerar válida la fase roja: errores de imports, resolución de dependencias o sintaxis son bloqueos del entorno o del armazón, no evidencia de un comportamiento faltante.

En esta sesión no se encontró `flutter` ni `dart` en el PATH. No se pudo ejecutar la suite ni confirmar su compilación. Consultar `VALIDACION.txt` para el intento de ejecución.

## Pasar a verde

Implementar únicamente `ServicioDispositivos.registrar` y `consultar`, usando los repositorios inyectados y `ahora()` para las fechas. Resolver la identidad y sus roles desde `obtenerUsuario`, validar el propietario y campos, comprobar duplicados, persistir y emitir auditoría. Dejar que cada prueba indique el comportamiento pendiente. Ejecutar la suite después de cada cambio y refactorizar cuando esté verde.

La consistencia ante fallos de almacenamiento/auditoría, concurrencia de altas duplicadas, persistencia real y controles de interfaz/API necesitan pruebas adicionales cuando se decida la infraestructura. Esta suite cubre el comportamiento del servicio con dobles en memoria.

Para ejecutar todo el proyecto después:

```powershell
flutter analyze
flutter test
```

La prueba existente `test/widget_test.dart` es todavía la del contador inicial y no corresponde al login actual; puede fallar por un motivo ajeno a dispositivos. Por eso el comando de fase roja selecciona explícitamente el archivo nuevo.
