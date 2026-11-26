import 'dart:convert';
import 'dart:typed_data';

/// Exporta únicamente los campos públicos de auditoría que muestra el panel.
Uint8List csvAuditoria(Iterable<Map<String, dynamic>> eventos) {
  String celda(Object? valor) {
    var texto = valor?.toString() ?? '';
    // Los programas de hojas de cálculo pueden evaluar estos prefijos.
    if (RegExp(r'^[\s\uFEFF]*[=+\-@]|^[\t\r\n]').hasMatch(texto)) {
      texto = "'$texto";
    }
    return '"${texto.replaceAll('"', '""')}"';
  }

  final filas = <List<Object?>>[
    ['Fecha UTC', 'Usuario', 'Acción', 'Objeto', 'ID de objeto', 'Resultado'],
    for (final evento in eventos)
      [
        evento['fecha'] ?? evento['fechaEvento'],
        evento['usuarioId'] ?? evento['actorId'],
        evento['accion'],
        evento['objetoTipo'],
        evento['objetoId'] ?? evento['entidadId'],
        evento['resultado'],
      ],
  ];
  return Uint8List.fromList(
    utf8.encode('\uFEFF${filas.map((fila) => fila.map(celda).join(',')).join('\r\n')}\r\n'),
  );
}
