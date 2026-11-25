import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/equipo2_harness.dart';

// Pruebas adicionales propuestas con asistencia de IA. No atribuyen ejecución humana.
void main() {
  testWidgets('S07 confirmar revocacion envia una orden y conserva pendiente', (tester) async {
    final h = EscenarioEquipo2();
    await h.equipo(tester);
    await tester.tap(find.text('Revocar dispositivo'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Confirmar revocación'));
    await tester.pumpAndSettle();
    expect(h.peticiones.where((r) => r.method == 'POST' && r.url.path.endsWith('/revocacion')).length, 1);
    expect(find.textContaining('Revocación: PENDIENTE'), findsOneWidget);
    expect(find.text('Entregar archivo o QR'), findsNothing);
    expect(find.text('Solicitar configuración VPN'), findsNothing);
    expect(find.text('Reponer un perfil perdido'), findsNothing);
  });
  testWidgets('S07 miembro sin propiedad no puede revocar', (tester) async {
    final h = EscenarioEquipo2(propietario: 2);
    await h.equipo(tester);
    expect(find.text('Revocar dispositivo'), findsNothing);
    expect(h.peticiones.where((r) => r.method == 'POST'), isEmpty);
  });
  testWidgets('S07 aplicar usuario realmente filtra y permite restablecer', (tester) async {
    final h = EscenarioEquipo2();
    await h.auditoria(tester);
    await tester.enterText(find.widgetWithText(TextFormField, 'Usuario'), '2');
    await tester.tap(find.text('Aplicar filtros'));
    await tester.pumpAndSettle();
    expect(find.textContaining('ALTA_DISPOSITIVO'), findsNothing);
    expect(find.text('Sin eventos para estos filtros.'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextFormField, 'Usuario'), '1');
    await tester.tap(find.text('Aplicar filtros'));
    await tester.pumpAndSettle();
    expect(find.textContaining('ALTA_DISPOSITIVO'), findsOneWidget);
  });
  testWidgets('S07 intervalo incluye el dia final y excluye fechas anteriores', (tester) async {
    final h = EscenarioEquipo2();
    await h.auditoria(tester);
    await tester.enterText(find.widgetWithText(TextFormField, 'Desde'), '2026-11-24');
    await tester.enterText(find.widgetWithText(TextFormField, 'Hasta'), '2026-11-24');
    await tester.tap(find.text('Aplicar filtros'));
    await tester.pumpAndSettle();
    expect(find.textContaining('ALTA_DISPOSITIVO'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextFormField, 'Desde'), '2026-11-25');
    await tester.enterText(find.widgetWithText(TextFormField, 'Hasta'), '2026-11-25');
    await tester.tap(find.text('Aplicar filtros'));
    await tester.pumpAndSettle();
    expect(find.textContaining('ALTA_DISPOSITIVO'), findsNothing);
  });
  testWidgets('S07 rechaza fecha imposible sin normalizarla silenciosamente', (tester) async {
    final h = EscenarioEquipo2();
    await h.auditoria(tester);
    await tester.enterText(find.widgetWithText(TextFormField, 'Desde'), '2026-02-30');
    await tester.tap(find.text('Aplicar filtros'));
    await tester.pumpAndSettle();
    expect(find.textContaining('fechas válidas'), findsOneWidget);
  });
}
