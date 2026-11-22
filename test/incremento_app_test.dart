import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:securelink_app/azure_api.dart';
import 'package:securelink_app/incremento_app.dart';
import 'package:securelink_app/sesion_azure.dart';

import 'azure_api_test.dart' show cuentaFixture, redFixture, equipoFixture;

void main() {
  late AzureApi api;
  late SesionAzure sesion;
  late int solicitudesSecretas;
  late int propietario;
  late String estadoVpn;
  late String estadoOperacion;
  late int respuestaEmision;
  late List<String> rutas;
  setUp(() {
    solicitudesSecretas = 0;
    propietario = 1;
    estadoVpn = 'ACTIVA';
    estadoOperacion = 'PENDIENTE';
    respuestaEmision = 202;
    rutas = [];
    api = AzureApi(
      obtenerToken: () => 'token-ficticio',
      cliente: MockClient((r) async {
        rutas.add(r.url.path);
        Object? respuesta;
        final path = r.url.path;
        if (path.endsWith('/auth/login')) {
          respuesta = {
            'accessToken': 'ficticio',
            'tokenType': 'Bearer',
            'expiresIn': 3600,
            'usuario': cuentaFixture(),
          };
        } else if (path.endsWith('/redes'))
          respuesta = [redFixture(propietario: propietario)];
        else if (path.endsWith('/redes/10'))
          respuesta = redFixture(propietario: propietario);
        else if (path.endsWith('/miembros'))
          respuesta = [
            {
              'usuarioId': 1,
              'nombre': 'Cuenta revisión',
              'correo': 'revision@example.test',
              'estado': 'ACTIVO',
              'rolRed': 'PROPIETARIO',
            },
          ];
        else if (path.endsWith('/dispositivos'))
          respuesta = [equipoFixture()];
        else if (path.endsWith('/vpn'))
          respuesta = {'estadoAplicado': estadoVpn, 'direccionIp': '10.8.0.2'};
        else if (path.contains('/operaciones-vpn/'))
          respuesta = {
            'id': '00000000-0000-0000-0000-000000000001',
            'estado': estadoOperacion,
          };
        else if (path.endsWith('/configuracion') && r.method == 'POST') {
          if (respuestaEmision != 202) {
            return http.Response(
              '{}',
              respuestaEmision,
              headers: {'content-type': 'application/json'},
            );
          }
          respuesta = {
            'id': '00000000-0000-0000-0000-000000000001',
            'estado': 'PENDIENTE',
          };
        } else if (path.endsWith('/configuracion/qr')) {
          solicitudesSecretas++;
          return http.Response.bytes(
            base64Decode(
              'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a2XkAAAAASUVORK5CYII=',
            ),
            200,
            headers: {'content-type': 'image/png'},
          );
        } else if (path.endsWith('/configuracion')) {
          solicitudesSecretas++;
          return http.Response(
            '[Interface]\nPrivateKey = SINTETICA',
            200,
            headers: {'content-type': 'text/plain'},
          );
        } else
          return http.Response('{"error":"NO_ENCONTRADO"}', 404);
        return http.Response(
          jsonEncode(respuesta),
          r.method == 'POST' ? 202 : 200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    sesion = SesionAzure(api: api);
  });
  tearDown(() => sesion.dispose());
  Future<void> abrir(WidgetTester tester, Widget widget) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: widget));
    await tester.pumpAndSettle();
  }

  testWidgets('login valida campos vacíos sin enviar credenciales', (
    tester,
  ) async {
    await tester.pumpWidget(IncrementoApp(sesion: sesion));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Iniciar sesión'));
    await tester.pumpAndSettle();
    expect(find.text('Escribe un correo válido.'), findsOneWidget);
    expect(rutas, isEmpty);
    sesion.limpiar();
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'el frontend carga redes y dispositivos con el contrato real tras autenticar',
    (tester) async {
      await sesion.ingresar('revision@example.test', 'ficticia');
      await abrir(tester, RedesPage(sesion: sesion));
      expect(find.text('Equipo de revisión'), findsOneWidget);
      expect(find.text('Registrar dispositivo'), findsOneWidget);
      expect(rutas, contains('/api/v1/redes/10/dispositivos'));
      expect(rutas, contains('/api/v1/redes/10/miembros'));
      sesion.limpiar();
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'miembro sin propiedad no ve el alta ni consulta miembros restringidos',
    (tester) async {
      propietario = 2;
      await sesion.ingresar('revision@example.test', 'ficticia');
      await abrir(tester, RedesPage(sesion: sesion));
      expect(find.text('Registrar dispositivo'), findsNothing);
      expect(rutas.where((r) => r.endsWith('/miembros')), isEmpty);
      sesion.limpiar();
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'el alta vacía muestra validaciones y solo ofrece miembros activos',
    (tester) async {
      await abrir(
        tester,
        const AltaEquipoDialog(
          miembros: [
            {
              'usuarioId': 1,
              'nombre': 'Activo',
              'correo': 'a@example.test',
              'estado': 'ACTIVO',
            },
            {
              'usuarioId': 2,
              'nombre': 'Suspendido',
              'correo': 's@example.test',
              'estado': 'SUSPENDIDO',
            },
          ],
        ),
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Registrar'));
      await tester.pumpAndSettle();
      expect(find.text('Selecciona un miembro activo.'), findsOneWidget);
      expect(find.text('Escribe el nombre del dispositivo.'), findsOneWidget);
      expect(find.text('Selecciona el sistema operativo.'), findsOneWidget);
      expect(rutas, isEmpty);
      sesion.limpiar();
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('la entrega no pide archivo ni QR antes de verificar identidad', (
    tester,
  ) async {
    await abrir(
      tester,
      EntregaDialog(
        api: api,
        redId: 10,
        equipo: EquipoAzure.fromJson(equipoFixture()),
      ),
    );
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Descargar .conf'),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Mostrar QR'),
          )
          .onPressed,
      isNull,
    );
    expect(solicitudesSecretas, 0);
    sesion.limpiar();
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'confirmar identidad permite pedir QR y ocultarlo descarta la vista',
    (tester) async {
      await abrir(
        tester,
        EntregaDialog(
          api: api,
          redId: 10,
          equipo: EquipoAzure.fromJson(equipoFixture()),
        ),
      );
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(OutlinedButton, 'Mostrar QR'));
      await tester.pumpAndSettle();
      expect(solicitudesSecretas, 1);
      expect(find.byType(Image), findsOneWidget);
      await tester.ensureVisible(find.text('Ocultar y descartar QR'));
      await tester.tap(find.text('Ocultar y descartar QR'));
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsNothing);
      sesion.limpiar();
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('una configuración pendiente mantiene deshabilitada la entrega', (
    tester,
  ) async {
    estadoVpn = 'PENDIENTE';
    await abrir(
      tester,
      EquipoDialog(
        api: api,
        red: RedAzure.fromJson(redFixture()),
        equipo: EquipoAzure.fromJson(equipoFixture()),
        cuenta: CuentaAzure.fromJson(cuentaFixture()),
      ),
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Entregar archivo o QR'),
          )
          .onPressed,
      isNull,
    );
    expect(solicitudesSecretas, 0);
    sesion.limpiar();
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'un perfil aplicado en red activa habilita la entrega sin revelar secretos',
    (tester) async {
      await abrir(
        tester,
        EquipoDialog(
          api: api,
          red: RedAzure.fromJson(redFixture()),
          equipo: EquipoAzure.fromJson(equipoFixture()),
          cuenta: CuentaAzure.fromJson(cuentaFixture()),
        ),
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Entregar archivo o QR'),
            )
            .onPressed,
        isNotNull,
      );
      expect(solicitudesSecretas, 0);
      expect(find.textContaining('10.8.0.2'), findsOneWidget);
      sesion.limpiar();
      await tester.pumpWidget(const SizedBox());
    },
  );
  for (final estado in ['PENDIENTE', 'FALLIDA', 'CANCELADA']) {
    testWidgets('VS-13: emisión $estado bloquea entrega de perfil anterior', (
      tester,
    ) async {
      estadoVpn = 'ACTIVA';
      estadoOperacion = estado;
      await abrir(
        tester,
        EquipoDialog(
          api: api,
          red: RedAzure.fromJson(redFixture()),
          equipo: EquipoAzure.fromJson(equipoFixture()),
          cuenta: CuentaAzure.fromJson(cuentaFixture()),
        ),
      );
      await tester.tap(
        find.widgetWithText(FilledButton, 'Solicitar configuración VPN'),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Operación: $estado.'), findsOneWidget);
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Entregar archivo o QR'),
            )
            .onPressed,
        isNull,
      );
      expect(solicitudesSecretas, 0);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('VS-13: operación aplicada refresca perfil y habilita entrega', (
    tester,
  ) async {
    estadoOperacion = 'APLICADA';
    await abrir(
      tester,
      EquipoDialog(
        api: api,
        red: RedAzure.fromJson(redFixture()),
        equipo: EquipoAzure.fromJson(equipoFixture()),
        cuenta: CuentaAzure.fromJson(cuentaFixture()),
      ),
    );
    await tester.tap(
      find.widgetWithText(FilledButton, 'Solicitar configuración VPN'),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Entregar archivo o QR'),
          )
          .onPressed,
      isNotNull,
    );
    expect(rutas.where((ruta) => ruta.endsWith('/vpn')).length, 2);
    expect(solicitudesSecretas, 0);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'VS-13: error 503 no confirma emisión ni entrega perfil anterior',
    (tester) async {
      respuestaEmision = 503;
      await abrir(
        tester,
        EquipoDialog(
          api: api,
          red: RedAzure.fromJson(redFixture()),
          equipo: EquipoAzure.fromJson(equipoFixture()),
          cuenta: CuentaAzure.fromJson(cuentaFixture()),
        ),
      );
      await tester.tap(
        find.widgetWithText(FilledButton, 'Solicitar configuración VPN'),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Emisión sin confirmar.'), findsOneWidget);
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Entregar archivo o QR'),
            )
            .onPressed,
        isNull,
      );
      expect(solicitudesSecretas, 0);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
