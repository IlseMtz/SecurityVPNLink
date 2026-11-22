/// Error HTTP saneado: no contiene tokens, claves ni cuerpos de respuesta.
class ExcepcionApi implements Exception {
  const ExcepcionApi(this.estado, this.codigo);
  final int estado;
  final String codigo;
  @override
  String toString() => 'ExcepcionApi($estado, $codigo)';
}
