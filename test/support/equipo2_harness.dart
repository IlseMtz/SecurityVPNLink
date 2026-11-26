import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:securelink_app/azure_api.dart';
import 'package:securelink_app/incremento_app.dart';
import 'package:securelink_app/sesion_azure.dart';
import '../azure_api_test.dart' show cuentaFixture, redFixture, equipoFixture;

/// Doble de transporte: no accede a Azure, firewall, MySQL ni WireGuard.
class EscenarioEquipo2 {
  EscenarioEquipo2({this.propietario = 1, this.estadoEquipo = 'ACTIVO',
      this.estadoAuditoria = 200}) {
    api = AzureApi(obtenerToken: () => 'TOKEN_SINTETICO_E2',
      cliente: MockClient(responder));
    addTearDown(cerrar);
  }
  final int propietario;
  final String estadoEquipo;
  final int estadoAuditoria;
  late final AzureApi api;
  SesionAzure? sesion;
  bool _cerrado = false;

  void cerrar() {
    if (_cerrado) return;
    _cerrado = true;
    if (sesion != null) {
      sesion!.dispose();
    } else {
      api.cerrar();
    }
  }

  final peticiones = <http.Request>[];
  final eventos = [
    for (final accion in ['ALTA_DISPOSITIVO', 'EMISION', 'REVOCACION', 'CAMBIO_PERMISO'])
      {'accion': accion, 'resultado': 'APLICADA', 'actorId': 1, 'objetoId': 20,
       'fecha': '2026-11-24T12:00:00Z', 'privateKey': 'CLAVE_FICTICIA_NO_PUBLICAR'},
  ];
  Future<http.Response> responder(http.Request r) async {
    peticiones.add(r);
    final p = r.url.path;
    Object cuerpo;
    var estado = 200;
    if (p.endsWith('/auth/login')) {
      cuerpo = {'accessToken':'TOKEN_SINTETICO_E2','tokenType':'Bearer',
        'expiresIn':3600,'usuario':cuentaFixture()};
    } else if (p.endsWith('/redes')) {
      cuerpo = [redFixture(propietario: propietario)];
    } else if (p.endsWith('/redes/10')) {
      cuerpo = redFixture(propietario: propietario);
    } else if (p.endsWith('/dispositivos')) {
      cuerpo = [{...equipoFixture(), 'estado': estadoEquipo}];
    } else if (p.endsWith('/redes/10/recursos') && r.method == 'GET') {
      estado = propietario == 1 ? 200 : 403;
      cuerpo = estado == 200 ? {
        'recursos': [{'id': 1, 'nombre': 'Laboratorio', 'direccion': '172.30.77.10',
          'protocolo': 'TCP', 'puerto': 80, 'activo': true}],
        'concesiones': [{'usuarioId': 1, 'recursoId': 1, 'dias': 127,
          'inicio': '00:00:00', 'fin': '00:00:00', 'zona': 'UTC'}],
        'agenteDisponible': true,
      } : {'error': 'NO_AUTORIZADO'};
    } else if (p.endsWith('/miembros')) {
      cuerpo = [{'usuarioId':1,'nombre':'Usuario sintético','correo':'e2@example.test',
        'estado':'ACTIVO','rolRed':'PROPIETARIO'}];
    } else if (p.endsWith('/vpn')) {
      cuerpo = {'estadoAplicado':'ACTIVA','direccionIp':'10.8.0.2'};
    } else if (p.endsWith('/revocacion') && r.method == 'POST') {
      estado = 202;
      cuerpo = {'id':'00000000-0000-0000-0000-000000000001','estado':'PENDIENTE'};
    } else if (p.endsWith('/auditoria')) {
      estado = estadoAuditoria;
      cuerpo = estado == 200 ? eventos : {'error':'NO_AUTORIZADO'};
    } else {
      estado = 404; cuerpo = {'error':'NO_ENCONTRADO'};
    }
    return http.Response(jsonEncode(cuerpo), estado,
      headers: {'content-type':'application/json'});
  }
  Future<void> montar(WidgetTester tester, Widget widget) async {
    tester.view.physicalSize = const Size(1400,1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_CicloEscenarioEquipo2(
      alCerrar: cerrar,
      child: MaterialApp(home: Scaffold(body: widget)),
    ));
    await tester.pumpAndSettle();
    addTearDown(() async { await tester.pumpWidget(const SizedBox.shrink()); });
  }
  Future<void> equipo(WidgetTester tester) => montar(tester, EquipoDialog(
    api: api, red: RedAzure.fromJson(redFixture(propietario: propietario)),
    equipo: EquipoAzure.fromJson({...equipoFixture(), 'estado': estadoEquipo}),
    cuenta: CuentaAzure.fromJson(cuentaFixture())));
  Future<void> redes(WidgetTester tester) async {
    sesion = SesionAzure(api: api);
    await sesion!.ingresar('e2@example.test', 'SINTETICA');
    await montar(tester, RedesPage(sesion: sesion!));
  }
  Future<void> auditoria(WidgetTester tester) =>
    montar(tester, AuditoriaDialog(api: api, redId: 10));
}

// Flutter desmonta el árbol antes de comprobar temporizadores pendientes.
// La sesión pertenece al escenario y se libera en ese mismo ciclo, no solo
// en addTearDown, que puede ejecutarse después de comprobar invariantes.
class _CicloEscenarioEquipo2 extends StatefulWidget {
  const _CicloEscenarioEquipo2({required this.alCerrar, required this.child});
  final VoidCallback alCerrar;
  final Widget child;

  @override
  State<_CicloEscenarioEquipo2> createState() => _CicloEscenarioEquipo2State();
}

class _CicloEscenarioEquipo2State extends State<_CicloEscenarioEquipo2> {
  @override
  Widget build(BuildContext context) => widget.child;

  @override
  void dispose() {
    widget.alCerrar();
    super.dispose();
  }
}

Map<String,dynamic> evidenciaEquipo2(String nombre) {
  final archivo = File('docs/evidencias_equipo2/$nombre');
  expect(archivo.existsSync(), isTrue,
    reason: 'Falta el registro de evidencia real: ${archivo.path}');
  return jsonDecode(archivo.readAsStringSync()) as Map<String,dynamic>;
}
void referenciaReal(Object? valor) {
  expect(valor, isA<String>());
  expect((valor as String).trim(), isNotEmpty);
  expect(valor.toUpperCase(), isNot(contains('PENDIENTE')));
}
void evidenciaIdentificada(Map<String,dynamic> datos) {
  for (final campo in ['evidencia', 'fecha', 'ejecutor', 'version']) {
    referenciaReal(datos[campo]);
  }
}

