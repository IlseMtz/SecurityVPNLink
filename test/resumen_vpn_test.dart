import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:securelink_app/resumen_vpn.dart';
import 'package:securelink_app/azure_api.dart';

void main() {
  Future<void> abrir(
    WidgetTester tester, {
    String estado = 'APLICADA',
    String? modo = 'FULL',
    Map<String, dynamic>? conexion,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ResumenVpn(
              operacion: {'estado': estado},
              modo: modo,
              conexion: conexion,
            ),
          ),
        ),
      ),
    );
  }

  test('el DTO conserva el modo real y no inventa SPLIT si falta', () {
    final json = <String, dynamic>{
      'id': 1,
      'propietarioId': 1,
      'nombre': 'Prueba',
      'estado': 'ACTIVA',
      'modoTunel': 'FULL',
    };
    expect(RedAzure.fromJson(json).modoTunel, 'FULL');
    json.remove('modoTunel');
    expect(RedAzure.fromJson(json).modoTunel, isNull);
  });
  testWidgets('APLICADA no anuncia conexión y FULL no se presenta como SPLIT', (
    tester,
  ) async {
    await abrir(tester);
    expect(find.text('Emisión: Aplicada'), findsOneWidget);
    expect(find.textContaining('no conecta automáticamente'), findsOneWidget);
    expect(
      find.textContaining('Full Tunnel: el perfil dirige'),
      findsOneWidget,
    );
    expect(find.textContaining('Sin consultar.'), findsOneWidget);
  });
  testWidgets('fallo no imprime mensajes arbitrarios del backend', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ResumenVpn(
            operacion: {
              'estado': 'FALLIDA',
              'codigoError': 'secreto-no-publicar',
            },
            modo: 'SPLIT',
            conexion: null,
          ),
        ),
      ),
    );
    expect(find.text('Emisión: Fallida'), findsOneWidget);
    expect(find.textContaining('secreto-no-publicar'), findsNothing);
  });
  testWidgets('peer presente sin handshake no se anuncia conectado', (
    tester,
  ) async {
    await abrir(
      tester,
      conexion: {
        'peerPresente': true,
        'actividadReciente': false,
        'ultimoHandshake': null,
        'bytesRecibidos': 0,
        'bytesEnviados': 0,
      },
    );
    expect(
      find.textContaining('Sin actividad reciente reportada.'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Último handshake: Sin registro'),
      findsOneWidget,
    );
  });
  for (final estado in ['PENDIENTE', 'EN_PROCESO', 'CANCELADA']) {
    testWidgets('muestra estado $estado sin anunciar aplicada', (tester) async {
      await abrir(tester, estado: estado);
      expect(find.text('Emisión: Aplicada'), findsNothing);
    });
  }
}
