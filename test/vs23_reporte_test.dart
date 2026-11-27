import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:securelink_app/azure_api.dart';
import 'package:securelink_app/reporte_auditoria.dart';

void main() {
  test('el CSV protege fórmulas y omite campos ajenos a la auditoría', () {
    final csv = utf8.decode(
      csvAuditoria([
        {
          'usuarioId': 7,
          'accion': '  =2+2',
          'resultado': 'Dijo "ok",\nsegunda línea',
          'detalle': 'SECRETO',
          'accessToken': 'TOKEN',
        },
      ]),
    );
    expect(csv, contains('"7","\'  =2+2"'));
    expect(csv, contains('"Dijo ""ok"",\nsegunda línea"'));
    expect(csv, isNot(contains('SECRETO')));
    expect(csv, isNot(contains('TOKEN')));
  });

  test('genera un PDF de auditoría con varios registros', () async {
    final pdf = await pdfAuditoria(
      List.generate(
        20,
        (i) => {
          'usuarioId': i,
          'accion': 'EDICIÓN',
          'resultado': 'APLICADA',
          'detalle': 'Secreto',
        },
      ),
    );
    expect(ascii.decode(pdf.take(5).toList()), '%PDF-');
  });

  test('envía juntos los filtros por dispositivo, usuario y fecha', () async {
    final cliente = MockClient((request) async {
      expect(request.url.path, '/api/v1/redes/9/auditoria');
      expect(request.url.queryParameters['dispositivoId'], '23');
      expect(request.url.queryParameters['usuarioId'], '42');
      expect(request.url.queryParameters['desde'], '2026-11-20T00:00:00.000Z');
      return http.Response('{"total":0,"items":[]}', 200);
    });
    addTearDown(cliente.close);
    final api = AzureApi(
      cliente: cliente,
      obtenerToken: () => 'TOKEN_DE_PRUEBA',
    );
    await api.paginaAuditoria(
      redId: 9,
      dispositivoId: 23,
      usuarioId: 42,
      desde: DateTime.utc(2026, 11, 20),
    );
  });
}
