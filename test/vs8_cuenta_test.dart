import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:securelink_app/cuenta_propia.dart';
import 'package:securelink_app/incremento_app.dart';
import 'package:securelink_app/sesion_azure.dart';

void main() {
  const clave = 'ActualFicticia123';
  const nueva = 'NuevaFicticia456';
  const correo = 'vs8@example.test';
  late SesionAzure sesion;
  late List<http.Request> peticiones;
  late int estadoLogin,
      estadoCambio,
      estadoSalida,
      estadoPerfil,
      estadoRegistro;

  http.Response json(Object datos, [int estado = 200]) => http.Response(
    jsonEncode(datos),
    estado,
    headers: {'content-type': 'application/json'},
  );

  setUp(() {
    peticiones = [];
    estadoLogin = estadoCambio = estadoSalida = estadoPerfil = estadoRegistro =
        200;
    final cuenta = {
      'id': 1,
      'nombre': 'Nombre de la API',
      'correo': correo,
      'estado': 'ACTIVO',
      'roles': ['USUARIO_VPN'],
    };
    sesion = SesionAzure(
      cliente: MockClient((r) async {
        peticiones.add(r);
        return switch (r.url.path) {
          '/api/v1/auth/login' when estadoLogin == 200 => json({
            'accessToken': 'token-sintetico',
            'tokenType': 'Bearer',
            'expiresIn': 3600,
            'usuario': {...cuenta, 'nombre': 'Nombre en login'},
          }),
          '/api/v1/auth/login' => json({
            'error': 'CREDENCIALES_INVALIDAS',
          }, estadoLogin),
          '/api/v1/auth/registro' when estadoRegistro == 200 => json(
            cuenta,
            201,
          ),
          '/api/v1/auth/registro' => json({}, estadoRegistro),
          '/api/v1/usuarios/me' => json(cuenta, estadoPerfil),
          '/api/v1/usuarios/me/perfil' => json(cuenta, estadoPerfil),
          '/api/v1/usuarios/me/contrasena' when estadoCambio == 200 =>
            http.Response('', 204),
          '/api/v1/usuarios/me/contrasena' => json({}, estadoCambio),
          '/api/v1/auth/logout' when estadoSalida == 200 => http.Response(
            '',
            204,
          ),
          '/api/v1/auth/logout' => json({}, estadoSalida),
          '/api/v1/redes' => json([]),
          _ => json({}, 404),
        };
      }),
    );
  });
  tearDown(() => sesion.dispose());

  Future<void> abrir(WidgetTester t) async {
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = const Size(1200, 900);
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(IncrementoApp(sesion: sesion));
    await t.pumpAndSettle();
  }

  Future<void> pulsar(WidgetTester t, Finder finder) async {
    await t.ensureVisible(finder);
    await t.tap(finder);
    await t.pumpAndSettle();
  }

  Finder campo(String etiqueta, {bool dialogo = false}) {
    final campos = find.widgetWithText(TextFormField, etiqueta);
    return dialogo
        ? find.descendant(of: find.byType(FormularioCuenta), matching: campos)
        : campos;
  }

  Future<void> login(WidgetTester t) async {
    await t.enterText(campo('Correo electrónico'), correo);
    await t.enterText(campo('Contraseña'), clave);
    await pulsar(t, find.widgetWithText(FilledButton, 'Iniciar sesión'));
  }

  testWidgets(
    'VS-8 registro público valida, muestra duplicado y no inicia sesión',
    (t) async {
      await abrir(t);
      await pulsar(t, find.text('Crear cuenta'));
      await t.enterText(campo('Nombre', dialogo: true), 'Nombre nuevo');
      await t.enterText(campo('Correo electrónico', dialogo: true), correo);
      await t.enterText(campo('Nueva contraseña', dialogo: true), 'corta');
      await pulsar(t, find.text('Registrar cuenta'));
      expect(peticiones, isEmpty);
      expect(find.textContaining('al menos 12'), findsOneWidget);
      await t.enterText(campo('Nueva contraseña', dialogo: true), nueva);
      await t.enterText(campo('Confirmar contraseña', dialogo: true), nueva);
      estadoRegistro = 409;
      await pulsar(t, find.text('Registrar cuenta'));
      expect(
        find.textContaining('Comprueba que esté disponible'),
        findsOneWidget,
      );
      estadoRegistro = 200;
      await pulsar(t, find.text('Registrar cuenta'));
      final r = peticiones.last;
      expect(r.url.path, '/api/v1/auth/registro');
      expect(r.method, 'POST');
      expect(r.headers['authorization'], isNull);
      expect(jsonDecode(r.body), {
        'nombre': 'Nombre nuevo',
        'correo': correo,
        'contrasena': nueva,
      });
      expect(sesion.cuenta, isNull);
      expect(find.textContaining('Cuenta creada'), findsOneWidget);
    },
  );

  testWidgets('VS-8 credenciales inválidas y caducidad al cumplirse una hora', (
    t,
  ) async {
    await abrir(t);
    estadoLogin = 401;
    await login(t);
    expect(find.text('Correo o contraseña incorrectos.'), findsOneWidget);
    expect(sesion.cuenta, isNull);
    estadoLogin = 200;
    await login(t);
    expect(find.byTooltip('Mi cuenta'), findsOneWidget);
    await t.pump(const Duration(minutes: 59, seconds: 59));
    expect(sesion.cuenta, isNotNull);
    await t.pump(const Duration(seconds: 1));
    await t.pumpAndSettle();
    expect(find.textContaining('Tu sesión venció'), findsOneWidget);
    expect(sesion.cuenta, isNull);
  });

  testWidgets('VS-8 consulta el perfil con Bearer, edita y vuelve al login', (
    t,
  ) async {
    await abrir(t);
    await login(t);
    await pulsar(t, find.byTooltip('Mi cuenta'));
    expect(find.text('Nombre de la API'), findsOneWidget);
    expect(peticiones.last.headers['authorization'], 'Bearer token-sintetico');
    await pulsar(t, find.text('Editar perfil'));
    await t.enterText(campo('Nombre', dialogo: true), 'Nombre actualizado');
    await pulsar(t, find.text('Guardar cambios'));
    final r = peticiones.last;
    expect(r.url.path, '/api/v1/usuarios/me/perfil');
    expect(r.method, 'POST');
    expect(jsonDecode(r.body), {
      'nombre': 'Nombre actualizado',
      'correo': correo,
    });
    expect(find.textContaining('Perfil actualizado.'), findsOneWidget);
    expect(sesion.cuenta, isNull);
  });

  testWidgets(
    'VS-8 una clave actual incorrecta conserva la sesión y un cambio válido la cierra',
    (t) async {
      await abrir(t);
      await login(t);
      await pulsar(t, find.byTooltip('Mi cuenta'));
      await pulsar(t, find.text('Cambiar contraseña'));
      await t.enterText(campo('Contraseña actual', dialogo: true), clave);
      await t.enterText(campo('Nueva contraseña', dialogo: true), nueva);
      await t.enterText(campo('Confirmar contraseña', dialogo: true), nueva);
      estadoCambio = 401;
      await pulsar(t, find.text('Guardar cambios'));
      expect(find.text('La contraseña actual es incorrecta.'), findsOneWidget);
      expect(sesion.cuenta, isNotNull);
      estadoCambio = 200;
      await pulsar(t, find.text('Guardar cambios'));
      final r = peticiones.last;
      expect(r.url.path, '/api/v1/usuarios/me/contrasena');
      expect(r.method, 'POST');
      expect(jsonDecode(r.body), {
        'contrasenaActual': clave,
        'contrasenaNueva': nueva,
      });
      expect(find.textContaining('Contraseña actualizada.'), findsOneWidget);
      expect(sesion.cuenta, isNull);
    },
  );

  testWidgets('VS-8 un 401 del perfil saca al usuario del panel', (t) async {
    await abrir(t);
    await login(t);
    estadoPerfil = 401;
    await pulsar(t, find.byTooltip('Mi cuenta'));
    expect(find.textContaining('Tu sesión venció'), findsOneWidget);
    expect(sesion.cuenta, isNull);
  });

  for (final estado in [200, 503]) {
    testWidgets('VS-8 cierre de todas las sesiones con respuesta $estado', (
      t,
    ) async {
      await abrir(t);
      await login(t);
      estadoSalida = estado;
      await pulsar(t, find.byTooltip('Cerrar todas mis sesiones'));
      await pulsar(t, find.text('Cerrar sesiones'));
      expect(peticiones.last.url.path, '/api/v1/auth/logout');
      expect(peticiones.last.method, 'POST');
      expect(sesion.cuenta, isNull);
      expect(
        find.textContaining(
          estado == 200
              ? 'Se cerraron las sesiones'
              : 'No se pudo confirmar el cierre',
        ),
        findsOneWidget,
      );
    });
  }
}
