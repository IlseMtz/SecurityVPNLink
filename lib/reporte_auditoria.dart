import 'dart:convert';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

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

  final filas = _filasAuditoria(eventos);
  return Uint8List.fromList(
    utf8.encode(
      '\uFEFF${filas.map((fila) => fila.map(celda).join(',')).join('\r\n')}\r\n',
    ),
  );
}

List<List<Object?>> _filasAuditoria(Iterable<Map<String, dynamic>> eventos) =>
    <List<Object?>>[
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

Future<Uint8List> pdfAuditoria(Iterable<Map<String, dynamic>> eventos) {
  String texto(Object? valor) {
    final limpio = (valor?.toString() ?? '').replaceAll(
      RegExp(r'[\x00-\x1f]'),
      ' ',
    );
    return String.fromCharCodes(
      limpio.runes.take(254).map((runa) => runa <= 255 ? runa : 63),
    );
  }

  final filas = _filasAuditoria(eventos);
  final documento = pw.Document(title: 'Auditoría de SecureLink');
  documento.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      header: (_) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 12),
        child: pw.Text('SecureLink | Página de auditoría'),
      ),
      build: (_) => [
        pw.TableHelper.fromTextArray(
          headers: filas.first.map(texto).toList(),
          data: filas.skip(1).map((fila) => fila.map(texto).toList()).toList(),
          cellStyle: const pw.TextStyle(fontSize: 9),
          headerStyle: pw.TextStyle(
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
          ),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
        ),
      ],
    ),
  );
  return documento.save();
}
