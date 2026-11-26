import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import 'dispositivos.dart';
import 'api_error.dart' show ExcepcionApi;

const urlAzure = 'https://nero.northcentralus.cloudapp.azure.com/api/v1';

Map<String, dynamic> objetoJson(Object? valor) {
  if (valor is! Map<String, dynamic>) {
    throw const ExcepcionApi(502, 'RESPUESTA_INVALIDA');
  }
  return valor;
}

List<Map<String, dynamic>> listaJson(Object? valor) {
  if (valor is List) return valor.map(objetoJson).toList();
  final mapa = objetoJson(valor);
  final elementos = mapa['items'] ?? mapa['content'];
  if (elementos is! List) throw const ExcepcionApi(502, 'RESPUESTA_INVALIDA');
  return elementos.map(objetoJson).toList();
}

int idJson(Object? valor) {
  if (valor is int && valor > 0) return valor;
  throw const ExcepcionApi(502, 'RESPUESTA_INVALIDA');
}

class CuentaAzure {
  CuentaAzure.fromJson(Map<String, dynamic> json)
    : id = idJson(json['id']),
      nombre = json['nombre'] as String,
      correo = json['correo'] as String,
      estado = json['estado'] as String,
      permisos = List<String>.unmodifiable((json['permisos'] as List? ?? const []).whereType<String>());
  final int id;
  final String nombre;
  final String correo;
  final String estado;
  final List<String> permisos;
  bool get administraCuentas => permisos.contains('ADMINISTRACION_GLOBAL');
  bool get consultaAuditoria => permisos.contains('AUDITORIA_LEER');
}

class PaginaAzure {
  PaginaAzure({required this.items, required this.pagina, required this.tamano, this.total});
  factory PaginaAzure.fromJson(Object? json, int pagina, int tamano) {
    final items = listaJson(json);
    return PaginaAzure(items: items, pagina: pagina, tamano: tamano,
      total: json is Map && json['total'] is int ? json['total'] as int : null);
  }
  final List<Map<String, dynamic>> items;
  final int pagina, tamano;
  final int? total;
  bool get haySiguiente => total == null ? items.length == tamano : (pagina + 1) * tamano < total!;
}

class RedAzure {
  RedAzure.fromJson(Map<String, dynamic> json)
    : id = idJson(json['id']),
      propietarioId = idJson(json['propietarioId']),
      nombre = json['nombre'] as String,
      estado = json['estado'] as String,
      cidr = json['cidr'] as String?,
      descripcion = json['descripcion'] as String? ?? '',
      version = json['version'] as int?,
      modoTunel = json['modoTunel'] as String?;
  final int id;
  final int propietarioId;
  final String nombre;
  final String estado;
  final String? cidr;
  final String descripcion;
  final int? version;
  final String? modoTunel;
  bool esPropietario(CuentaAzure cuenta) => propietarioId == cuenta.id;
}

class EquipoAzure {
  EquipoAzure.fromJson(Map<String, dynamic> json)
    : id = idJson(json['id']),
      redId = idJson(json['redId']),
      usuarioId = idJson(json['usuarioId']),
      nombre = json['nombre'] as String,
      sistemaOperativo = json['sistemaOperativo'] as String,
      estado = json['estado'] as String,
      version = json['version'] as int?;
  final int id;
  final int redId;
  final int usuarioId;
  final String nombre;
  final String sistemaOperativo;
  final String estado;
  final int? version;
  bool get activo => estado == 'ACTIVO';
}

class AccesoAzure {
  AccesoAzure({
    required this.token,
    required this.cuenta,
    required this.expiraEn,
  });
  final String token;
  final CuentaAzure cuenta;
  final Duration expiraEn;
}

enum AccionRed {
  suspender('suspension', 'Suspender red'),
  reactivar('reactivacion', 'Reactivar red'),
  eliminar('eliminacion', 'Eliminar red'),
  retirarMiembro('retiro', 'Retirar miembro');

  const AccionRed(this.ruta, this.etiqueta);
  final String ruta;
  final String etiqueta;
}

