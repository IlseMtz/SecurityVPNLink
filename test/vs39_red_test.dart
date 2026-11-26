import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:securelink_app/incremento_app.dart';
import 'package:securelink_app/sesion_azure.dart';

import 'azure_api_test.dart' show cuentaFixture, equipoFixture, redFixture;

const uuid = '01234567-89ab-4def-8123-0123456789ab';
const prefijo = '/api/v1';

class EscenarioRed {
  final peticiones = <http.Request>[];
  final redes = <int, Map<String, dynamic>>{
    10: {...redFixture(), 'descripcion': 'Descripción original', 'version': 3},
  };
  final equipos = [equipoFixture()];
  final miembros = <Map<String, dynamic>>[
    {
      'usuarioId': 1,
      'nombre': 'Propietario',
      'rolRed': 'PROPIETARIO',
      'estado': 'ACTIVO',
    },
  ];
  String estadoOperacion = 'PENDIENTE';
  String? accion;
  int consultas = 0;
  late final sesion = SesionAzure(cliente: MockClient(responder));

  http.Response json(Object datos, [int codigo = 200]) => http.Response(
    jsonEncode(datos),
    codigo,
    headers: {'content-type': 'application/json'},
  );

  Iterable<http.Request> get posts =>
      peticiones.where((r) => r.method == 'POST');

  Future<http.Response> responder(http.Request r) async {
    peticiones.add(r);
    final p = r.url.path.substring(prefijo.length);
    if (p == '/auth/login') {
      return json({
        'usuario': cuentaFixture(),
        'accessToken': 'sintetico',
        'tokenType': 'Bearer',
        'expiresIn': 3600,
      });
    }
    expect(r.headers['authorization'], 'Bearer sintetico');
    if (p == '/redes') {
      if (r.method == 'GET') return json(redes.values.toList());
      final datos = jsonDecode(r.body) as Map<String, dynamic>;
      redes[10] = {
        ...redFixture(estado: 'PENDIENTE'),
        ...datos,
        'cidr': null,
        'version': 0,
      };
      return json(redes[10]!, 201);
    }
    if (p == '/redes/10' && redes.containsKey(10)) return json(redes[10]!);
    if (p == '/redes/10/dispositivos' && r.method == 'GET') {
      return json(equipos);
    }
    if (p == '/redes/10/miembros') {
      if (r.method == 'GET') return json(miembros);
      final id = (jsonDecode(r.body) as Map)['usuarioId'];
      miembros.add({
        'usuarioId': id,
        'nombre': 'Miembro agregado',
        'rolRed': 'MIEMBRO',
        'estado': 'ACTIVO',
      });
      return json({}, 201);
    }
    if (p == '/redes/10/edicion' || p == '/redes/10/dispositivos/20/edicion') {
      if (redes[10]!['propietarioId'] != 1) return json({}, 403);
      final recurso = p.contains('dispositivos') ? equipos.first : redes[10]!;
      final datos = jsonDecode(r.body) as Map<String, dynamic>;
      if (datos['version'] != recurso['version']) {
        return json({'error': 'VERSION_SUPERADA'}, 409);
      }
      recurso.addAll(datos);
      recurso['version'] = (recurso['version'] as int) + 1;
      return json({'id_red': 10, 'id_dispositivo': 20, ...datos});
    }
    if (p == '/redes/10/operaciones-administrativas/$uuid') {
      consultas++;
      if (estadoOperacion == 'APLICADA') {
        switch (accion) {
          case 'suspension':
            redes[10]!['estado'] = 'SUSPENDIDA';
          case 'reactivacion':
            redes[10]!['estado'] = 'ACTIVA';
          case 'eliminacion':
            redes.remove(10);
          case 'retiro':
            miembros.removeWhere((m) => m['usuarioId'] == 2);
        }
      }
      return json({'id': uuid, 'estado': estadoOperacion});
    }
    if (r.method == 'POST' &&
        {
          'suspension',
          'reactivacion',
          'eliminacion',
          'retiro',
        }.contains(p.split('/').last)) {
      expect(r.body, isEmpty);
      accion = p.split('/').last;
      return json({'operacionAdministrativaId': uuid}, 202);
    }
    return json({}, 404);
  }
}

