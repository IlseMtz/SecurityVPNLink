import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:securelink_app/azure_api.dart';
import 'package:securelink_app/dispositivos.dart';
import 'package:securelink_app/api_error.dart' show ExcepcionApi;

Map<String, dynamic> cuentaFixture({int id = 1}) => {
  'id': id,
  'nombre': 'Cuenta revisión',
  'correo': 'revision@example.test',
  'estado': 'ACTIVO',
  'roles': ['USUARIO_VPN'],
  'permisos': [],
};
Map<String, dynamic> redFixture({
  int propietario = 1,
  String estado = 'ACTIVA',
}) => {
  'id': 10,
  'propietarioId': propietario,
  'nombre': 'Laboratorio',
  'estado': estado,
  'cidr': '10.8.0.0/24',
};
Map<String, dynamic> equipoFixture({int id = 20}) => {
  'id': id,
  'redId': 10,
  'usuarioId': 1,
  'nombre': 'Equipo de revisión',
  'sistemaOperativo': 'IOS',
  'estado': 'ACTIVO',
  'version': 0,
};

void main() {
  late AzureApi api;
  late http.Request ultima;
  late int llamadas, estado, expiraciones;
  late Object? respuesta;
  late String? token;
  late String tipo;
  setUp(() {
    llamadas = 0;
    estado = 200;
    expiraciones = 0;
    respuesta = {};
    token = 'token-sintetico';
    tipo = 'application/json';
    api = AzureApi(
      obtenerToken: () => token,
      alCaducar: () => expiraciones++,
      cliente: MockClient((r) async {
        ultima = r;
        llamadas++;
        if (respuesta is Uint8List) {
          return http.Response.bytes(
            respuesta as Uint8List,
            estado,
            headers: {'content-type': tipo},
          );
        }
        return http.Response(
          jsonEncode(respuesta),
          estado,
          headers: {'content-type': tipo},
        );
      }),
    );
  });
  tearDown(() => api.cerrar());

  test(
    'login interpreta el DTO real sin Authorization ni persistir credenciales',
    () async {
      respuesta = {
        'accessToken': 'token-nuevo',
        'tokenType': 'Bearer',
        'expiresIn': 3600,
        'usuario': cuentaFixture(),
      };
      final acceso = await api.login(
        ' revision@example.test ',
        'ficticia-no-real',
      );
      expect(acceso.token, 'token-nuevo');
      expect(acceso.cuenta.id, 1);
      expect(acceso.expiraEn, const Duration(hours: 1));
      expect(ultima.url.toString(), '$urlAzure/auth/login');
      expect(ultima.headers.containsKey('Authorization'), isFalse);
      expect(jsonDecode(ultima.body), {
        'correo': 'revision@example.test',
        'contrasena': 'ficticia-no-real',
      });
    },
  );
  test('rechaza un login sin token o expiración válida', () async {
    respuesta = {
      'usuario': cuentaFixture(),
      'expiresIn': 3600,
      'tokenType': 'Bearer',
    };
    await expectLater(
      api.login('revision@example.test', 'ficticia'),
      throwsA(isA<ExcepcionApi>()),
    );
  });
  test('un ADMIN global no sustituye la propiedad de una red', () {
    final cuenta = CuentaAzure.fromJson({
      ...cuentaFixture(),
      'roles': ['ADMIN'],
    });
    expect(
      RedAzure.fromJson(redFixture(propietario: 2)).esPropietario(cuenta),
      isFalse,
    );
    expect(RedAzure.fromJson(redFixture()).esPropietario(cuenta), isTrue);
  });
  test('lista redes desde el array real', () async {
    respuesta = [redFixture()];
    final redes = await api.redes();
    expect(redes.single.id, 10);
    expect(ultima.url.path, '/api/v1/redes');
    expect(ultima.headers['Authorization'], 'Bearer token-sintetico');
  });
  test(
    'lista dispositivos por red sin utilizar compatibilidad antigua',
    () async {
      respuesta = [equipoFixture()];
      final equipos = await api.dispositivos(10);
      expect(equipos.single.usuarioId, 1);
      expect(ultima.url.path, '/api/v1/redes/10/dispositivos');
    },
  );
  test(
    'registra dispositivo con el DTO confirmado y devuelve ID del servidor',
    () async {
      estado = 201;
      respuesta = equipoFixture();
      final equipo = await api.registrar(
        10,
        const SolicitudDispositivo(
          usuarioId: '1',
          nombre: 'iPhone',
          sistemaOperativo: 'IOS',
        ),
      );
      expect(equipo.id, 20);
      expect(ultima.method, 'POST');
      expect(ultima.url.path, '/api/v1/redes/10/dispositivos');
      expect(jsonDecode(ultima.body), {
        'usuarioId': 1,
        'nombre': 'iPhone',
        'sistemaOperativo': 'IOS',
      });
    },
  );
  test('el SO inválido no envía un alta', () {
    expect(
      () => api.registrar(
        10,
        const SolicitudDispositivo(
          usuarioId: '1',
          nombre: 'iPhone',
          sistemaOperativo: 'OTHER',
        ),
      ),
      throwsA(isA<ExcepcionDispositivos>()),
    );
    expect(llamadas, 0);
  });
  test('202 conserva PENDIENTE y no lo convierte en APLICADA', () async {
    estado = 202;
    respuesta = {
      'id': '00000000-0000-0000-0000-000000000001',
      'estado': 'PENDIENTE',
    };
    final op = await api.solicitar(10, 20);
    expect(op['estado'], 'PENDIENTE');
    expect(ultima.body, isEmpty);
    expect(ultima.url.path, '/api/v1/redes/10/dispositivos/20/configuracion');
  });
  for (final valor in ['FALLIDA', 'CANCELADA', 'EN_PROCESO']) {
    test('conserva el estado real de operación $valor', () async {
      respuesta = {
        'id': '00000000-0000-0000-0000-000000000001',
        'estado': valor,
      };
      expect(
        (await api.operacion(
          10,
          '00000000-0000-0000-0000-000000000001',
        ))['estado'],
        valor,
      );
    });
  }
  test('archivo requiere Bearer, endpoint público y no-cache', () async {
    tipo = 'text/plain';
    respuesta = Uint8List.fromList(
      utf8.encode('[Interface]\nPrivateKey = SINTETICA\n[Peer]'),
    );
    final bytes = await api.archivo(10, 20);
    expect(bytes, isNotEmpty);
    expect(ultima.headers['Accept'], 'text/plain');
    expect(ultima.url.queryParameters, {'endpoint': 'public'});
    expect(ultima.headers['Authorization'], 'Bearer token-sintetico');
    expect(ultima.headers['Cache-Control'], 'no-store');
    bytes.fillRange(0, bytes.length, 0);
  });
  test('QR se pide como PNG autenticado y no con token en la URL', () async {
    tipo = 'image/png';
    respuesta = Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10, 0]);
    expect(await api.qr(10, 20), isNotEmpty);
    expect(
      ultima.url.path,
      '/api/v1/redes/10/dispositivos/20/configuracion/qr',
    );
    expect(ultima.url.queryParameters, {'endpoint': 'public'});
    expect(ultima.url.toString(), isNot(contains('token-sintetico')));
  });
  test('no interpreta JSON de error como archivo de configuración', () async {
    respuesta = {'error': 'SIN_COPIA'};
    await expectLater(api.archivo(10, 20), throwsA(isA<ExcepcionApi>()));
  });
  test('rechaza una respuesta QR sin firma PNG', () async {
    tipo = 'image/png';
    respuesta = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);
    await expectLater(api.qr(10, 20), throwsA(isA<ExcepcionApi>()));
  });
  test('sin sesión no solicita ningún secreto al servidor', () async {
    token = null;
    await expectLater(
      api.archivo(10, 20),
      throwsA(isA<ExcepcionApi>().having((e) => e.estado, 'HTTP', 401)),
    );
    await expectLater(api.qr(10, 20), throwsA(isA<ExcepcionApi>()));
    expect(llamadas, 0);
  });
  for (final status in [401, 403, 404, 409, 503]) {
    test('un rechazo $status no entrega bytes de claves', () async {
      estado = status;
      respuesta = {'error': 'RECHAZADO'};
      await expectLater(
        api.archivo(10, 20),
        throwsA(isA<ExcepcionApi>().having((e) => e.estado, 'HTTP', status)),
      );
      expect(expiraciones, status == 401 ? 1 : 0);
    });
  }
  test('no sigue redirecciones con el token', () async {
    estado = 302;
    await expectLater(api.qr(10, 20), throwsA(isA<ExcepcionApi>()));
    expect(ultima.followRedirects, isFalse);
  });
  test(
    'auditoría usa solo la red seleccionada y conserva paginación del servidor',
    () async {
      respuesta = {
        'page': 0,
        'size': 20,
        'total': 1,
        'items': [
          {'accion': 'ALTA_DISPOSITIVO', 'resultado': 'EXITO', 'objetoId': 20},
        ],
      };
      expect((await api.auditoria(10)).single['objetoId'], 20);
      expect(ultima.url.path, '/api/v1/redes/10/auditoria');
    },
  );
  test(
    'las excepciones y mensajes no reflejan secretos del servidor',
    () async {
      estado = 500;
      respuesta = {'error': 'un texto con un secreto y un token'};
      try {
        await api.archivo(10, 20);
        fail('Debe rechazar');
      } catch (e) {
        expect('$e', isNot(contains('secreto')));
        expect(mensajeSeguro(e), isNot(contains('token')));
      }
    },
  );
}