class OperacionAdministrativa {
  OperacionAdministrativa.fromJson(Map<String, dynamic> json, {String? idConsulta, bool aceptada = false})
    : id = uuidAdministrativo(json['id'] ?? json['operacionAdministrativaId'] ?? idConsulta),
      estado = aceptada ? 'PENDIENTE' : (json['estado'] is String ? json['estado'] as String : '') {
    if ((idConsulta != null && id.toLowerCase() != idConsulta.toLowerCase()) ||
        !{'PENDIENTE', 'EN_PROCESO', 'APLICADA', 'FALLIDA'}.contains(estado)) {
      throw const ExcepcionApi(502, 'RESPUESTA_INVALIDA');
    }
  }

  final String id;
  final String estado;
  bool get terminal => estado == 'APLICADA' || estado == 'FALLIDA';
}

String uuidAdministrativo(Object? valor) {
  if (valor is String && RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', caseSensitive: false).hasMatch(valor)) {
    return valor;
  }
  throw const ExcepcionApi(502, 'RESPUESTA_INVALIDA');
}

/// API V3-V6. La propiedad de la red se comprueba otra vez en el servidor.
/// Los perfiles y QR se entregan como bytes; no se registran ni persisten aquí.
class AzureApi {
  AzureApi({
    http.Client? cliente,
    Uri? baseUrl,
    required this.obtenerToken,
    this.alCaducar,
    this.limite = const Duration(seconds: 20),
  }) : _cliente = cliente ?? http.Client(),
       baseUrl = baseUrl ?? _resolverApiConfigurada() {
    final esLocal =
        baseUrl == null &&
        kIsWeb &&
        _apiConfigurada == '/api/v1' &&
        this.baseUrl.scheme == 'http' &&
        this.baseUrl.host == '127.0.0.1';
    if ((this.baseUrl.scheme != 'https' && !esLocal) ||
        this.baseUrl.host.isEmpty ||
        this.baseUrl.userInfo.isNotEmpty ||
        this.baseUrl.hasQuery ||
        this.baseUrl.hasFragment) {
      throw ArgumentError('La API requiere una URL HTTPS sin credenciales.');
    }
  }

  static const _apiConfigurada = String.fromEnvironment(
    'SECURELINK_API_URL',
    defaultValue: urlAzure,
  );

  static Uri _resolverApiConfigurada() => kIsWeb && _apiConfigurada == '/api/v1'
      ? Uri.base.resolve(_apiConfigurada)
      : Uri.parse(_apiConfigurada);
  final http.Client _cliente;
  final Uri baseUrl;
  final String? Function() obtenerToken;
  final void Function()? alCaducar;
  final Duration limite;

  Future<http.Response> _enviar(
    String metodo,
    String ruta, {
    Map<String, Object>? datos,
    Map<String, String>? query,
    bool publica = false,
    bool caducarEn401 = true,
    String acepta = 'application/json',
  }) async {
    final token = publica ? null : obtenerToken();
    if (!publica && (token == null || token.trim().isEmpty)) {
      throw const ExcepcionApi(401, 'SIN_TOKEN');
    }
    final req =
        http.Request(
            metodo,
            baseUrl.replace(
              path: '${baseUrl.path.replaceFirst(RegExp(r'/+$'), '')}/$ruta',
              queryParameters: query,
            ),
          )
          ..followRedirects = false
          ..headers['Accept'] = acepta
          ..headers['Cache-Control'] = 'no-store';
    if (token != null) req.headers['Authorization'] = 'Bearer $token';
    if (datos != null) {
      req.headers['Content-Type'] = 'application/json; charset=utf-8';
      req.body = jsonEncode(datos);
    }
    http.Response respuesta;
    try {
      respuesta = await (() async => http.Response.fromStream(
        await _cliente.send(req),
      ))().timeout(limite);
    } on TimeoutException {
      throw const ExcepcionApi(0, 'TIEMPO_AGOTADO');
    } on http.ClientException {
      throw const ExcepcionApi(0, 'SIN_CONEXION');
    }
    if (respuesta.statusCode < 200 || respuesta.statusCode >= 300) {
      if (respuesta.statusCode == 401 &&
          !publica &&
          caducarEn401 &&
          token == obtenerToken()) {
        alCaducar?.call();
      }
      var codigo = 'HTTP_${respuesta.statusCode}';
      try {
        final error = jsonDecode(utf8.decode(respuesta.bodyBytes));
        final clave = error is Map ? (error['error'] ?? error['codigo']) : null;
        if (clave is String &&
            RegExp(r'^[A-Z][A-Z0-9_]{0,79}$').hasMatch(clave)) {
          codigo = clave;
        }
      } on FormatException {
        /* No se refleja el cuerpo del servidor. */
      }
      throw ExcepcionApi(respuesta.statusCode, codigo);
    }
    return respuesta;
  }

