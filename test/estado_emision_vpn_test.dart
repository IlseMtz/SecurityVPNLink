import 'package:flutter_test/flutter_test.dart';
import 'package:securelink_app/estado_emision_vpn.dart';

void main() {
  bool permite({
    String? operacion,
    String? perfil = 'ACTIVA',
    bool red = true,
    bool dispositivo = true,
    bool cuenta = true,
    bool consultando = false,
  }) => puedeEntregarPerfil(
    redActiva: red,
    dispositivoActivo: dispositivo,
    cuentaActiva: cuenta,
    estadoPerfil: perfil,
    estadoOperacion: operacion,
    consultaEnCurso: consultando,
  );

  test('perfil vigente sin nueva emisión permite entrega', () {
    expect(permite(), isTrue);
  });
  test('requiere operación aplicada y perfil activo', () {
    expect(permite(operacion: 'APLICADA'), isTrue);
    expect(permite(operacion: 'APLICADA', perfil: null), isFalse);
    expect(permite(operacion: 'APLICADA', perfil: 'REVOCADA'), isFalse);
  });
  for (final estado in ['PENDIENTE', 'FALLIDA', 'CANCELADA', 'DESCONOCIDA']) {
    test('estado $estado no habilita el perfil anterior', () {
      expect(permite(operacion: estado), isFalse);
    });
  }
  test('red, dispositivo o cuenta inactivos impiden entrega', () {
    expect(permite(red: false), isFalse);
    expect(permite(dispositivo: false), isFalse);
    expect(permite(cuenta: false), isFalse);
  });
  test('una consulta pendiente no se interpreta como confirmación', () {
    expect(permite(consultando: true), isFalse);
  });
}
