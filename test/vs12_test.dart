import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import '../lib/vs12.dart';

// Doble de pruebas: no ejecuta comandos, no usa red ni WireGuard real.
class WireGuardSimulado implements AdaptadorWireGuard {
  final Set<String> peers = <String>{};
  int altas = 0;

  @override
  Set<String> obtenerPeers() => Set<String>.of(peers);

  @override
  void agregarPeer(String id) {
    altas++;
    peers.add(id);
  }

  @override
  void eliminarPeer(String id) {
    peers.remove(id);
  }
}

Map<String, Object?> esquemaInicial() => <String, Object?>{
      'version': 1,
      'tablas': <String>['usuarios'],
      'usuarios': <String>['usuario-1', 'usuario-2'],
    };

Map<String, Object?> esquemaMigrado() => <String, Object?>{
      'version': 2,
      'tablas': <String>['usuarios', 'dispositivos', 'configuraciones_vpn'],
      'usuarios': <String>['usuario-1', 'usuario-2'],
    };

void main() {
  group('CRC 1 - MigracionDispositivo', () {
    test('CP-25 Crea las tablas de dispositivos y configuraciones VPN', () {
      final resultado = MigracionDispositivo().migrar(esquemaInicial());
      expect(resultado['tablas'],
          containsAll(['usuarios', 'dispositivos', 'configuraciones_vpn']));
    });

    test('CP-26 Conserva las identidades de usuarios existentes', () {
      final inicial = esquemaInicial();
      final resultado = MigracionDispositivo().migrar(inicial);
      expect(resultado['usuarios'], ['usuario-1', 'usuario-2']);
    });

    test('CP-27 Registra la nueva version del esquema', () {
      final resultado = MigracionDispositivo().migrar(esquemaInicial());
      expect(resultado['version'], 2);
    });

    test('CP-28 Revierte la migracion sin perder usuarios', () {
      final resultado = MigracionDispositivo().revertir(esquemaMigrado());
      expect(resultado['version'], 1);
      expect(resultado['tablas'], ['usuarios']);
      expect(resultado['usuarios'], ['usuario-1', 'usuario-2']);
    });
  });

  group('CRC 2 - AsignadorIP', () {
    late AsignadorIP asignador;

    setUp(() {
      asignador = AsignadorIP(['10.0.0.2', '10.0.0.3']);
    });

    test('CP-29 Asigna una IP disponible a un dispositivo autorizado', () {
      final ip = asignador.asignar('equipo-1', autorizado: true);
      expect(ip, isIn(['10.0.0.2', '10.0.0.3']));
    });

    test('CP-30 Evita direcciones IP duplicadas', () {
      final ip1 = asignador.asignar('equipo-1', autorizado: true);
      final ip2 = asignador.asignar('equipo-2', autorizado: true);
      expect(ip1, isNot(equals(ip2)));
      expect([ip1, ip2], unorderedEquals(['10.0.0.2', '10.0.0.3']));
    });

    test('CP-31 Rechaza dispositivos no autorizados', () {
      expect(() => asignador.asignar('equipo-1', autorizado: false),
          throwsA(isA<StateError>()));
      expect(asignador.asignaciones, isEmpty);
    });

    test('CP-32 Detecta el agotamiento de direcciones IP', () {
      asignador.asignar('equipo-1', autorizado: true);
      asignador.asignar('equipo-2', autorizado: true);
      expect(() => asignador.asignar('equipo-3', autorizado: true),
          throwsA(isA<StateError>()));
      expect(asignador.asignaciones, hasLength(2));
    });

    test('CP-33 Conserva el registro de direcciones asignadas', () {
      final ip = asignador.asignar('equipo-1', autorizado: true);
      expect(asignador.asignaciones, {'equipo-1': ip});
    });
  });

  group('CRC 3 - PersistenciaLocal', () {
    late Directory temporal;
    late String ruta;
    late PersistenciaLocal persistencia;

    setUp(() {
      temporal = Directory.systemTemp.createTempSync('vs12_red_');
      ruta = '${temporal.path}${Platform.pathSeparator}estado.json';
      persistencia = PersistenciaLocal(ruta);
    });

    tearDown(() {
      if (temporal.existsSync()) temporal.deleteSync(recursive: true);
    });

    test('CP-34 Guarda los peers de la VPN', () {
      persistencia.guardarPeer('peer-1', activo: true);
      expect(persistencia.obtenerPeers(), {'peer-1': true});
    });

    test('CP-35 Almacena el historial de operaciones', () {
      persistencia.registrarOperacion('aplicar:peer-1');
      expect(persistencia.obtenerOperaciones(), ['aplicar:peer-1']);
    });

    test('CP-36 Recupera peers desde una nueva instancia', () {
      persistencia.guardarPeer('peer-1', activo: true);
      persistencia.guardarPeer('peer-2', activo: false);
      expect(File(ruta).existsSync(), isTrue);
      final reiniciada = PersistenciaLocal(ruta);
      expect(reiniciada.obtenerPeers(), {'peer-1': true, 'peer-2': false});
    });

    test('CP-37 Actualiza peers sin generar duplicados', () {
      persistencia.guardarPeer('peer-1', activo: true);
      persistencia.guardarPeer('peer-1', activo: false);
      expect(persistencia.obtenerPeers(), {'peer-1': false});
    });

    test('CP-38 Recupera historial desde una nueva instancia', () {
      persistencia.registrarOperacion('aplicar:peer-1');
      persistencia.registrarOperacion('revocar:peer-1');
      expect(File(ruta).existsSync(), isTrue);
      final reiniciada = PersistenciaLocal(ruta);
      expect(reiniciada.obtenerOperaciones(),
          ['aplicar:peer-1', 'revocar:peer-1']);
    });
  });

  group('CRC 4 - AgenteLocal', () {
    late WireGuardSimulado wireGuard;
    late AgenteLocal agente;

    setUp(() {
      wireGuard = WireGuardSimulado();
      agente = AgenteLocal(wireGuard);
    });

    test('CP-39 Aplica una configuracion autorizada y reporta el resultado', () {
      final resultado = agente.aplicar('peer-1', autorizado: true);
      expect(resultado, 'aplicada');
      expect(wireGuard.obtenerPeers(), {'peer-1'});
    });

    test('CP-40 Rechaza operaciones no autorizadas sin cambiar los peers', () {
      wireGuard.peers.add('peer-existente');
      expect(() => agente.aplicar('peer-1', autorizado: false),
          throwsA(isA<StateError>()));
      expect(() => agente.revocar('peer-existente', autorizado: false),
          throwsA(isA<StateError>()));
      expect(wireGuard.obtenerPeers(), {'peer-existente'});
      expect(wireGuard.altas, 0);
    });

    test('CP-41 Revoca un peer autorizado y reporta el resultado', () {
      wireGuard.peers.add('peer-1');
      final resultado = agente.revocar('peer-1', autorizado: true);
      expect(resultado, 'revocada');
      expect(wireGuard.obtenerPeers(), isEmpty);
    });

    test('CP-42 Recupera peers activos despues de un reinicio simulado', () {
      agente.reconciliar({'peer-1': true, 'peer-2': true});
      expect(wireGuard.obtenerPeers(), {'peer-1', 'peer-2'});
    });

    test('CP-43 Reconcilia sin duplicar peers ni repetir altas', () {
      wireGuard.peers.add('peer-1');
      agente.reconciliar({'peer-1': true, 'peer-2': true});
      agente.reconciliar({'peer-1': true, 'peer-2': true});
      expect(wireGuard.obtenerPeers(), {'peer-1', 'peer-2'});
      expect(wireGuard.altas, 1);
    });

    test('CP-44 No restaura peers revocados y elimina los revocados presentes', () {
      wireGuard.peers.add('peer-2');
      agente.reconciliar({'peer-1': true, 'peer-2': false, 'peer-3': false});
      expect(wireGuard.obtenerPeers(), {'peer-1'});
      expect(wireGuard.altas, 1);
    });
  });
}
