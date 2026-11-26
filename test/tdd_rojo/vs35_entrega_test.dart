import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

// Puerta documental de VS-35. No sustituye ejecutar WireGuard ni la aceptacion
// humana. Los archivos deben contener evidencias reales, no datos inventados.
void main() {
  Map<String,dynamic> leer(String nombre) {
    final archivo = File('docs/entrega/$nombre');
    expect(archivo.existsSync(), isTrue,
      reason: 'Falta evidencia de entrega: ${archivo.path}');
    return jsonDecode(archivo.readAsStringSync()) as Map<String,dynamic>;
  }
  void referencia(Object? valor) {
    expect(valor, isA<String>());
    expect((valor as String).trim(), isNotEmpty);
    expect(valor.toUpperCase(), isNot(contains('PENDIENTE')));
  }
  test('VS35-R01 | Piloto: Ricardo Almada | Copiloto: Jaime Lopez | entrega identifica version, commit y URL', () {
    final datos = leer('version.json');
    referencia(datos['version']);
    expect(datos['commit'], matches(RegExp(r'^[0-9a-f]{40}$')));
    expect(Uri.tryParse(datos['url'] as String)?.scheme, 'https');
  });
  test('VS35-R02 | Piloto: Ricardo Almada | Copiloto: Jaime Lopez | guia cubre instalacion, uso, respaldo y Endpoint', () {
    final archivo = File('docs/entrega/GUIA.md');
    expect(archivo.existsSync(), isTrue, reason: 'Falta guia corta de VS-35.');
    final guia = archivo.readAsStringSync().toLowerCase();
    for (final seccion in ['instalación', 'uso', 'respaldo', 'endpoint']) {
      expect(guia, contains(seccion), reason: 'Falta documentar $seccion.');
    }
  });
  test('VS35-R03 | Piloto: Ricardo Almada | Copiloto: Jaime Lopez | flujo completo tiene evidencia por paso', () {
    final datos = leer('flujo_funcional.json');
    for (final paso in ['alta', 'configuracion', 'conexion', 'permisoRecurso', 'revocacion']) {
      final evidencia = datos[paso] as Map<String,dynamic>;
      expect(evidencia['resultado'], 'APROBADO', reason: 'Falta verificar $paso.');
      referencia(evidencia['evidencia']);
      referencia(evidencia['fecha']);
      referencia(evidencia['ejecutor']);
    }
  });
  test('VS35-R04 | Piloto: Ricardo Almada | Copiloto: Jaime Lopez | evidencia individual Windows 11, Android e iPhone', () {
    final datos = leer('plataformas.json');
    for (final plataforma in ['Windows 11', 'Android', 'iPhone']) {
      final evidencia = datos[plataforma] as Map<String,dynamic>;
      expect(evidencia['resultado'], 'APROBADO', reason: plataforma);
      referencia(evidencia['versionSistema']);
      referencia(evidencia['evidencia']);
      referencia(evidencia['ejecutor']);
    }
  });
  test('VS35-R05 | Piloto: Ricardo Almada | Copiloto: Jaime Lopez | entrega registra limitaciones y aceptacion humana', () {
    final datos = leer('aceptacion.json');
    expect(datos['limitaciones'], isA<List>());
    expect(datos['pendientes'], isA<List>());
    referencia(datos['version']);
    referencia(datos['revisor']);
    referencia(datos['fecha']);
    referencia(datos['evidencia']);
    expect(datos['decision'], isIn(['ACEPTADO', 'ACEPTADO_CON_CONDICIONES']));
    if (datos['decision'] == 'ACEPTADO_CON_CONDICIONES') {
      expect(datos['condiciones'], isNotEmpty);
    }
  });
}


