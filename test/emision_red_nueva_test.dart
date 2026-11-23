import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:securelink_app/azure_api.dart';
import 'package:securelink_app/incremento_app.dart';

import 'azure_api_test.dart' show cuentaFixture, redFixture, equipoFixture;

void main() {
  late String estadoRed;
  late bool aplicada;
  late int emisiones;
  late int respuestaEmision;
  late AzureApi api;

  setUp(() {
    estadoRed = 'PENDIENTE';
    aplicada = false;
    emisiones = 0;
    respuestaEmision = 202;
    api = AzureApi(
      obtenerToken: () => 'token-sintetico',
      cliente: MockClient((request) async {
        final path = request.url.path;
        Object body;
        var status = 200;
        if (path.endsWith('/redes/10')) {
          body = {...redFixture(estado: estadoRed), 'modoTunel': 'FULL'};
        } else if (path.endsWith('/vpn')) {
          status = aplicada ? 200 : 404;
          body = aplicada
              ? {'estadoAplicado': 'ACTIVA', 'direccionIp': '10.8.0.2'}
              : {'error': 'NO_ENCONTRADO'};
        } else if (path.endsWith('/configuracion') &&
            request.method == 'POST') {
          emisiones++;
          status = respuestaEmision;
          body = status == 202
              ? {
                  'id': '00000000-0000-0000-0000-000000000001',
                  'estado': 'PENDIENTE',
                }
              : {'error': 'ERROR_CONTROLADO'};
        } else if (path.contains('/operaciones-vpn/')) {
          aplicada = true;
          estadoRed = 'ACTIVA';
          body = {
            'id': '00000000-0000-0000-0000-000000000001',
            'estado': 'APLICADA',
          };
        } else {
          status = 404;
          body = {'error': 'NO_ENCONTRADO'};
        }
        return http.Response(
          jsonEncode(body),
          status,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
  });

  Future<void> abrir(WidgetTester tester, {String cuenta = 'ACTIVO'}) async {
    tester.view.physicalSize = const Size(1400, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EquipoDialog(
            api: api,
            red: RedAzure.fromJson(redFixture(estado: estadoRed)),
            equipo: EquipoAzure.fromJson(equipoFixture()),
            cuenta: CuentaAzure.fromJson({
              ...cuentaFixture(),
              'estado': cuenta,
            }),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder solicitar() =>
      find.widgetWithText(FilledButton, 'Solicitar configuración VPN');
  Finder entregar() =>
      find.widgetWithText(OutlinedButton, 'Entregar archivo o QR');

  testWidgets(
    'primera emisión permite red pendiente sin perfil y espera confirmación',
    (tester) async {
      await abrir(tester);
      expect(tester.widget<FilledButton>(solicitar()).onPressed, isNotNull);
      expect(tester.widget<OutlinedButton>(entregar()).onPressed, isNull);
      await tester.ensureVisible(solicitar());
      await tester.tap(solicitar());
      await tester.pumpAndSettle();
      expect(emisiones, 1);
      expect(find.text('Emisión: Aplicada'), findsOneWidget);
      expect(tester.widget<OutlinedButton>(entregar()).onPressed, isNotNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final estado in ['SUSPENDIDA', 'ELIMINADA']) {
    testWidgets('red $estado no permite primera emisión', (tester) async {
      estadoRed = estado;
      await abrir(tester);
      expect(tester.widget<FilledButton>(solicitar()).onPressed, isNull);
      expect(tester.widget<OutlinedButton>(entregar()).onPressed, isNull);
      expect(emisiones, 0);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('cuenta suspendida no habilita emisión en pantalla', (
    tester,
  ) async {
    await abrir(tester, cuenta: 'SUSPENDIDO');
    expect(tester.widget<FilledButton>(solicitar()).onPressed, isNull);
    expect(emisiones, 0);
    await tester.pumpWidget(const SizedBox());
  });

  for (final status in [403, 409, 503]) {
    testWidgets(
      'rechazo HTTP $status no habilita descarga ni anuncia aplicada',
      (tester) async {
        respuestaEmision = status;
        await abrir(tester);
        await tester.ensureVisible(solicitar());
        await tester.tap(solicitar());
        await tester.pumpAndSettle();
        expect(emisiones, 1);
        expect(find.text('Emisión: Aplicada'), findsNothing);
        expect(tester.widget<OutlinedButton>(entregar()).onPressed, isNull);
        expect(find.textContaining('Emisión sin confirmar.'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