  Future<Object?> _json(
    String metodo,
    String ruta, {
    Map<String, Object>? datos,
    bool publica = false,
    Map<String, String>? query,
  }) async {
    final r = await _enviar(
      metodo,
      ruta,
      datos: datos,
      publica: publica,
      query: query,
    );
    if (r.bodyBytes.isEmpty) return null;
    try {
      return jsonDecode(utf8.decode(r.bodyBytes));
    } on FormatException {
      throw const ExcepcionApi(502, 'RESPUESTA_INVALIDA');
    }
  }

  Future<AccesoAzure> login(String correo, String contrasena) async {
    final json = objetoJson(
      await _json(
        'POST',
        'auth/login',
        publica: true,
        datos: {'correo': correo.trim(), 'contrasena': contrasena},
      ),
    );
    final token = json['accessToken'];
    final segundos = json['expiresIn'];
    if (token is! String ||
        token.isEmpty ||
        segundos is! int ||
        segundos <= 0 ||
        json['tokenType'] is! String ||
        (json['tokenType'] as String).toLowerCase() != 'bearer') {
      throw const ExcepcionApi(502, 'RESPUESTA_INVALIDA');
    }
    final cuenta = CuentaAzure.fromJson(objetoJson(json['usuario']));
    if (cuenta.estado != 'ACTIVO') {
      throw const ExcepcionApi(403, 'USUARIO_INACTIVO');
    }
    return AccesoAzure(
      token: token,
      cuenta: cuenta,
      expiraEn: Duration(seconds: segundos),
    );
  }

  Future<void> logout() async {
    await _json('POST', 'auth/logout');
  }

  Future<void> registrarCuenta(String nombre, String correo, String clave) async {
    await _json(
      'POST',
      'auth/registro',
      publica: true,
      datos: {'nombre': nombre.trim(), 'correo': correo.trim(), 'contrasena': clave},
    );
  }

  Future<CuentaAzure> miPerfil() async =>
      CuentaAzure.fromJson(objetoJson(await _json('GET', 'usuarios/me')));

  Future<void> editarMiPerfil(String nombre, String correo) async {
    await _enviar('POST', 'usuarios/me/perfil', datos: {
      'nombre': nombre.trim(),
      'correo': correo.trim(),
    });
  }

  Future<void> cambiarMiContrasena(String actual, String nueva) async {
    try {
      await _enviar(
        'POST',
        'usuarios/me/contrasena',
        caducarEn401: false,
        datos: {'contrasenaActual': actual, 'contrasenaNueva': nueva},
      );
    } on ExcepcionApi catch (error) {
      if (error.estado != 401) rethrow;
      // Un 401 aquí puede indicar una contraseña incorrecta o un JWT inválido.
      await miPerfil();
      throw const ExcepcionApi(400, 'CONTRASENA_ACTUAL_INCORRECTA');
    }
  }

  Future<List<T>> _listar<T>(String ruta, T Function(Map<String, dynamic>) convertir, int Function(T) id) async {
    const tamano = 20;
    final resultados = <int, T>{};
    for (var pagina = 0; ; pagina++) {
      final anterior = resultados.length;
      final datos = PaginaAzure.fromJson(await _json('GET', ruta, query: {'page': '$pagina', 'size': '$tamano'}), pagina, tamano);
      for (final item in datos.items) {
        final convertido = convertir(item);
        resultados[id(convertido)] = convertido;
      }
      if (!datos.haySiguiente || resultados.length == anterior) return resultados.values.toList();
    }
  }

