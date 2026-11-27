import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:securelink_app/azure_api.dart';
import 'package:securelink_app/api_error.dart';
import 'package:securelink_app/administracion_cuentas.dart';
import 'package:securelink_app/administracion_catalogos.dart';
import 'package:securelink_app/administracion_formularios.dart';
import 'package:securelink_app/sesion_azure.dart';

Map<String, dynamic> perfil({int id = 1, List<String> permisos = const ['ADMINISTRACION_GLOBAL', 'USUARIOS_GESTIONAR']}) => {
  'id': id, 'nombre': 'Cuenta de prueba', 'correo': 'cuenta@example.test', 'estado': 'ACTIVO',
  'roles': ['ADMIN'], 'permisos': permisos,
};
http.Response respuesta(Object? valor, [int status = 200]) => http.Response(
  valor == null ? '' : jsonEncode(valor), status, headers: {'content-type': 'application/json'});
CuentaAzure admin() => CuentaAzure.fromJson(perfil());
const rol = {'id_rol': 4, 'codigo': 'CONSULTA', 'nombre': 'Consulta', 'descripcion': '', 'sistema': false,
  'version': 7, 'permisos': [{'id_permiso': 3, 'codigo': 'USUARIOS_LEER'}]};
const grupo = {'id_grupo': 6, 'nombre': 'Equipo de prueba', 'descripcion': '', 'activo': true, 'version': 9};
Future<void> montar(WidgetTester t, Widget child) async {
  t.view.physicalSize = const Size(1400, 1800); t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize); addTearDown(t.view.resetDevicePixelRatio);
  await t.pumpWidget(MaterialApp(home: child)); await t.pumpAndSettle();
}
void main() {
  test('VS41 permisos de alta, lectura y administración no se infieren del rol ni de una red', () {
    final lector = CuentaAzure.fromJson(perfil(permisos: ['USUARIOS_LEER']));
    expect(lector.leeCuentas, true); expect(lector.creaCuentas, false); expect(lector.administraCuentas, false);
    final creador = CuentaAzure.fromJson(perfil(permisos: ['USUARIOS_GESTIONAR']));
    expect(creador.creaCuentas, true); expect(creador.leeCuentas, false); expect(creador.abreCuentas, true);
    expect(CuentaAzure.fromJson(perfil(permisos: [])).abreCuentas, false);
  });
  test('VS41 alta autenticada no envía roles; edición y reemplazo usan rutas V6', () async {
    final requests = <http.Request>[];
    final api = AzureApi(obtenerToken: () => 'SINTETICO', cliente: MockClient((r) async {
      requests.add(r); return respuesta(null, 204);
    })); addTearDown(api.cerrar);
    await api.crearCuentaAdministrada(' Prueba ', ' prueba@example.test ', 'CLAVE_SOLO_PRUEBA');
    await api.editarCuentaAdministrada(2, ' Editado ', ' editado@example.test ');
    await api.reemplazarRolesCuenta(2, [1, 4]);
    expect(requests.map((r) => r.url.path), ['/api/v1/usuarios', '/api/v1/administracion/usuarios/2/perfil', '/api/v1/administracion/usuarios/2/roles']);
    expect(jsonDecode(requests.first.body), {'nombre': 'Prueba', 'correo': 'prueba@example.test', 'contrasena': 'CLAVE_SOLO_PRUEBA'});
    expect(jsonDecode(requests[1].body), {'nombre': 'Editado', 'correo': 'editado@example.test'});
    expect(jsonDecode(requests[2].body), {'rolIds': [1, 4]});
    expect(requests.every((r) => r.headers['Authorization'] == 'Bearer SINTETICO'), true);
  });
  test('VS41 rechazo del último ADMIN se propaga y no produce éxito', () async {
    final api = AzureApi(obtenerToken: () => 'SINTETICO', cliente: MockClient((_) async => respuesta({'error': 'ULTIMO_ADMIN'}, 409)));
    addTearDown(api.cerrar);
    await expectLater(api.cambiarEstadoCuenta(2, 'DADO_DE_BAJA'), throwsA(isA<ExcepcionApi>().having((e) => e.estado, 'estado', 409)));
    await expectLater(api.reemplazarRolesCuenta(2, [4]), throwsA(isA<ExcepcionApi>()));
  });
  test('VS41 roles inválidos no generan peticiones', () async {
    var calls = 0;
    final api = AzureApi(obtenerToken: () => 'SINTETICO', cliente: MockClient((_) async { calls++; return respuesta(null,204); }));
    addTearDown(api.cerrar);
    for (final ids in <List<int>>[[], [1, 1], [0], List.generate(11, (i) => i + 1)]) {
      await expectLater(api.reemplazarRolesCuenta(2, ids), throwsArgumentError);
    }
    expect(calls, 0);
  });
  test('VS41 edición conserva versión leída; eliminación de rol no envía cuerpo', () async {
    final requests = <http.Request>[];
    final api = AzureApi(obtenerToken: () => 'SINTETICO', cliente: MockClient((r) async {
      requests.add(r); return r.method == 'GET' ? respuesta(rol) : respuesta(null,204);
    })); addTearDown(api.cerrar);
    final detalle = await api.rolPanel(4);
    await api.guardarRol(id: 4, version: detalle['version'] as int, codigo: 'IGNORADO', nombre: 'Nuevo', descripcion: '', permisos: [3]);
    expect(jsonDecode(requests.last.body), {'nombre': 'Nuevo', 'descripcion': '', 'permisoIds': [3], 'version': 7});
    await api.eliminarRol(4);
    expect(requests.last.url.path, '/api/v1/administracion/roles/4/eliminacion'); expect(requests.last.body, '');
    await expectLater(api.guardarRol(id: 4, codigo: '', nombre: 'N', descripcion: '', permisos: []), throwsArgumentError);
  });
  test('VS41 grupos mantienen contrato de versión y solo mutan asociación administrativa', () async {
    final requests = <http.Request>[];
    final api = AzureApi(obtenerToken: () => 'SINTETICO', cliente: MockClient((r) async { requests.add(r); return respuesta(null,204); }));
    addTearDown(api.cerrar);
    await api.guardarGrupo(nombre: 'Equipo', descripcion: 'Prueba');
    expect(jsonDecode(requests.last.body), {'nombre': 'Equipo', 'descripcion': 'Prueba'});
    await api.guardarGrupo(id: 6, version: 9, nombre: 'Equipo', descripcion: '', activo: true);
    expect(jsonDecode(requests.last.body), {'nombre': 'Equipo', 'descripcion': '', 'activo': true, 'version': 9});
    await api.desactivarGrupo(6);
    await api.asociarGrupo(6, 2, agregar: true); await api.asociarGrupo(6, 2, agregar: false);
    expect(requests.skip(2).map((r) => r.url.path), ['/api/v1/administracion/grupos/6/eliminacion',
      '/api/v1/administracion/grupos/6/miembros/2/alta', '/api/v1/administracion/grupos/6/miembros/2/retiro']);
    expect(requests.skip(2).every((r) => r.body.isEmpty), true);
    expect(requests.every((r) => !r.url.path.contains('/redes/')), true);
  });
  test('VS41 consulta inicial admite array y grupos paginan desde cero', () async {
    final requests = <http.Request>[];
    final api = AzureApi(obtenerToken: () => 'SINTETICO', cliente: MockClient((r) async {
      requests.add(r); return r.url.path == '/api/v1/usuarios' ? respuesta([perfil()]) : respuesta({'total': 45, 'items': [perfil()]});
    })); addTearDown(api.cerrar);
    expect((await api.usuariosPorPermiso()).items.length, 1);
    final page = await api.miembrosGrupo(6, pagina: 1);
    expect(page.haySiguiente, true); expect(requests.last.url.queryParameters, {'page': '1', 'size': '20'});
  });
  testWidgets('VS41 sin administración global no consulta roles ni grupos', (t) async {
    var calls = 0;
    final api = AzureApi(obtenerToken: () => 'SINTETICO', cliente: MockClient((_) async { calls++; return respuesta({}); }));
    addTearDown(api.cerrar);
    for (final grupos in [false, true]) {
      await montar(t, CatalogosAdministrativosPage(key: ValueKey(grupos), api: api,
        cuentaActual: CuentaAzure.fromJson(perfil(permisos: ['USUARIOS_LEER'])), grupos: grupos));
      expect(find.textContaining('No tienes permiso'), findsOneWidget);
    }
    expect(calls, 0);
  });
  testWidgets('VS41 permiso de lectura usa usuarios y no ofrece administración global', (t) async {
    final paths = <String>[];
    final api = AzureApi(obtenerToken: () => 'SINTETICO', cliente: MockClient((r) async { paths.add(r.url.path); return respuesta([perfil()]); }));
    addTearDown(api.cerrar);
    await montar(t, AdministracionCuentasPage(api: api, cuentaActual: CuentaAzure.fromJson(perfil(permisos: ['USUARIOS_LEER']))));
    expect(paths, ['/api/v1/usuarios']); expect(find.text('Crear cuenta'), findsNothing);
    expect(t.widget<ListTile>(find.byType(ListTile)).onTap, isNull);
  });
  testWidgets('VS41 cuenta dada de baja nunca ofrece reactivación aunque retirada termine', (t) async {
    final api = AzureApi(obtenerToken: () => 'SINTETICO', cliente: MockClient((r) async => respuesta(
      r.url.path.endsWith('/accesos-vpn') ? {'estadoCuenta': 'DADO_DE_BAJA', 'retiradaCompleta': true}
        : {...perfil(id: 2), 'estado': 'DADO_DE_BAJA'})));
    addTearDown(api.cerrar);
    await montar(t, Scaffold(body: EstadoCuentaDialog(api: api, usuarioId: 2, cuentaActual: admin())));
    expect(find.text('Reactivar cuenta'), findsNothing); expect(find.text('Reemplazar roles'), findsNothing);
    expect(find.textContaining('no puede recuperarse'), findsOneWidget);
  });
  testWidgets('VS41 cancelar baja no envía POST; 202 conserva retirada pendiente', (t) async {
    var posts = 0;
    final api = AzureApi(obtenerToken: () => 'SINTETICO', cliente: MockClient((r) async {
      if (r.method == 'POST') {
        posts++; expect(jsonDecode(r.body), {'estado': 'DADO_DE_BAJA'});
        return respuesta({'estadoCuenta': 'DADO_DE_BAJA', 'retiradaCompleta': false},202);
      }
      return respuesta(r.url.path.endsWith('/accesos-vpn') ? {'estadoCuenta': 'ACTIVO', 'retiradaCompleta': false} : perfil(id: 2));
    })); addTearDown(api.cerrar);
    await montar(t, Scaffold(body: EstadoCuentaDialog(api: api, usuarioId: 2, cuentaActual: admin())));
    await t.tap(find.text('Dar de baja definitivamente')); await t.pumpAndSettle();
    await t.tap(find.text('Cancelar')); await t.pumpAndSettle(); expect(posts, 0);
    await t.tap(find.text('Dar de baja definitivamente')); await t.pumpAndSettle();
    await t.tap(find.text('Confirmar')); await t.pumpAndSettle(); expect(posts, 1);
    expect(find.textContaining('Retirada VPN sin confirmar'), findsOneWidget);
    expect(find.text('Reactivar cuenta'), findsNothing);
    await t.pumpWidget(const SizedBox.shrink()); await t.pump(const Duration(seconds: 65));
  });
  testWidgets('VS41 rol de sistema solo permite consulta', (t) async {
    final sistema = {...rol, 'codigo': 'ADMIN', 'sistema': true};
    final api = AzureApi(obtenerToken: () => 'SINTETICO', cliente: MockClient((r) async => respuesta(
      r.url.path.endsWith('/4') ? sistema : {'total': 1, 'items': [sistema]})));
    addTearDown(api.cerrar);
    await montar(t, CatalogosAdministrativosPage(api: api, cuentaActual: admin(), grupos: false));
    await t.tap(find.byType(ListTile)); await t.pumpAndSettle();
    expect(find.text('Editar'), findsNothing); expect(find.text('Eliminar'), findsNothing);
    expect(find.textContaining('solo consulta'), findsOneWidget);
  });
  testWidgets('VS41 formulario de rol excluye permiso reservado y envía versión vigente', (t) async {
    Map<String, dynamic>? enviado;
    final api = AzureApi(obtenerToken: () => 'SINTETICO', cliente: MockClient((r) async {
      if (r.method == 'POST') { enviado = jsonDecode(r.body) as Map<String,dynamic>; return respuesta(rol); }
      if (r.url.path.endsWith('/permisos')) return respuesta([
        {'id_permiso': 1, 'codigo': 'ADMINISTRACION_GLOBAL'}, {'id_permiso': 3, 'codigo': 'USUARIOS_LEER'}]);
      return respuesta(r.url.path.endsWith('/4') ? rol : {'total': 1, 'items': [rol]});
    })); addTearDown(api.cerrar);
    await montar(t, CatalogosAdministrativosPage(api: api, cuentaActual: admin(), grupos: false));
    await t.tap(find.byType(ListTile)); await t.pumpAndSettle();
    await t.tap(find.text('Editar')); await t.pumpAndSettle();
    expect(find.byType(CheckboxListTile), findsOneWidget);
    expect(t.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value, true);
    await t.tap(find.text('Guardar')); await t.pumpAndSettle();
    expect(enviado?['version'], 7); expect(enviado?['permisoIds'], [3]);
  });
  testWidgets('VS41 conflicto de versión mantiene formulario y exige recargar', (t) async {
    await montar(t, Scaffold(body: FormularioAdministrativo(titulo: 'Editar rol', campos: const [],
      guardar: (_, _, _) async => throw const ExcepcionApi(409, 'VERSION_CONFLICTO'))));
    await t.tap(find.text('Guardar')); await t.pumpAndSettle();
    expect(find.textContaining('versión desactualizada'), findsOneWidget);
    expect(t.widget<FilledButton>(find.widgetWithText(FilledButton, 'Guardar')).onPressed, isNull);
  });
  testWidgets('VS41 grupo inactivo impide altas; retirar conserva rutas VPN intactas', (t) async {
    final requests = <http.Request>[];
    final api = AzureApi(obtenerToken: () => 'SINTETICO', cliente: MockClient((r) async {
      requests.add(r);
      if (r.method == 'POST') return respuesta(null,204);
      return respuesta(r.url.path.endsWith('/miembros') ? {'total': 1, 'items': [perfil(id: 2)]} : {...grupo, 'activo': false});
    })); addTearDown(api.cerrar);
    await montar(t, MiembrosGrupoPage(api: api, cuentaActual: admin(), grupoId: 6));
    expect(t.widget<FilledButton>(find.widgetWithText(FilledButton, 'Agregar integrante')).onPressed, isNull);
    await t.tap(find.text('Retirar')); await t.pumpAndSettle();
    await t.tap(find.text('Confirmar')); await t.pumpAndSettle();
    expect(requests.where((r) => r.method == 'POST').single.url.path, '/api/v1/administracion/grupos/6/miembros/2/retiro');
    expect(requests.any((r) => r.url.path.contains('/redes/')), false);
  });
  test('VS41 actualización de permisos refleja servidor y no revive una sesión cerrada', () async {
    final pending = Completer<http.Response>();
    var consultas = 0;
    final sesion = SesionAzure(cliente: MockClient((r) async {
      if (r.url.path.endsWith('/login')) return respuesta({'accessToken': 'SINTETICO', 'tokenType': 'Bearer', 'expiresIn': 3600, 'usuario': perfil()});
      if (++consultas == 1) return respuesta(perfil(permisos: ['USUARIOS_LEER']));
      return pending.future;
    })); addTearDown(sesion.dispose);
    await sesion.ingresar('cuenta@example.test', 'SINTETICO');
    await sesion.actualizarPermisos(); expect(sesion.cuenta!.administraCuentas, false);
    final futuro = sesion.actualizarPermisos(); sesion.limpiar();
    pending.complete(respuesta(perfil())); await futuro; expect(sesion.cuenta, isNull);
  });
}
