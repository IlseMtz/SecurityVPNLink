import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import '../../support/equipo2_harness.dart';

// Registros y documentación de VS-31. No ejecutan restauraciones reales.
void main() {
  test('VS31-R01 | Piloto: Nadia Ramirez | Copiloto: Ilse Jaqueline | guia documenta arranque de todos los componentes', () async {
    final f = File('docs/evidencias_equipo2/ARRANQUE.md');
    expect(f.existsSync(), isTrue, reason:'Falta guia reproducible de arranque.');
    final texto = f.readAsStringSync().toLowerCase();
    for (final componente in ['frontend','backend','agente','caddy','mysql']) {
      expect(texto, contains(componente));
    }
  });
  test('VS31-R02 | Piloto: Ilse Jaqueline | Copiloto: Nadia Ramirez | guia de migraciones documenta preservacion y recuperacion', () async {
    final f = File('docs/evidencias_equipo2/MIGRACIONES.md');
    expect(f.existsSync(), isTrue, reason:'Falta documentar migraciones.');
    final texto = f.readAsStringSync().toLowerCase();
    for (final tema in ['migraciones','identidades','respaldo','recuperación']) {
      expect(texto, contains(tema));
    }
  });
  test('VS31-R03 | Piloto: Nadia Ramirez | Copiloto: Ilse Jaqueline | registro de respaldo manual protegido DB y configuracion', () async {
    final d = evidenciaEquipo2('vs31_respaldo.json');
    evidenciaIdentificada(d);
    expect(d['baseDeDatosIncluida'], isTrue);
    expect(d['configuracionIncluida'], isTrue);
    expect(d['accesoRestringido'], isTrue);
    referenciaReal(d['metodoProteccion']);
    referenciaReal(d['procedimientoRecuperacion']);
  });
  test('VS31-R04 | Piloto: Ilse Jaqueline | Copiloto: Nadia Ramirez | restauracion aislada conserva revocaciones', () async {
    final d = evidenciaEquipo2('vs31_restauracion.json');
    evidenciaIdentificada(d);
    expect(d['entornoAislado'], isTrue);
    expect(d['produccionModificada'], isFalse);
    expect(d['restauracionExitosa'], isTrue);
    expect(d['revocadosComprobados'], isNotEmpty);
    expect(d['revocadosReactivados'], 0);
  });
  test('VS31-R05 | Piloto: Nadia Ramirez | Copiloto: Ilse Jaqueline | revision de roles aislamiento y secretos sin criticos abiertos', () async {
    final d = evidenciaEquipo2('vs31_seguridad.json');
    evidenciaIdentificada(d);
    expect(d['rolesVerificados'], isTrue);
    expect(d['accesoEntreUsuariosDenegado'], isTrue);
    expect(d['secretosEnLogs'], isFalse);
    expect(d['secretosEnRepositorio'], isFalse);
    expect(d['defectosCriticosAbiertos'], 0);
    referenciaReal(d['revisor']);
  });
  test('VS31-C01 | Piloto: Ilse Jaqueline | Copiloto: Nadia Ramirez | manifiesto conserva el sitio existente', () async {
    final d = jsonDecode(File('hosting/.openai/hosting.json').readAsStringSync());
    expect(d['project_id'], 'appgprj_6b0313ccc5d081919910e30c7f9ece80');
  });
}