  Future<List<RedAzure>> redes() => _listar('redes', RedAzure.fromJson, (r) => r.id);
  Future<RedAzure> red(int id) async =>
      RedAzure.fromJson(objetoJson(await _json('GET', 'redes/$id')));
  Future<RedAzure> crearRed(String nombre, {String descripcion = ''}) async => RedAzure.fromJson(
    objetoJson(
      await _json(
        'POST',
        'redes',
        datos: {
          'nombre': nombre.trim(),
          'descripcion': descripcion.trim(),
        },
      ),
    ),
  );
  Future<List<EquipoAzure>> dispositivos(int redId) =>
      _listar('redes/$redId/dispositivos', EquipoAzure.fromJson, (e) => e.id);

  Future<void> editarRed(int redId, String nombre, String descripcion, int version) async {
    await _enviar('POST', 'redes/$redId/edicion', datos: {
      'nombre': nombre.trim(), 'descripcion': descripcion.trim(), 'version': version,
    });
  }

  Future<void> editarDispositivo(int redId, int equipoId, String nombre, String sistemaOperativo, int version) async {
    await _enviar('POST', 'redes/$redId/dispositivos/$equipoId/edicion', datos: {
      'nombre': nombre.trim(), 'sistemaOperativo': sistemaOperativo, 'version': version,
    });
  }

  Future<void> agregarMiembro(int redId, int usuarioId) async {
    await _enviar('POST', 'redes/$redId/miembros', datos: {'usuarioId': usuarioId});
  }

  Future<OperacionAdministrativa> solicitarOperacionRed(int redId, AccionRed accion, {int? usuarioId}) async {
    final ruta = accion == AccionRed.retirarMiembro
        ? 'redes/$redId/miembros/${idJson(usuarioId)}/retiro'
        : 'redes/$redId/${accion.ruta}';
    return OperacionAdministrativa.fromJson(objetoJson(await _json('POST', ruta)), aceptada: true);
  }

  Future<OperacionAdministrativa> consultarOperacionRed(int redId, String id) async {
    final uuid = uuidAdministrativo(id);
    return OperacionAdministrativa.fromJson(
      objetoJson(await _json('GET', 'redes/$redId/operaciones-administrativas/$uuid')), idConsulta: uuid,
    );
  }
  Future<List<Map<String, dynamic>>> miembros(int redId) async =>
      listaJson(await _json('GET', 'redes/$redId/miembros'));
  Future<EquipoAzure> registrar(
    int redId,
    SolicitudDispositivo solicitud,
  ) async => EquipoAzure.fromJson(
    objetoJson(
      await _json(
        'POST',
        'redes/$redId/dispositivos',
        datos: solicitud.toJson(),
      ),
    ),
  );
  Future<Map<String, dynamic>> solicitar(int redId, int equipoId) async =>
      objetoJson(
        await _json(
          'POST',
          'redes/$redId/dispositivos/$equipoId/configuracion',
        ),
      );
  Future<Map<String, dynamic>> operacion(int redId, String uuid) async {
    if (!RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(uuid)) {
      throw const ExcepcionApi(502, 'RESPUESTA_INVALIDA');
    }
    return objetoJson(await _json('GET', 'redes/$redId/operaciones-vpn/$uuid'));
  }

  Future<Map<String, dynamic>> vpn(int redId, int equipoId) async =>
      objetoJson(await _json('GET', 'redes/$redId/dispositivos/$equipoId/vpn'));
  Future<Map<String, dynamic>> conexion(int redId, int equipoId) async =>
      objetoJson(
        await _json('GET', 'redes/$redId/dispositivos/$equipoId/conexion'),
      );
  Future<List<Map<String, dynamic>>> auditoria(int redId) async => listaJson(
    await _json(
      'GET',
      'redes/$redId/auditoria',
      query: {'page': '0', 'size': '20'},
    ),
  );
  Future<PaginaAzure> paginaAuditoria({int? redId, int pagina = 0,
      int? usuarioId, DateTime? desde, DateTime? hasta}) async {
    if (pagina < 0 || (usuarioId != null && usuarioId <= 0)) {
      throw ArgumentError('Filtro inválido');
    }
    return PaginaAzure.fromJson(await _json('GET',
      redId == null ? 'auditoria' : 'redes/$redId/auditoria', query: {
        'page': '$pagina', 'size': '20',
        if (usuarioId != null) 'usuarioId': '$usuarioId',
        if (desde != null) 'desde': desde.toUtc().toIso8601String(),
        if (hasta != null) 'hasta': hasta.toUtc().toIso8601String(),
      }), pagina, 20);
  }

