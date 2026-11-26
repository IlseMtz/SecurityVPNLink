import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:securelink_app/azure_api.dart';
import 'package:securelink_app/administracion_cuentas.dart';
import 'package:securelink_app/incremento_app.dart';
import 'azure_api_test.dart' show cuentaFixture, redFixture, equipoFixture;

http.Response respuesta(Object body, [int estado = 200]) => http.Response(
  jsonEncode(body), estado, headers: {'content-type': 'application/json'});
CuentaAzure admin() => CuentaAzure.fromJson({...cuentaFixture(), 'permisos': ['ADMINISTRACION_GLOBAL', 'AUDITORIA_LEER']});
Future<void> montar(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(1400, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
  await tester.pumpAndSettle();
}
void main() {
  test('Auditoria envia filtros documentados y conserva total y pagina', () async {
    late http.Request recibido;
    final api = AzureApi(obtenerToken: () => 'SINTETICO', cliente: MockClient((r) async {
      recibido = r;
      return respuesta({'page': 2, 'size': 20, 'total': 65, 'items': []});
    }));
    addTearDown(api.cerrar);
    final pagina = await api.paginaAuditoria(redId: 10, pagina: 2, usuarioId: 4,
      desde: DateTime.utc(2026,11,1), hasta: DateTime.utc(2026,11,25,23,59,59,999));
    expect(recibido.url.path, '/api/v1/redes/10/auditoria');
    expect(recibido.url.queryParameters['page'], '2');
    expect(recibido.url.queryParameters['usuarioId'], '4');
    expect(recibido.url.queryParameters['desde'], '2026-11-01T00:00:00.000Z');
    expect(recibido.url.queryParameters['hasta'], '2026-11-25T23:59:59.999Z');
    expect(pagina.total, 65);
    expect(pagina.haySiguiente, isTrue);
  });
  test('Suspension usa estado SUSPENDIDO y no inventa retirada completa en 202', () async {
    final api = AzureApi(obtenerToken: () => 'SINTETICO', cliente: MockClient((r) async {
      expect(r.method, 'POST');
      expect(r.url.path, '/api/v1/administracion/usuarios/2/estado');
      expect(jsonDecode(r.body), {'estado': 'SUSPENDIDO'});
      return respuesta({'usuarioId': 2, 'estadoCuenta': 'SUSPENDIDO', 'retiradaCompleta': false, 'configuraciones': []}, 202);
    }));
    addTearDown(api.cerrar);
    expect((await api.cambiarEstadoCuenta(2, 'SUSPENDIDO'))['retiradaCompleta'], isFalse);
  });
  test('Permisos administrativos ausentes no se deducen por ser propietario', () {
    final usuario = CuentaAzure.fromJson(cuentaFixture());
    expect(usuario.administraCuentas, isFalse);
    expect(usuario.consultaAuditoria, isFalse);
    expect(admin().administraCuentas, isTrue);
  });
  testWidgets('Cuentas no consulta API sin permiso administrativo', (tester) async {
    var solicitudes = 0;
    final api = AzureApi(obtenerToken: () => 'SINTETICO', cliente: MockClient((r) async {
      solicitudes++; return respuesta({});
    }));
    addTearDown(api.cerrar);
    await montar(tester, AdministracionCuentasPage(api: api, cuentaActual: CuentaAzure.fromJson(cuentaFixture())));
    expect(solicitudes, 0);
    expect(find.textContaining('No tienes permiso'), findsOneWidget);
  });
  testWidgets('Suspension cancelada no envia POST; confirmada bloquea reactivacion pendiente', (tester) async {
    var posts = 0;
    final api = AzureApi(obtenerToken: () => 'SINTETICO', cliente: MockClient((r) async {
      if (r.method == 'POST') {
        posts++;
        return respuesta({'usuarioId': 2, 'estadoCuenta': 'SUSPENDIDO', 'retiradaCompleta': false, 'configuraciones': []}, 202);
      }
      if (r.url.path.endsWith('/accesos-vpn')) return respuesta({'usuarioId': 2, 'estadoCuenta': 'ACTIVO', 'retiradaCompleta': false, 'configuraciones': []});
      return respuesta(cuentaFixture(id: 2));
    }));
    addTearDown(api.cerrar);
    await montar(tester, EstadoCuentaDialog(api: api, usuarioId: 2, cuentaActual: admin()));
    await tester.tap(find.widgetWithText(FilledButton, 'Suspender cuenta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar')); await tester.pumpAndSettle();
    expect(posts, 0);
    await tester.tap(find.widgetWithText(FilledButton, 'Suspender cuenta'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Confirmar'));
    await tester.pumpAndSettle();
    expect(posts, 1);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Reactivar cuenta')).onPressed, isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 65));
    expect(posts, 1);
  });
  testWidgets('Reactivacion exige retirada completa y envia ACTIVO', (tester) async {
    String? enviado;
    final api = AzureApi(obtenerToken: () => 'SINTETICO', cliente: MockClient((r) async {
      if (r.method == 'POST') {
        enviado = jsonDecode(r.body)['estado'] as String;
        return respuesta({'usuarioId': 2, 'estadoCuenta': 'ACTIVO', 'retiradaCompleta': true});
      }
      if (r.url.path.endsWith('/accesos-vpn')) return respuesta({'estadoCuenta': 'SUSPENDIDO', 'retiradaCompleta': true});
      return respuesta({...cuentaFixture(id: 2), 'estado': 'SUSPENDIDO'});
    }));
    addTearDown(api.cerrar);
    await montar(tester, EstadoCuentaDialog(api: api, usuarioId: 2, cuentaActual: admin()));
    await tester.tap(find.widgetWithText(FilledButton, 'Reactivar cuenta')); await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Confirmar')); await tester.pumpAndSettle();
    expect(enviado, 'ACTIVO');
    expect(find.text('Estado de cuenta: ACTIVO'), findsOneWidget);
  });
  testWidgets('Auditoria cambia pagina y manda filtro al servidor desde pagina cero', (tester) async {
    final solicitudes = <http.Request>[];
    final api = AzureApi(obtenerToken: () => 'SINTETICO', cliente: MockClient((r) async {
      solicitudes.add(r);
      return respuesta({'total': 21, 'items': [{'accion': 'REVOCACION', 'actorId': 1, 'fecha': '2026-11-25T12:00:00Z', 'resultado': 'APLICADA', 'objetoId': 20, 'privateKey': 'NO_MOSTRAR'}]});
    }));
    addTearDown(api.cerrar);
    await montar(tester, AuditoriaDialog(api: api));
    expect(solicitudes.last.url.path, '/api/v1/auditoria');
    await tester.tap(find.byTooltip('Página siguiente')); await tester.pumpAndSettle();
    expect(solicitudes.last.url.queryParameters['page'], '1');
    await tester.enterText(find.widgetWithText(TextFormField, 'Usuario'), '2');
    await tester.tap(find.text('Aplicar filtros')); await tester.pumpAndSettle();
    expect(solicitudes.last.url.queryParameters['page'], '0');
    expect(solicitudes.last.url.queryParameters['usuarioId'], '2');
    expect(find.textContaining('NO_MOSTRAR'), findsNothing);
  });
  testWidgets('Revocacion se consulta a los 3 s y detiene consultas al aplicar', (tester) async {
    var consultas = 0;
    final api = AzureApi(obtenerToken: () => 'SINTETICO', cliente: MockClient((r) async {
      if (r.url.path.contains('/operaciones-vpn/')) {
        consultas++; return respuesta({'id': '00000000-0000-0000-0000-000000000001', 'estado': 'APLICADA'});
      }
      if (r.method == 'POST') return respuesta({'id': '00000000-0000-0000-0000-000000000001', 'estado': 'PENDIENTE'},202);
      if (r.url.path.endsWith('/vpn')) return respuesta({'estadoAplicado':'ACTIVA'});
      return respuesta(redFixture());
    }));
    addTearDown(api.cerrar);
    await montar(tester, EquipoDialog(api: api, red: RedAzure.fromJson(redFixture()),
      equipo: EquipoAzure.fromJson(equipoFixture()), cuenta: CuentaAzure.fromJson(cuentaFixture())));
    await tester.tap(find.text('Revocar dispositivo')); await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton,'Confirmar revocación')); await tester.pumpAndSettle();
    expect(consultas, 0);
    await tester.pump(const Duration(seconds:3)); await tester.pumpAndSettle();
    expect(consultas, 1);
    expect(find.textContaining('Revocación: APLICADA'), findsOneWidget);
    expect(find.text('Entregar archivo o QR'), findsNothing);
    await tester.pump(const Duration(seconds:30));
    expect(consultas, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
