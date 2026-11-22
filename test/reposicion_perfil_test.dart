import 'package:flutter_test/flutter_test.dart';
import 'package:securelink_app/azure_api.dart';
import 'package:securelink_app/dispositivos.dart';
import 'package:securelink_app/reposicion_perfil.dart';
import 'package:securelink_app/api_error.dart' show ExcepcionApi;

import 'azure_api_test.dart' show cuentaFixture, redFixture, equipoFixture;

class ApiReposicion extends AzureApi {
  ApiReposicion() : super(obtenerToken: () => null);
  final pasos = <String>[];
  List<String> estados = ['PENDIENTE', 'APLICADA'];
  int indice = 0;
  SolicitudDispositivo? solicitud;
  @override
  Future<Map<String, dynamic>> revocar(int redId, int equipoId) async {
    pasos.add('revocar');
    return {
      'id': '00000000-0000-0000-0000-000000000001',
      'estado': 'PENDIENTE',
    };
  }

  @override
  Future<Map<String, dynamic>> operacion(int redId, String uuid) async {
    final estado =
        estados[indice < estados.length ? indice++ : estados.length - 1];
    pasos.add(estado);
    return {'id': uuid, 'estado': estado};
  }

  @override
  Future<EquipoAzure> registrar(
    int redId,
    SolicitudDispositivo solicitud,
  ) async {
    pasos.add('registrar');
    this.solicitud = solicitud;
    return EquipoAzure.fromJson(equipoFixture(id: 21));
  }

  @override
  Future<Map<String, dynamic>> solicitar(int redId, int equipoId) async {
    pasos.add('provisionar');
    return {
      'id': '00000000-0000-0000-0000-000000000002',
      'estado': 'PENDIENTE',
    };
  }
}

void main() {
  late ApiReposicion api;
  setUp(() => api = ApiReposicion());
  tearDown(() => api.cerrar());
  test('espera revocación APLICADA antes de crear otro equipo y solicitar nuevas claves', () async {
    final resultado = await ReposicionPerfil(api, pausa: () async {}).ejecutar(
      RedAzure.fromJson(redFixture()),
      EquipoAzure.fromJson(equipoFixture()),
      CuentaAzure.fromJson(cuentaFixture()),
    );
    expect(api.pasos, [
      'revocar',
      'PENDIENTE',
      'APLICADA',
      'registrar',
      'provisionar',
    ]);
    expect(resultado.equipo.id, 21);
    expect(resultado.operacion['estado'], 'PENDIENTE');
    expect(api.solicitud!.usuarioId, '1');
    expect(api.solicitud!.sistemaOperativo, 'IOS');
  });
  for (final estado in ['FALLIDA', 'CANCELADA']) {
    test(
      'no crea ni emite un perfil si la revocación termina $estado',
      () async {
        api.estados = [estado];
        await expectLater(
          ReposicionPerfil(api, pausa: () async {}).ejecutar(
            RedAzure.fromJson(redFixture()),
            EquipoAzure.fromJson(equipoFixture()),
            CuentaAzure.fromJson(cuentaFixture()),
          ),
          throwsA(isA<ReposicionPendiente>()),
        );
        expect(api.pasos, ['revocar', estado]);
        expect(api.solicitud, isNull);
      },
    );
  }
  test(
    'agente pendiente agota espera sin inventar éxito ni duplicar dispositivos',
    () async {
      api.estados = ['PENDIENTE'];
      await expectLater(
        ReposicionPerfil(api, intentos: 2, pausa: () async {}).ejecutar(
          RedAzure.fromJson(redFixture()),
          EquipoAzure.fromJson(equipoFixture()),
          CuentaAzure.fromJson(cuentaFixture()),
        ),
        throwsA(isA<ReposicionPendiente>()),
      );
      expect(api.pasos, ['revocar', 'PENDIENTE', 'PENDIENTE']);
      expect(api.solicitud, isNull);
    },
  );
  test('un no propietario no inicia una revocación', () async {
    await expectLater(
      ReposicionPerfil(api).ejecutar(
        RedAzure.fromJson(redFixture(propietario: 2)),
        EquipoAzure.fromJson(equipoFixture()),
        CuentaAzure.fromJson(cuentaFixture()),
      ),
      throwsA(isA<ExcepcionApi>()),
    );
    expect(api.pasos, isEmpty);
  });
  test(
    'si la sesión o vista dejó de ser vigente no registra otro dispositivo',
    () async {
      api.estados = ['APLICADA'];
      await expectLater(
        ReposicionPerfil(api).ejecutar(
          RedAzure.fromJson(redFixture()),
          EquipoAzure.fromJson(equipoFixture()),
          CuentaAzure.fromJson(cuentaFixture()),
          vigente: () => false,
        ),
        throwsA(isA<ReposicionPendiente>()),
      );
      expect(api.pasos, ['revocar', 'APLICADA']);
      expect(api.solicitud, isNull);
    },
  );
}
