import 'package:flutter_test/flutter_test.dart';
import 'package:securelink_app/dispositivos.dart';
import 'package:securelink_app/usuarios_page.dart';

// Dobles de infraestructura: no contienen las reglas de negocio bajo prueba.
class RepositorioEnMemoria implements RepositorioDispositivos {
  final usuarios = <String, UsuarioDemo>{};
  final dispositivos = <Dispositivo>[];
  int consultasDispositivos = 0;

  @override
  Future<UsuarioDemo?> obtenerUsuario(String id) async => usuarios[id];

  @override
  Future<List<Dispositivo>> consultarPorUsuario(String usuarioId) async {
    consultasDispositivos++;
    return dispositivos.where((d) => d.usuarioId == usuarioId).toList();
  }

  @override
  Future<Dispositivo?> buscarPorIdentificador(String identificador) async {
    for (final dispositivo in dispositivos) {
      if (dispositivo.identificador == identificador) return dispositivo;
    }
    return null;
  }

  @override
  Future<void> guardar(Dispositivo dispositivo) async {
    dispositivos.add(dispositivo);
  }
}

class AuditoriaEnMemoria implements AuditoriaDispositivos {
  final eventos = <EventoDispositivo>[];

  @override
  Future<void> registrar(EventoDispositivo evento) async {
    eventos.add(evento);
  }
}

UsuarioDemo usuario(String id, {String estado = 'ACTIVO',
    List<String> roles = const ['Usuario VPN']}) => UsuarioDemo(
  id: id,
  nombre: 'Usuario $id',
  correo: '$id@example.test',
  estado: estado,
  roles: roles,
);

Dispositivo dispositivo(String id, String usuarioId,
    {String identificador = 'equipo-001'}) => Dispositivo(
  id: id,
  usuarioId: usuarioId,
  nombre: 'Laptop de trabajo',
  tipo: 'laptop',
  identificador: identificador,
);

Matcher rechaza(MotivoRechazo motivo) => throwsA(
  isA<ExcepcionDispositivos>().having((e) => e.motivo, 'motivo', motivo),
);

