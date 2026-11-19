// VS-12 | TDD RED: contratos iniciales sin implementar.
// Los métodos deben lanzar UnimplementedError hasta la fase GREEN.

class MigracionDispositivo {
  Map<String, Object?> migrar(Map<String, Object?> esquema) =>
      throw UnimplementedError('TDD ROJO: implementar migración');

  Map<String, Object?> revertir(Map<String, Object?> esquema) =>
      throw UnimplementedError('TDD ROJO: implementar reversión');
}

class AsignadorIP {
  AsignadorIP(List<String> disponibles);

  String asignar(String dispositivoId, {required bool autorizado}) =>
      throw UnimplementedError('TDD ROJO: implementar asignación IP');

  Map<String, String> get asignaciones =>
      throw UnimplementedError('TDD ROJO: implementar registro de IP');
}

class PersistenciaLocal {
  PersistenciaLocal(String ruta);

  void guardarPeer(String id, {required bool activo}) =>
      throw UnimplementedError('TDD ROJO: implementar guardado de peers');

  Map<String, bool> obtenerPeers() =>
      throw UnimplementedError('TDD ROJO: implementar recuperación de peers');

  void registrarOperacion(String operacion) =>
      throw UnimplementedError('TDD ROJO: implementar historial');

  List<String> obtenerOperaciones() =>
      throw UnimplementedError('TDD ROJO: recuperar historial');
}

// Contrato del adaptador. Las pruebas usan exclusivamente un doble en memoria.
abstract class AdaptadorWireGuard {
  Set<String> obtenerPeers();
  void agregarPeer(String id);
  void eliminarPeer(String id);
}

class AgenteLocal {
  AgenteLocal(AdaptadorWireGuard adaptador);

  String aplicar(String peerId, {required bool autorizado}) =>
      throw UnimplementedError('TDD ROJO: implementar aplicación autorizada');

  String revocar(String peerId, {required bool autorizado}) =>
      throw UnimplementedError('TDD ROJO: implementar revocación autorizada');

  // true = activo; false = revocado. No contiene claves reales.
  void reconciliar(Map<String, bool> estadoPersistido) =>
      throw UnimplementedError('TDD ROJO: implementar reconciliación');
}
