import 'usuarios_page.dart';

// Contrato provisional para la fase ROJA. Sin reglas de negocio implementadas.
class Dispositivo {
  const Dispositivo({
    required this.id,
    required this.usuarioId,
    required this.nombre,
    required this.tipo,
    required this.identificador,
  });

  final String id;
  final String usuarioId;
  final String nombre;
  final String tipo;
  final String identificador;
}

enum MotivoRechazo {
  sinSesion,
  actorInactivo,
  sinPermiso,
  usuarioNoExiste,
  usuarioInactivo,
  campoObligatorio,
  tipoInvalido,
  identificadorDuplicado,
}

class ExcepcionDispositivos implements Exception {
  const ExcepcionDispositivos(this.motivo);
  final MotivoRechazo motivo;

  @override
  String toString() => 'ExcepcionDispositivos: ${motivo.name}';
}

enum AccionDispositivo { registrar, consultar }
enum ResultadoAuditoria { exito, rechazo }

class EventoDispositivo {
  const EventoDispositivo({
    required this.accion,
    required this.resultado,
    required this.actorId,
    required this.usuarioId,
    required this.fecha,
    this.dispositivoId,
    this.motivo,
  });

  final AccionDispositivo accion;
  final ResultadoAuditoria resultado;
  final String? actorId;
  final String usuarioId;
  final DateTime fecha;
  final String? dispositivoId;
  final MotivoRechazo? motivo;
}

abstract class RepositorioDispositivos {
  Future<UsuarioDemo?> obtenerUsuario(String id);
  Future<List<Dispositivo>> consultarPorUsuario(String usuarioId);
  Future<Dispositivo?> buscarPorIdentificador(String identificador);
  Future<void> guardar(Dispositivo dispositivo);
}

abstract class AuditoriaDispositivos {
  Future<void> registrar(EventoDispositivo evento);
}

class ServicioDispositivos {
  ServicioDispositivos({
    required this.repositorio,
    required this.auditoria,
    required this.ahora,
  });

  final RepositorioDispositivos repositorio;
  final AuditoriaDispositivos auditoria;
  final DateTime Function() ahora;

  Future<Dispositivo> registrar({
    required String? actorId,
    required String usuarioId,
    required String nombre,
    required String tipo,
    required String identificador,
  }) async {
    throw UnimplementedError('TDD ROJO: implementar registro de dispositivos');
  }

  Future<List<Dispositivo>> consultar({
    required String? actorId,
    required String usuarioId,
  }) async {
    throw UnimplementedError('TDD ROJO: implementar consulta de dispositivos');
  }
}