void main() {
  late RepositorioEnMemoria repositorio;
  late AuditoriaEnMemoria auditoria;
  late ServicioDispositivos servicio;
  final instante = DateTime.utc(2026, 11, 18, 12);

  setUp(() {
    repositorio = RepositorioEnMemoria();
    repositorio.usuarios.addAll({
      'admin': usuario('admin', roles: ['Administrador']),
      'soporte': usuario('soporte', roles: ['Soporte']),
      'ana': usuario('ana'),
      'luis': usuario('luis'),
      'suspendido': usuario('suspendido', estado: 'SUSPENDIDO'),
      'baja': usuario('baja', estado: 'DADO_DE_BAJA'),
      'admin-inactivo': usuario('admin-inactivo',
          estado: 'SUSPENDIDO', roles: ['Administrador']),
      'sin-rol': usuario('sin-rol', roles: []),
    });
    auditoria = AuditoriaEnMemoria();
    servicio = ServicioDispositivos(
      repositorio: repositorio,
      auditoria: auditoria,
      ahora: () => instante,
    );
  });

  Future<Dispositivo> registrar({
    String? actorId = 'admin',
    String usuarioId = 'ana',
    String nombre = 'Laptop de trabajo',
    String tipo = 'laptop',
    String identificador = 'equipo-001',
  }) => servicio.registrar(
    actorId: actorId,
    usuarioId: usuarioId,
    nombre: nombre,
    tipo: tipo,
    identificador: identificador,
  );

  void verificarAuditoria({
    required AccionDispositivo accion,
    required ResultadoAuditoria resultado,
    String? actorId = 'admin',
    String usuarioId = 'ana',
    String? dispositivoId,
    MotivoRechazo? motivo,
  }) {
    expect(auditoria.eventos, hasLength(1),
        reason: 'Cada operación debe producir exactamente un evento.');
    final evento = auditoria.eventos.single;
    expect(evento.accion, accion);
    expect(evento.resultado, resultado);
    expect(evento.actorId, actorId);
    expect(evento.usuarioId, usuarioId);
    expect(evento.dispositivoId, dispositivoId);
    expect(evento.motivo, motivo);
    expect(evento.fecha, instante);
  }

  group('Registro válido', () {
    for (final tipo in ['laptop', 'escritorio', 'movil', 'tablet']) {
      test('administrador registra $tipo para usuario activo', () async {
        final creado = await registrar(tipo: tipo);
        expect(creado.id, isNotEmpty);
        expect(creado.usuarioId, 'ana');
        expect(creado.nombre, 'Laptop de trabajo');
        expect(creado.tipo, tipo);
        expect(creado.identificador, 'equipo-001');
        expect(repositorio.dispositivos, hasLength(1));
        final guardado = repositorio.dispositivos.single;
        expect(guardado.id, creado.id);
        expect(guardado.usuarioId, creado.usuarioId);
        expect(guardado.nombre, creado.nombre);
        expect(guardado.tipo, creado.tipo);
        expect(guardado.identificador, creado.identificador);
      });
    }

    test('normaliza espacios y el identificador antes de guardar', () async {
      final creado = await registrar(nombre: '  Laptop de trabajo  ',
          identificador: '  EQUIPO-001  ');
      expect(creado.nombre, 'Laptop de trabajo');
      expect(creado.identificador, 'equipo-001');
      expect(repositorio.dispositivos.single.identificador, 'equipo-001');
    });

    test('dos altas diferentes conservan ambos dispositivos con ids únicos', () async {
      final primero = await registrar();
      final segundo = await registrar(identificador: 'equipo-002');
      expect(primero.id, isNotEmpty);
      expect(segundo.id, isNotEmpty);
      expect(segundo.id, isNot(primero.id));
      expect(repositorio.dispositivos, hasLength(2));
    });

    test('el alta queda disponible en una consulta posterior', () async {
      final creado = await registrar();
      final encontrados = await servicio.consultar(actorId: 'admin', usuarioId: 'ana');
      expect(encontrados.map((d) => d.id), [creado.id]);
    });

    test('audita alta con actor, propietario, dispositivo y fecha', () async {
      final creado = await registrar();
      verificarAuditoria(accion: AccionDispositivo.registrar,
          resultado: ResultadoAuditoria.exito, dispositivoId: creado.id);
    });
  });

  group('Validación de campos', () {
    for (final campo in ['usuarioId', 'nombre', 'tipo', 'identificador']) {
      for (final valor in ['', '   ']) {
        test('rechaza $campo ${valor.isEmpty ? 'vacío' : 'con espacios'} sin guardar y audita', () async {
          await expectLater(registrar(
            usuarioId: campo == 'usuarioId' ? valor : 'ana',
            nombre: campo == 'nombre' ? valor : 'Laptop de trabajo',
            tipo: campo == 'tipo' ? valor : 'laptop',
            identificador: campo == 'identificador' ? valor : 'equipo-001',
          ), rechaza(MotivoRechazo.campoObligatorio));
          expect(repositorio.dispositivos, isEmpty);
          verificarAuditoria(accion: AccionDispositivo.registrar,
              resultado: ResultadoAuditoria.rechazo,
              usuarioId: campo == 'usuarioId' ? valor : 'ana',
              motivo: MotivoRechazo.campoObligatorio);
        });
      }
    }

    test('rechaza un tipo no permitido y audita', () async {
      await expectLater(registrar(tipo: 'desconocido'), rechaza(MotivoRechazo.tipoInvalido));
      expect(repositorio.dispositivos, isEmpty);
      verificarAuditoria(accion: AccionDispositivo.registrar,
          resultado: ResultadoAuditoria.rechazo, motivo: MotivoRechazo.tipoInvalido);
    });

    for (final propietario in ['ana', 'luis']) {
      test('rechaza identificador duplicado perteneciente a $propietario', () async {
        repositorio.dispositivos.add(dispositivo('existente', propietario));
        await expectLater(registrar(identificador: ' EQUIPO-001 '),
            rechaza(MotivoRechazo.identificadorDuplicado));
        expect(repositorio.dispositivos, hasLength(1));
        expect(repositorio.dispositivos.single.id, 'existente');
        expect(repositorio.dispositivos.single.usuarioId, propietario);
        verificarAuditoria(accion: AccionDispositivo.registrar,
            resultado: ResultadoAuditoria.rechazo,
            motivo: MotivoRechazo.identificadorDuplicado);
      });
    }
  });

  group('Propietario del dispositivo', () {
    final casos = <String, MotivoRechazo>{
      'no-existe': MotivoRechazo.usuarioNoExiste,
      'suspendido': MotivoRechazo.usuarioInactivo,
      'baja': MotivoRechazo.usuarioInactivo,
    };
    for (final caso in casos.entries) {
      test('rechaza alta para ${caso.key} y audita', () async {
        await expectLater(registrar(usuarioId: caso.key), rechaza(caso.value));
        expect(repositorio.dispositivos, isEmpty);
        verificarAuditoria(accion: AccionDispositivo.registrar,
            resultado: ResultadoAuditoria.rechazo,
            usuarioId: caso.key, motivo: caso.value);
      });

      test('rechaza consulta para ${caso.key} sin leer dispositivos y audita', () async {
        repositorio.dispositivos.add(dispositivo('previo', caso.key));
        await expectLater(servicio.consultar(actorId: 'admin', usuarioId: caso.key),
            rechaza(caso.value));
        expect(repositorio.consultasDispositivos, 0);
        expect(repositorio.dispositivos.single.id, 'previo');
        verificarAuditoria(accion: AccionDispositivo.consultar,
            resultado: ResultadoAuditoria.rechazo,
            usuarioId: caso.key, motivo: caso.value);
      });
    }
  });

  group('Permisos de registro', () {
    final casos = <String?, MotivoRechazo>{
      null: MotivoRechazo.sinSesion,
      'intruso': MotivoRechazo.sinSesion,
      'admin-inactivo': MotivoRechazo.actorInactivo,
      'soporte': MotivoRechazo.sinPermiso,
      'ana': MotivoRechazo.sinPermiso,
      'sin-rol': MotivoRechazo.sinPermiso,
    };
    for (final caso in casos.entries) {
      test('rechaza alta por ${caso.key ?? 'sesión ausente'} y audita', () async {
        await expectLater(registrar(actorId: caso.key), rechaza(caso.value));
        expect(repositorio.dispositivos, isEmpty);
        verificarAuditoria(accion: AccionDispositivo.registrar,
            resultado: ResultadoAuditoria.rechazo,
            actorId: caso.key, motivo: caso.value);
      });
    }
  });

  group('Consulta válida', () {
    for (final actor in ['admin', 'soporte', 'ana']) {
      test('$actor consulta solo los dispositivos del propietario solicitado', () async {
        repositorio.dispositivos.addAll([
          dispositivo('ana-1', 'ana'),
          dispositivo('ana-2', 'ana', identificador: 'equipo-002'),
          dispositivo('luis-1', 'luis', identificador: 'equipo-003'),
        ]);
        final encontrados = await servicio.consultar(actorId: actor, usuarioId: 'ana');
        expect(encontrados.map((d) => d.id), unorderedEquals(['ana-1', 'ana-2']));
        expect(encontrados.every((d) => d.usuarioId == 'ana'), isTrue);
        expect(repositorio.dispositivos, hasLength(3));
        verificarAuditoria(accion: AccionDispositivo.consultar,
            resultado: ResultadoAuditoria.exito, actorId: actor);
      });
    }

    test('usuario activo sin dispositivos obtiene lista vacía y genera auditoría', () async {
      repositorio.dispositivos.add(dispositivo('de-otro', 'luis'));
      final encontrados = await servicio.consultar(actorId: 'admin', usuarioId: 'ana');
      expect(encontrados, isEmpty);
      expect(repositorio.dispositivos, hasLength(1));
      verificarAuditoria(accion: AccionDispositivo.consultar,
          resultado: ResultadoAuditoria.exito);
    });

    test('revocar el estado activo impide consultas de dispositivos ya registrados', () async {
      repositorio.dispositivos.add(dispositivo('ana-1', 'ana'));
      await servicio.consultar(actorId: 'admin', usuarioId: 'ana');
      auditoria.eventos.clear();
      repositorio.consultasDispositivos = 0;
      repositorio.usuarios['ana'] = usuario('ana', estado: 'SUSPENDIDO');
      await expectLater(servicio.consultar(actorId: 'admin', usuarioId: 'ana'),
          rechaza(MotivoRechazo.usuarioInactivo));
      expect(repositorio.consultasDispositivos, 0);
      expect(repositorio.dispositivos.single.id, 'ana-1');
      verificarAuditoria(accion: AccionDispositivo.consultar,
          resultado: ResultadoAuditoria.rechazo, motivo: MotivoRechazo.usuarioInactivo);
    });
  });

  group('Permisos y campos de consulta', () {
    final casos = <String?, MotivoRechazo>{
      null: MotivoRechazo.sinSesion,
      'intruso': MotivoRechazo.sinSesion,
      'admin-inactivo': MotivoRechazo.actorInactivo,
      'luis': MotivoRechazo.sinPermiso,
      'sin-rol': MotivoRechazo.sinPermiso,
    };
    for (final caso in casos.entries) {
      test('rechaza consulta por ${caso.key ?? 'sesión ausente'} sin exponer dispositivos', () async {
        repositorio.dispositivos.add(dispositivo('privado', 'ana'));
        await expectLater(servicio.consultar(actorId: caso.key, usuarioId: 'ana'),
            rechaza(caso.value));
        expect(repositorio.consultasDispositivos, 0);
        expect(repositorio.dispositivos.single.id, 'privado');
        verificarAuditoria(accion: AccionDispositivo.consultar,
            resultado: ResultadoAuditoria.rechazo,
            actorId: caso.key, motivo: caso.value);
      });
    }

    for (final valor in ['', '   ']) {
      test('rechaza consulta con propietario ${valor.isEmpty ? 'vacío' : 'con espacios'}', () async {
        await expectLater(servicio.consultar(actorId: 'admin', usuarioId: valor),
            rechaza(MotivoRechazo.campoObligatorio));
        expect(repositorio.consultasDispositivos, 0);
        verificarAuditoria(accion: AccionDispositivo.consultar,
            resultado: ResultadoAuditoria.rechazo, usuarioId: valor,
            motivo: MotivoRechazo.campoObligatorio);
      });
    }
  });
}
