
import 'package:flutter_test/flutter_test.dart';
import '../../support/equipo2_harness.dart';

// Fixtures sintéticos; las pruebas de evidencia verifican registros, no tráfico real.
void main() {
  testWidgets('VS18-R01 | Piloto: Nadia Ramirez | Copiloto: Ilse Jaqueline | panel muestra destino fijo de laboratorio y TCP 80', (tester) async {
    final h = EscenarioEquipo2();
    await h.redes(tester);
    expect(find.textContaining('172.30.77.10'), findsOneWidget);
    expect(find.textContaining('TCP/80'), findsOneWidget);
  });
  testWidgets('VS18-R02 | Piloto: Ilse Jaqueline | Copiloto: Nadia Ramirez | propietario puede asignar y retirar autorizacion', (tester) async {
    final h = EscenarioEquipo2();
    await h.redes(tester);
    expect(find.text('Autorizar recurso'), findsOneWidget);
    expect(find.text('Retirar autorización'), findsOneWidget);
  });
  testWidgets('VS18-C01 | Piloto: Nadia Ramirez | Copiloto: Ilse Jaqueline | miembro sin propiedad no administra concesiones', (tester) async {
    final h = EscenarioEquipo2(propietario:2);
    await h.redes(tester);
    expect(find.text('Autorizar recurso'), findsNothing);
    expect(find.text('Retirar autorización'), findsNothing);
    expect(h.peticiones.where((r) => r.method != 'GET' &&
      !r.url.path.endsWith('/auth/login')), isEmpty);
  });
  test('VS18-R03 | Piloto: Ilse Jaqueline | Copiloto: Nadia Ramirez | evidencia de denegacion sin concesion y permiso de destino exacto', () async {
    final d = evidenciaEquipo2('vs18_recurso.json');
    evidenciaIdentificada(d);
    expect(d['destino'], '172.30.77.10');
    expect(d['protocolo'], 'TCP');
    expect(d['puerto'], 80);
    expect(d['accesoSinConcesion'], isFalse);
    expect(d['accesoConConcesionDirecta'], isTrue);
  });
  test('VS18-R04 | Piloto: Nadia Ramirez | Copiloto: Ilse Jaqueline | evidencia de control en servidor ante AllowedIPs modificado', () async {
    final d = evidenciaEquipo2('vs18_aislamiento.json');
    evidenciaIdentificada(d);
    expect(d['allowedIpsModificadoEnCliente'], isTrue);
    expect(d['otroDestinoPermitido'], isFalse);
    expect(d['otroPuertoPermitido'], isFalse);
    expect(d['otroUsuarioSinConcesionPermitido'], isFalse);
  });
  test('VS18-R05 | Piloto: Ilse Jaqueline | Copiloto: Nadia Ramirez | evidencia de retirada en 10 s y evento de auditoria', () async {
    final d = evidenciaEquipo2('vs18_retirada.json');
    evidenciaIdentificada(d);
    expect(d['agenteDisponible'], isTrue);
    expect(d['traficoTrasRetirada'], isFalse);
    final a = DateTime.parse(d['aceptadaEn'] as String);
    final b = DateTime.parse(d['bloqueadaEn'] as String);
    expect(b.difference(a).inMicroseconds, inInclusiveRange(0,10000000));
    referenciaReal(d['eventoAuditoria']);
  });
}