  Future<PaginaAzure> cuentas({int pagina = 0}) async => PaginaAzure.fromJson(
    await _json('GET', 'administracion/usuarios',
      query: {'page': '$pagina', 'size': '20'}), pagina, 20);

  Future<Map<String, dynamic>> cuentaAdministrada(int id) async => objetoJson(
    await _json('GET', 'administracion/usuarios/$id'));

  Future<Map<String, dynamic>> accesosCuenta(int id) async => objetoJson(
    await _json('GET', 'administracion/usuarios/$id/accesos-vpn'));

  Future<Map<String, dynamic>> cambiarEstadoCuenta(int id, String estado) async {
    if (id <= 0 || !['SUSPENDIDO', 'ACTIVO'].contains(estado)) {
      throw ArgumentError('Estado de cuenta inválido');
    }
    return objetoJson(await _json('POST', 'administracion/usuarios/$id/estado',
      datos: {'estado': estado}));
  }

  Future<Map<String, dynamic>> revocar(int redId, int equipoId) async =>
      objetoJson(
        await _json('POST', 'redes/$redId/dispositivos/$equipoId/revocacion'),
      );

  Future<Uint8List> archivo(int redId, int equipoId) async {
    final r = await _enviar(
      'GET',
      'redes/$redId/dispositivos/$equipoId/configuracion',
      query: {'endpoint': 'public'},
      acepta: 'text/plain',
    );
    if (!(r.headers['content-type'] ?? '').toLowerCase().startsWith(
          'text/plain',
        ) ||
        r.bodyBytes.isEmpty ||
        r.bodyBytes.length > 2 * 1024 * 1024) {
      throw const ExcepcionApi(502, 'RESPUESTA_INVALIDA');
    }
    return Uint8List.fromList(r.bodyBytes);
  }

  Future<Uint8List> qr(int redId, int equipoId) async {
    final r = await _enviar(
      'GET',
      'redes/$redId/dispositivos/$equipoId/configuracion/qr',
      query: {'endpoint': 'public'},
      acepta: 'image/png',
    );
    const firma = [137, 80, 78, 71, 13, 10, 26, 10];
    if (!(r.headers['content-type'] ?? '').toLowerCase().startsWith(
          'image/png',
        ) ||
        r.bodyBytes.length < 8 ||
        r.bodyBytes.length > 2 * 1024 * 1024 ||
        List.generate(8, (i) => r.bodyBytes[i] == firma[i]).contains(false)) {
      throw const ExcepcionApi(502, 'RESPUESTA_INVALIDA');
    }
    return Uint8List.fromList(r.bodyBytes);
  }

  void cerrar() => _cliente.close();
}

String mensajeSeguro(Object error) {
  if (error is ExcepcionDispositivos) {
    return 'Revisa los campos obligatorios y el sistema operativo.';
  }
  if (error is ExcepcionApi) {
    if (error.estado == 401) {
      return 'La sesión no es válida o ha caducado. Inicia sesión nuevamente.';
    }
    if (error.estado == 403) return 'No tienes permiso para esta operación.';
    if (error.estado == 404) {
      return 'El recurso no está disponible o no pertenece a tu red.';
    }
    if (error.estado == 409) {
      return 'La operación no está disponible en el estado actual. Actualiza los datos; si falta una copia recuperable, utiliza la reposición del perfil.';
    }
    if (error.estado == 400 || error.estado == 422) {
      return 'El servidor rechazó los datos. Revisa los campos y que el usuario esté activo.';
    }
    if (error.estado == 429) {
      return 'Hay demasiados intentos. Espera antes de volver a intentar.';
    }
    if (error.codigo == 'TIEMPO_AGOTADO') {
      return 'El servidor tardó demasiado. Actualiza el estado antes de repetir un alta.';
    }
    if (error.codigo == 'SIN_CONEXION') {
      return 'No se pudo contactar al servidor. Comprueba la conexión.';
    }
    if (error.estado == 503) {
      return 'El agente o servicio no está disponible. No se ha confirmado la operación.';
    }
  }
  return 'No se pudo completar la operación. Actualiza los datos y vuelve a intentarlo.';
}
