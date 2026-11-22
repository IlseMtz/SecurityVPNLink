/// VS-13: un perfil previo no confirma la aplicación de una nueva emisión.
/// Esta regla de presentación no sustituye la autorización del servidor.
bool puedeEntregarPerfil({
  required bool redActiva,
  required bool dispositivoActivo,
  required bool cuentaActiva,
  required String? estadoPerfil,
  required String? estadoOperacion,
  bool consultaEnCurso = false,
}) =>
    redActiva &&
    dispositivoActivo &&
    cuentaActiva &&
    !consultaEnCurso &&
    estadoPerfil == 'ACTIVA' &&
    (estadoOperacion == null || estadoOperacion == 'APLICADA');
