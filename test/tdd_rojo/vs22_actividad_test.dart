import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:securelink_app/azure_api.dart';
import 'package:securelink_app/incremento_app.dart';
import 'package:securelink_app/resumen_vpn.dart';
import '../azure_api_test.dart' show cuentaFixture, redFixture, equipoFixture;

// Datos sintéticos; no consulta Azure ni modifica la VPN.
// Fecha de prueba relativa con margen: no depende del huso horario del equipo.
void main() {
  Map<String, dynamic> muestra({int handshake = 30, int recoleccion = 0,
      bool sinHandshake = false, bool reciente = true}) {
    final ahora = DateTime.now().toUtc();
    return {
      'peerPresente': true,
      'actividadReciente': reciente,
      'ultimoHandshake': sinHandshake ? null :
        ahora.subtract(Duration(seconds: handshake)).toIso8601String(),
      'observadoEn': ahora.subtract(Duration(seconds: recoleccion)).toIso8601String(),
    };
  }
  Future<void> resumen(WidgetTester tester, Map<String,dynamic> datos) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: ResumenVpn(
      operacion: null, modo: 'SPLIT', conexion: datos))));
  }

  testWidgets('VS22-R01 | Ricardo Almada | sin handshake no hay actividad observada',
      (tester) async {
    await resumen(tester, muestra(sinHandshake: true));
    expect(find.textContaining('Sin actividad observada'), findsOneWidget,
      reason: 'Un indicador reciente no debe sustituir un handshake real.');
    expect(find.textContaining('Actividad reciente reportada.'), findsNothing);
  });
  testWidgets('VS22-R02 | Jaime Lopez | recoleccion mayor a 60 s esta desactualizada',
      (tester) async {
    await resumen(tester, muestra(recoleccion: 61));
    expect(find.textContaining('Desactualizado'), findsOneWidget);
    expect(find.textContaining('Actividad reciente reportada.'), findsNothing);
  });
  testWidgets('VS22-R03 | Ricardo Almada | handshake de 181 s no es reciente',
      (tester) async {
    await resumen(tester, muestra(handshake: 181));
    expect(find.textContaining('Actividad reciente reportada.'), findsNothing,
      reason: 'VS-22 limita actividad reciente a 180 s.');
  });
  testWidgets('VS22-C01 | Jaime Lopez | handshake de 179 s permite actividad reciente',
      (tester) async {
    await resumen(tester, muestra(handshake: 179));
    expect(find.textContaining('Actividad reciente reportada.'), findsOneWidget);
    expect(find.textContaining('sesión activa'), findsNothing);
  });
  testWidgets('VS22-R04 | Ricardo Almada | sin fecha de recoleccion no confirma vigencia',
      (tester) async {
    final datos = muestra()..remove('observadoEn');
    await resumen(tester, datos);
    expect(find.textContaining('Actividad reciente reportada.'), findsNothing);
    expect(find.textContaining('Desactualizado'), findsOneWidget);
  });

  Future<void> dialogo(WidgetTester tester, {int cuentaId = 1,
      required http.Client cliente}) async {
    tester.view.physicalSize = const Size(1400, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = AzureApi(cliente: cliente, obtenerToken: () => 'TOKEN_SINTETICO');
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: EquipoDialog(
      api: api, red: RedAzure.fromJson(redFixture()),
      equipo: EquipoAzure.fromJson(equipoFixture()),
      cuenta: CuentaAzure.fromJson(cuentaFixture(id: cuentaId))))));
    await tester.pumpAndSettle();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      cliente.close();
    });
  }
  testWidgets('VS22-R05 | Jaime Lopez | consulta cada 30 s y cancela al cerrar',
      (tester) async {
    var consultas = 0;
    final cliente = MockClient((request) async {
      final path = request.url.path;
      final body = path.endsWith('/conexion')
          ? (() { consultas++; return muestra(); })()
          : path.endsWith('/vpn') ? {'estadoAplicado': 'ACTIVA'}
          : redFixture();
      return http.Response(jsonEncode(body), 200,
        headers: {'content-type': 'application/json'});
    });
    await dialogo(tester, cliente: cliente);
    await tester.tap(find.text('Consultar actividad observada'));
    await tester.pumpAndSettle();
    expect(consultas, 1);
    await tester.pump(const Duration(seconds: 29));
    expect(consultas, 1, reason: 'No consultar antes del intervalo.');
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(consultas, 2, reason: 'Falta la consulta automatica a los 30 s.');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 60));
    expect(consultas, 2, reason: 'No consultar al cerrar la pantalla.');
  });
  testWidgets('VS22-C02 | Ricardo Almada | un tercero no puede consultar actividad',
      (tester) async {
    var consultas = 0;
    final cliente = MockClient((request) async {
      if (request.url.path.endsWith('/conexion')) consultas++;
      return http.Response('{}', 403,
        headers: {'content-type': 'application/json'});
    });
    await dialogo(tester, cuentaId: 999, cliente: cliente);
    expect(find.text('Consultar actividad observada'), findsNothing);
    expect(consultas, 0);
  });
}

