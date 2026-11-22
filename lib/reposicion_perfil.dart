import 'azure_api.dart';
import 'dispositivos.dart';
import 'api_error.dart' show ExcepcionApi;

class ReposicionPendiente implements Exception {
  const ReposicionPendiente(this.operacionId, this.estado);
  final String operacionId;
  final String estado;
}

class PerfilRepuesto {
  const PerfilRepuesto(this.equipo, this.operacion);
  final EquipoAzure equipo;
  final Map<String, dynamic> operacion;
}

/// Una reposición no reutiliza el perfil revocado. Nunca se registra el equipo
/// nuevo antes de que el agente confirme APLICADA para la revocación anterior.
class ReposicionPerfil {
  ReposicionPerfil(
    this.api, {
    this.intentos = 15,
    Future<void> Function()? pausa,
  }) : pausa =
           pausa ?? (() => Future<void>.delayed(const Duration(seconds: 2)));
  final AzureApi api;
  final int intentos;
  final Future<void> Function() pausa;
  Future<PerfilRepuesto> ejecutar(
    RedAzure red,
    EquipoAzure equipo,
    CuentaAzure cuenta, {
    bool Function()? vigente,
  }) async {
    if (!red.esPropietario(cuenta)) {
      throw const ExcepcionApi(403, 'SIN_PERMISO');
    }
    if (!equipo.activo || equipo.redId != red.id) {
      throw const ExcepcionApi(409, 'ESTADO_INVALIDO');
    }
    final solicitud = await api.revocar(red.id, equipo.id);
    final id = solicitud['id'];
    if (id is! String) throw const ExcepcionApi(502, 'RESPUESTA_INVALIDA');
    Map<String, dynamic> operacion = solicitud;
    for (var i = 0; i < intentos; i++) {
      operacion = await api.operacion(red.id, id);
      final estado = operacion['estado'];
      if (estado == 'APLICADA') break;
      if (estado == 'FALLIDA' || estado == 'CANCELADA') {
        throw ReposicionPendiente(id, estado as String);
      }
      if (estado != 'PENDIENTE' && estado != 'EN_PROCESO') {
        throw const ExcepcionApi(502, 'RESPUESTA_INVALIDA');
      }
      if (i + 1 < intentos) await pausa();
    }
    if (operacion['estado'] != 'APLICADA') {
      throw ReposicionPendiente(id, '${operacion['estado']}');
    }
    if (vigente != null && !vigente()) {
      throw ReposicionPendiente(id, 'APLICADA');
    }
    final nuevo = await api.registrar(
      red.id,
      SolicitudDispositivo(
        usuarioId: '${equipo.usuarioId}',
        nombre: equipo.nombre,
        sistemaOperativo: equipo.sistemaOperativo,
      ),
    );
    final provision = await api.solicitar(red.id, nuevo.id);
    return PerfilRepuesto(nuevo, provision);
  }
}
