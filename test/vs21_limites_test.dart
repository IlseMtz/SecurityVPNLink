import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:securelink_app/azure_api.dart';

void main() {
  test('VS-21 consulta y guarda la política con su versión', () async {
    var llamadas = 0;
    final cliente = MockClient((req) async {
      llamadas++;
      expect(req.url.path, '/api/v1/redes/9/limites');
      expect(req.headers['authorization'], 'Bearer TOKEN_DE_PRUEBA');
      final editando = req.method == 'POST';
      if (editando) {
        expect(jsonDecode(req.body), {
          'limiteEquiposUsuario': 3,
          'version': 4,
          'modoTunel': 'SPLIT',
        });
      } else {
        expect(req.method, 'GET');
      }
      return http.Response(
        jsonEncode({
          'limiteEquiposUsuario': editando ? 3 : 5,
          'version': editando ? 5 : 4,
          'modoTunel': editando ? 'SPLIT' : 'FULL',
          'ocupadosPorUsuario': {'42': 1},
        }),
        200,
      );
    });
    addTearDown(cliente.close);
    final api = AzureApi(
      cliente: cliente,
      obtenerToken: () => 'TOKEN_DE_PRUEBA',
    );
    final actual = await api.limitesRed(9);
    expect(actual.ocupadosPorUsuario, {'42': 1});
    expect(actual.modoTunel, 'FULL');
    final editada = await api.actualizarLimitesRed(
      9,
      3,
      actual.version,
      'SPLIT',
    );
    expect(editada.limiteEquiposUsuario, 3);
    expect(editada.version, 5);
    expect(editada.modoTunel, 'SPLIT');
    expect(llamadas, 2);
  });
}
