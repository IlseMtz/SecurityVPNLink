// VS-13 | TDD RED. Contratos sin implementar para las dos clases CRC.
// No se modifica VS-12 ni se ejecutan comandos reales de WireGuard.

enum EstadoConfiguracion { pendiente, aplicada, fallida }
enum ModoConexion { splitTunnel, fullTunnel }

class DispositivoVPN {
  final String id;
  final bool autorizado;
  final bool usuarioActivo;

  const DispositivoVPN({
    required this.id,
    required this.autorizado,
    required this.usuarioActivo,
  });
}

// Modelo mínimo de datos de prueba: no contiene claves privadas reales.
class ConfiguracionVPN {
  final String dispositivoId;
  final String ip;
  final String clavePublica;
  final String endpoint;
  final ModoConexion modo;
  final List<String> rutas;
  final EstadoConfiguracion estado;

  const ConfiguracionVPN({
    required this.dispositivoId,
    required this.ip,
    required this.clavePublica,
    required this.endpoint,
    required this.modo,
    required this.rutas,
    this.estado = EstadoConfiguracion.pendiente,
  });
}

// Puerto del agente: las pruebas lo sustituyen por un doble en memoria.
abstract class AgenteConfiguracionVPN {
  bool get disponible;
  bool aplicar(ConfiguracionVPN configuracion);
}

// Contratos para los colaboradores. El asignador real pertenece a VS-12.
typedef AsignarIP = String Function(String dispositivoId);
typedef NotificarAdministrador = void Function(String mensaje);

class MonitorEstadoVPN {
  final AgenteConfiguracionVPN agente;
  final NotificarAdministrador notificar;

  MonitorEstadoVPN({required this.agente, required this.notificar});

  EstadoConfiguracion consultarEstado(ConfiguracionVPN configuracion) =>
      throw UnimplementedError('TDD ROJO: consultar estado VPN');

  EstadoConfiguracion determinarEstado(
    ConfiguracionVPN configuracion, {
    required bool? confirmacion,
  }) =>
      throw UnimplementedError('TDD ROJO: comprobar confirmacion del agente');

  bool agenteDisponible() =>
      throw UnimplementedError('TDD ROJO: comprobar disponibilidad del agente');

  bool detectarIntentoSuspendido(DispositivoVPN dispositivo) =>
      throw UnimplementedError('TDD ROJO: detectar usuario suspendido');

  void informarAgotamientoIP({required bool sinIps}) =>
      throw UnimplementedError('TDD ROJO: informar agotamiento de IP');
}

class GeneradorConfiguracionVPN {
  final AsignarIP asignarIP;
  final AgenteConfiguracionVPN agente;

  GeneradorConfiguracionVPN({required this.asignarIP, required this.agente});

  ConfiguracionVPN generar({
    required DispositivoVPN dispositivo,
    required String clavePublica,
    required String endpoint,
    required List<String> rutasLaboratorio,
  }) =>
      throw UnimplementedError('TDD ROJO: generar configuracion VPN');

  bool validar(ConfiguracionVPN configuracion) =>
      throw UnimplementedError('TDD ROJO: validar parametros VPN');

  bool entregar(ConfiguracionVPN configuracion) =>
      throw UnimplementedError('TDD ROJO: entregar configuracion al agente');
}
