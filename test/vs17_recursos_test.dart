import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:securelink_app/azure_api.dart';
import 'package:securelink_app/recursos_internos.dart';

void main() {
  testWidgets('El propietario consulta y retira una concesión directa', (tester) async {
    final calls = <String>[];
    var granted = true;
    final api = AzureApi(obtenerToken: () => 'prueba', cliente: MockClient((request) async {
      final path = request.url.path;
      calls.add('${request.method} $path');
      expect(request.headers['authorization'], 'Bearer prueba');
      if (path.endsWith('/retiro')) {
        granted = false;
        return http.Response('', 200);
      }
      final data = path.endsWith('/miembros')
          ? [{'usuarioId': 2, 'estado': 'ACTIVO', 'nombre': 'Ana'}]
          : {'recursos': [{'id': 5, 'nombre': 'Laboratorio', 'direccion': '172.30.77.10',
              'protocolo': 'TCP', 'puerto': 80, 'activo': true}],
             'concesiones': [if (granted) {'usuarioId': 2, 'recursoId': 5, 'dias': 31,
               'inicio': '09:00:00', 'fin': '18:00:00', 'zona': 'America/Mexico_City'}],
             'agenteDisponible': true};
      return http.Response(jsonEncode(data), 200);
    }));
    final red = RedAzure.fromJson({'id': 3, 'propietarioId': 1, 'nombre': 'Red de prueba', 'estado': 'ACTIVA'});
    await tester.pumpWidget(MaterialApp(home: RecursosInternosPage(api: api, red: red)));
    await tester.pumpAndSettle();
    expect(find.text('172.30.77.10 · TCP/80'), findsOneWidget);
    expect(find.text('Ana · Laboratorio'), findsOneWidget);
    await tester.tap(find.byTooltip('Retirar autorización'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Retirar'));
    await tester.pumpAndSettle();
    expect(calls, contains('POST /api/v1/redes/3/recursos/5/usuarios/2/retiro'));
    expect(find.text('Todavía no hay autorizaciones.'), findsOneWidget);
    expect(find.text('Cambio guardado. El agente sincroniza la política.'), findsOneWidget);
  });
}
