
import 'package:flutter_test/flutter_test.dart';
import '../../support/equipo2_harness.dart';

// Fixtures sintéticos; las pruebas de evidencia verifican registros, no tráfico real.
void main() {
  testWidgets('VS15-R01 | Piloto: Nadia Ramirez | Copiloto: Ilse Jaqueline | el administrador dispone de revocacion independiente', (tester) async {
    final h = EscenarioEquipo2();
    await h.equipo(tester);
    expect(find.text('Revocar dispositivo'), findsOneWidget,
      reason: 'Reponer un perfil crea un reemplazo; falta revocar sin reemplazar.');
  });
  testWidgets('VS15-R02 | Piloto: Ilse Jaqueline | Copiloto: Nadia Ramirez | cancelar confirmacion no envia revocacion', (tester) async {
    final h = EscenarioEquipo2();
    await h.equipo(tester);
    expect(find.text('Revocar dispositivo'), findsOneWidget);
    await tester.tap(find.text('Revocar dispositivo'));
    await tester.pumpAndSettle();
    expect(h.peticiones.where((r) => r.method == 'POST'), isEmpty);
    expect(find.text('Cancelar'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(h.peticiones.where((r) => r.method == 'POST'), isEmpty);
  });
  test('VS15-C01 | Piloto: Nadia Ramirez | Copiloto: Ilse Jaqueline | 202 conserva PENDIENTE y no inventa bloqueo', () async {
    final h = EscenarioEquipo2();
    final respuesta = await h.api.revocar(10,20);
    expect(respuesta['estado'], 'PENDIENTE');
    expect(h.peticiones.single.method, 'POST');
    expect(h.peticiones.single.url.path, '/api/v1/redes/10/dispositivos/20/revocacion');
    expect(h.peticiones.single.headers['Authorization'], 'Bearer TOKEN_SINTETICO_E2');
  });
  testWidgets('VS15-C02 | Piloto: Ilse Jaqueline | Copiloto: Nadia Ramirez | equipo revocado no ofrece entrega de configuracion', (tester) async {
    final h = EscenarioEquipo2(estadoEquipo:'REVOCADO');
    await h.equipo(tester);
    expect(find.text('Entregar archivo o QR'), findsNothing);
    expect(h.peticiones.where((r) => r.url.path.endsWith('/configuracion')), isEmpty);
  });
  test('VS15-R03 | Piloto: Nadia Ramirez | Copiloto: Ilse Jaqueline | evidencia de peer retirado y bloqueo efectivo en hasta 10 s', () async {
    final d = evidenciaEquipo2('vs15_revocacion.json');
    evidenciaIdentificada(d);
    expect(d['agenteDisponible'], isTrue);
    expect(d['peerRetirado'], isTrue);
    expect(d['traficoBloqueado'], isTrue);
    final aceptacion = DateTime.parse(d['aceptadaEn'] as String);
    final bloqueo = DateTime.parse(d['bloqueadaEn'] as String);
    expect(bloqueo.difference(aceptacion).inMicroseconds, inInclusiveRange(0,10000000));
  });
  test('VS15-R04 | Piloto: Ilse Jaqueline | Copiloto: Nadia Ramirez | evidencia de suspension en cascada y bloqueo tras reinicio', () async {
    final d = evidenciaEquipo2('vs15_suspension_reinicio.json');
    evidenciaIdentificada(d);
    final dispositivos = d['dispositivosDeLaCuenta'] as List;
    final revocados = d['dispositivosRevocados'] as List;
    expect(dispositivos, isNotEmpty);
    expect(revocados.toSet(), dispositivos.toSet());
    expect(d['reinicioRealizado'], isTrue);
    expect(d['revocadosReactivados'], 0);
    expect(d['traficoRevocadoTrasReinicio'], isFalse);
  });
}


