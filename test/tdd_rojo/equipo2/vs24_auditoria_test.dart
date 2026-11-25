import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../support/equipo2_harness.dart';

// Fixtures sintéticos; las pruebas de evidencia verifican registros, no tráfico real.
void main() {
  testWidgets('VS24-R01 | Piloto: Nadia Ramirez | Copiloto: Ilse Jaqueline | listado permite filtrar por usuario', (tester) async {
    final h = EscenarioEquipo2();
    await h.auditoria(tester);
    expect(find.widgetWithText(TextFormField, 'Usuario'), findsOneWidget,
      reason: 'Falta el filtro de usuario requerido por Jira.');
  });
  testWidgets('VS24-R02 | Piloto: Ilse Jaqueline | Copiloto: Nadia Ramirez | listado permite filtrar por intervalo de fechas', (tester) async {
    final h = EscenarioEquipo2();
    await h.auditoria(tester);
    expect(find.widgetWithText(TextFormField, 'Desde'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Hasta'), findsOneWidget);
    expect(find.text('Aplicar filtros'), findsOneWidget);
  });
  testWidgets('VS24-C01 | Piloto: Nadia Ramirez | Copiloto: Ilse Jaqueline | presenta accion resultado actor objeto y fecha', (tester) async {
    final h = EscenarioEquipo2();
    await h.auditoria(tester);
    for (final accion in ['ALTA_DISPOSITIVO','EMISION','REVOCACION','CAMBIO_PERMISO']) {
      expect(find.textContaining(accion), findsOneWidget);
    }
    expect(find.textContaining('Actor: 1'), findsNWidgets(4));
    expect(find.textContaining('Objeto: 20'), findsNWidgets(4));
    expect(find.textContaining('2026-11-24T12:00:00Z'), findsNWidgets(4));
  });
  testWidgets('VS24-C02 | Piloto: Ilse Jaqueline | Copiloto: Nadia Ramirez | campos extra con secretos no se renderizan', (tester) async {
    final h = EscenarioEquipo2();
    await h.auditoria(tester);
    expect(find.textContaining('CLAVE_FICTICIA_NO_PUBLICAR'), findsNothing);
    expect(find.textContaining('privateKey'), findsNothing);
  });
  testWidgets('VS24-C03 | Piloto: Nadia Ramirez | Copiloto: Ilse Jaqueline | respuesta 403 no muestra eventos', (tester) async {
    final h = EscenarioEquipo2(estadoAuditoria:403);
    await h.auditoria(tester);
    expect(find.textContaining('No tienes permiso'), findsOneWidget);
    expect(find.textContaining('ALTA_DISPOSITIVO'), findsNothing);
  });
  test('VS24-R03 | Piloto: Ilse Jaqueline | Copiloto: Nadia Ramirez | evidencia de cuatro operaciones persistentes tras reinicio', () async {
    final d = evidenciaEquipo2('vs24_persistencia.json');
    evidenciaIdentificada(d);
    expect(d['reinicioRealizado'], isTrue);
    final antes = d['idsAntesDelReinicio'] as List;
    final despues = d['idsDespuesDelReinicio'] as List;
    expect(antes, isNotEmpty);
    expect(despues, containsAll(antes));
    final eventos = d['eventos'] as List;
    expect(eventos.map((e) => e['accion']), containsAll(
      ['ALTA_DISPOSITIVO','EMISION','REVOCACION','CAMBIO_PERMISO']));
    for (final e in eventos) {
      expect(e['actorId'], isNotNull);
      expect(e['objetoId'], isNotNull);
      referenciaReal(e['fecha']);
      referenciaReal(e['resultado']);
    }
  });
}

