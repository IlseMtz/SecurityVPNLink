import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:securelink_app/reporte_auditoria.dart';

void main() {
  test('el CSV protege fórmulas y omite campos ajenos a la auditoría', () {
    final csv = utf8.decode(csvAuditoria([
      {
        'usuarioId': 7,
        'accion': '  =2+2',
        'resultado': 'Dijo "ok",\nsegunda línea',
        'detalle': 'SECRETO',
        'accessToken': 'TOKEN',
      },
    ]));
    expect(csv, contains('"7","\'  =2+2"'));
    expect(csv, contains('"Dijo ""ok"",\nsegunda línea"'));
    expect(csv, isNot(contains('SECRETO')));
    expect(csv, isNot(contains('TOKEN')));
  });
}