void main() {
  late EscenarioRed h;
  setUp(() => h = EscenarioRed());
  tearDown(() => h.sesion.dispose());

  Future<void> abrir(WidgetTester t) async {
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = const Size(1400, 1250);
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.runAsync(
      () => h.sesion.ingresar('prueba@example.test', 'solo prueba'),
    );
    await t.pumpWidget(IncrementoApp(sesion: h.sesion));
    await t.pumpAndSettle();
  }

  Future<void> pulsar(WidgetTester t, Finder f) async {
    await t.ensureVisible(f);
    await t.tap(f);
    await t.pumpAndSettle();
  }

  Future<void> boton(WidgetTester t, String etiqueta) =>
      pulsar(t, find.text(etiqueta));
  Finder campo(String titulo) => find.widgetWithText(TextFormField, titulo);

  testWidgets(
    'VS-39 crear red envía descripción y muestra PENDIENTE sin CIDR',
    (t) async {
      h.redes.clear();
      await abrir(t);
      await boton(t, 'Crear red');
      await t.enterText(campo('Nombre de la red'), 'Red temporal');
      await t.enterText(campo('Descripción'), 'Red para la demostración');
      await boton(t, 'Crear');
      expect(jsonDecode(h.posts.last.body), {
        'nombre': 'Red temporal',
        'descripcion': 'Red para la demostración',
      });
      expect(
        find.textContaining('Estado de la red: PENDIENTE'),
        findsOneWidget,
      );
      expect(find.textContaining('La subred se asignará'), findsOneWidget);
    },
  );

  testWidgets(
    'VS-39 los cupos se cuentan sobre redes propias y equipos habilitados',
    (t) async {
      for (final id in [11, 12, 13]) {
        h.redes[id] = {...redFixture(propietario: id == 13 ? 2 : 1), 'id': id};
      }
      h.equipos.addAll([
        for (var id = 21; id <= 24; id++) equipoFixture(id: id),
        {...equipoFixture(id: 25), 'estado': 'INACTIVO'},
      ]);
      await abrir(t);
      expect(
        find.text('Límite de tres redes propias alcanzado.'),
        findsOneWidget,
      );
      expect(find.text('5 de 5 dispositivos habilitados.'), findsOneWidget);
      expect(
        t
            .widget<OutlinedButton>(
              find.ancestor(
                of: find.text('Crear red'),
                matching: find.bySubtype<OutlinedButton>(),
              ),
            )
            .onPressed,
        isNull,
      );
      expect(
        t
            .widget<FilledButton>(
              find.ancestor(
                of: find.text('Registrar dispositivo'),
                matching: find.bySubtype<FilledButton>(),
              ),
            )
            .onPressed,
        isNull,
      );
    },
  );

  testWidgets(
    'VS-39 no muestra administración ni edición a un miembro sin propiedad',
    (t) async {
      h.redes[10]!['propietarioId'] = 2;
      await abrir(t);
      expect(find.text('Administrar red'), findsNothing);
      expect(
        find.byTooltip('Editar dispositivo Equipo de revisión'),
        findsNothing,
      );
      expect(
        h.peticiones.where((r) => r.url.path.endsWith('/miembros')),
        isEmpty,
      );
      expect(h.posts.length, 1);
    },
  );

  testWidgets(
    'VS-39 edición de red rechaza una versión obsoleta y permite recargar',
    (t) async {
      await abrir(t);
      await boton(t, 'Administrar red');
      await boton(t, 'Editar red');
      await t.enterText(campo('Nombre de la red'), 'Edición anterior');
      h.redes[10]!['version'] = 4;
      await boton(t, 'Guardar cambios');
      expect((jsonDecode(h.posts.last.body) as Map)['version'], 3);
      expect(find.textContaining('versión vigente'), findsOneWidget);
      await boton(t, 'Actualizar datos');
      await boton(t, 'Editar red');
      await t.enterText(campo('Nombre de la red'), 'Nombre actualizado');
      await t.enterText(campo('Descripción'), 'Nueva descripción');
      await boton(t, 'Guardar cambios');
      expect(jsonDecode(h.posts.last.body), {
        'nombre': 'Nombre actualizado',
        'descripcion': 'Nueva descripción',
        'version': 4,
      });
      expect(find.text('Administrar red: Nombre actualizado'), findsOneWidget);
    },
  );

  testWidgets(
    'VS-39 suspensión pendiente, fallo, reintento, reactivación y eliminación',
    (t) async {
      await abrir(t);
      await boton(t, 'Administrar red');
      await boton(t, 'Suspender red');
      await boton(t, 'Confirmar');
      expect(find.text('Suspender red: PENDIENTE'), findsOneWidget);
      expect(find.textContaining(uuid), findsOneWidget);
      await boton(t, 'Cerrar');
      await boton(t, 'Administrar red');
      expect(
        h.posts.where((r) => r.url.path.endsWith('/suspension')).length,
        1,
      );
      h.estadoOperacion = 'FALLIDA';
      await t.pump(const Duration(seconds: 4));
      await t.pumpAndSettle();
      expect(find.text('Suspender red: FALLIDA'), findsOneWidget);
      await boton(t, 'Reintentar operación');
      await boton(t, 'Confirmar');
      expect(
        h.posts.where((r) => r.url.path.endsWith('/suspension')).length,
        2,
      );
      h.estadoOperacion = 'APLICADA';
      await boton(t, 'Actualizar operación');
      expect(find.text('Suspender red: APLICADA'), findsOneWidget);
      await boton(t, 'Cerrar');
      expect(
        find.textContaining('Estado de la red: SUSPENDIDA'),
        findsOneWidget,
      );
      await boton(t, 'Administrar red');
      await boton(t, 'Reactivar red');
      await boton(t, 'Confirmar');
      await boton(t, 'Actualizar operación');
      expect(find.text('Reactivar red: APLICADA'), findsOneWidget);
      await boton(t, 'Cerrar');
      await boton(t, 'Administrar red');
      await boton(t, 'Eliminar red');
      await boton(t, 'Confirmar');
      expect(h.redes, isNotEmpty);
      await boton(t, 'Actualizar operación');
      expect(find.text('Eliminar red: APLICADA'), findsOneWidget);
      await boton(t, 'Cerrar');
      expect(find.text('Todavía no tienes redes.'), findsOneWidget);
      await boton(t, 'Operación de Laboratorio: APLICADA');
      final consultas = h.consultas;
      await boton(t, 'Actualizar operación');
      expect(h.consultas, consultas + 1);
      expect(find.text('Eliminar red: APLICADA'), findsOneWidget);
    },
  );

  testWidgets(
    'VS-39 agrega una cuenta activa y retira al miembro con UUID, no al propietario',
    (t) async {
      await abrir(t);
      await boton(t, 'Administrar red');
      expect(find.byTooltip('Retirar miembro 1'), findsNothing);
      await boton(t, 'Agregar miembro');
      await t.enterText(campo('ID de una cuenta activa'), '2');
      await boton(t, 'Agregar');
      expect(jsonDecode(h.posts.last.body), {'usuarioId': 2});
      expect(find.text('Miembro agregado · 2'), findsOneWidget);
      await pulsar(t, find.byTooltip('Retirar miembro 2'));
      await boton(t, 'Confirmar');
      expect(h.posts.last.url.path, '$prefijo/redes/10/miembros/2/retiro');
      expect(h.miembros.length, 2);
      h.estadoOperacion = 'APLICADA';
      await boton(t, 'Actualizar operación');
      expect(h.miembros.length, 1);
      expect(find.text('Retirar miembro: APLICADA'), findsOneWidget);
    },
  );

  testWidgets(
    'VS-39 edición de equipo usa la versión del listado y vuelve a consultar',
    (t) async {
      await abrir(t);
      await pulsar(t, find.byTooltip('Editar dispositivo Equipo de revisión'));
      await t.enterText(campo('Nombre del dispositivo'), 'Equipo editado');
      await pulsar(t, find.text('IOS').last);
      await pulsar(t, find.text('LINUX').last);
      await boton(t, 'Guardar cambios');
      expect(
        h.posts.last.url.path,
        '$prefijo/redes/10/dispositivos/20/edicion',
      );
      expect(jsonDecode(h.posts.last.body), {
        'nombre': 'Equipo editado',
        'sistemaOperativo': 'LINUX',
        'version': 0,
      });
      expect(find.text('Equipo editado'), findsOneWidget);
    },
  );
}
