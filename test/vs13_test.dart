import 'package:flutter_test/flutter_test.dart';
import '../lib/vs13.dart';

// Doble de prueba. No contacta servidores ni usa WireGuard real.
class AgentePrueba implements AgenteConfiguracionVPN {
  @override
  bool disponible = true;
  bool confirmar = true;
  final List<ConfiguracionVPN> recibidas = [];

  @override
  bool aplicar(ConfiguracionVPN configuracion) {
    recibidas.add(configuracion);
    return confirmar;
  }
}

const equipo1 = DispositivoVPN(
  id: 'equipo-1', autorizado: true, usuarioActivo: true,
);
const equipo2 = DispositivoVPN(
  id: 'equipo-2', autorizado: true, usuarioActivo: true,
);
const noAutorizado = DispositivoVPN(
  id: 'equipo-3', autorizado: false, usuarioActivo: true,
);
const suspendido = DispositivoVPN(
  id: 'equipo-4', autorizado: true, usuarioActivo: false,
);

// Datos sintéticos: no son configuraciones listas para conectar.
const rutasPrueba = ['10.20.0.0/24', '10.21.0.0/24'];
const clavePrueba = 'clave-publica-de-prueba';
const endpointPrueba = 'vpn.example.test:51820';

ConfiguracionVPN configuracionPrueba({
  String ip = '10.8.0.2',
  String clave = clavePrueba,
  String endpoint = endpointPrueba,
  EstadoConfiguracion estado = EstadoConfiguracion.pendiente,
}) => ConfiguracionVPN(
  dispositivoId: equipo1.id,
  ip: ip,
  clavePublica: clave,
  endpoint: endpoint,
  modo: ModoConexion.splitTunnel,
  rutas: rutasPrueba,
  estado: estado,
);

void main() {
  group('CRC 1 - MonitorEstadoVPN', () {
    late AgentePrueba agente;
    late List<String> avisos;
    late MonitorEstadoVPN monitor;

    setUp(() {
      agente = AgentePrueba();
      avisos = <String>[];
      monitor = MonitorEstadoVPN(agente: agente, notificar: avisos.add);
    });

    test('CP-45 Consulta configuracion pendiente', () {
      expect(monitor.consultarEstado(configuracionPrueba()),
          EstadoConfiguracion.pendiente);
    });

    test('CP-46 Reporta aplicada solo despues de confirmacion', () {
      final estado = monitor.determinarEstado(
        configuracionPrueba(), confirmacion: true,
      );
      expect(estado, EstadoConfiguracion.aplicada);
      expect(monitor.consultarEstado(configuracionPrueba(
        estado: EstadoConfiguracion.aplicada,
      )), EstadoConfiguracion.aplicada);
    });

    test('CP-47 Detecta aplicacion fallida', () {
      final estado = monitor.determinarEstado(
        configuracionPrueba(), confirmacion: false,
      );
      expect(estado, EstadoConfiguracion.fallida);
      expect(monitor.consultarEstado(configuracionPrueba(
        estado: EstadoConfiguracion.fallida,
      )), EstadoConfiguracion.fallida);
    });

    test('CP-48 Detecta indisponibilidad del agente local', () {
      agente.disponible = false;
      expect(monitor.agenteDisponible(), isFalse);
      agente.disponible = true;
      expect(monitor.agenteDisponible(), isTrue);
    });

    test('CP-49 Sin confirmacion conserva estado pendiente', () {
      agente.disponible = false;
      final estado = monitor.determinarEstado(
        configuracionPrueba(), confirmacion: null,
      );
      expect(estado, EstadoConfiguracion.pendiente);
    });

    test('CP-50 Detecta intento de usuario suspendido', () {
      expect(monitor.detectarIntentoSuspendido(suspendido), isTrue);
    });

    test('CP-51 Usuario activo no genera alerta de suspension', () {
      expect(monitor.detectarIntentoSuspendido(equipo1), isFalse);
    });

    test('CP-52 Informa agotamiento de IP al administrador', () {
      monitor.informarAgotamientoIP(sinIps: false);
      expect(avisos, isEmpty);
      monitor.informarAgotamientoIP(sinIps: true);
      expect(avisos, hasLength(1));
      expect(avisos.single.trim(), isNotEmpty);
      expect(avisos.single.toLowerCase(), contains('ip'));
    });
  });

  group('CRC 2 - GeneradorConfiguracionVPN', () {
    late AgentePrueba agente;
    late List<String> solicitudesIP;
    late GeneradorConfiguracionVPN generador;

    setUp(() {
      agente = AgentePrueba();
      solicitudesIP = <String>[];
      final ips = {'equipo-1': '10.8.0.2', 'equipo-2': '10.8.0.3'};
      generador = GeneradorConfiguracionVPN(
        agente: agente,
        asignarIP: (id) {
          solicitudesIP.add(id);
          if (!ips.containsKey(id)) {
            throw StateError('Dispositivo sin IP de prueba');
          }
          return ips[id]!;
        },
      );
    });

    ConfiguracionVPN generar(DispositivoVPN dispositivo) => generador.generar(
      dispositivo: dispositivo,
      clavePublica: clavePrueba,
      endpoint: endpointPrueba,
      rutasLaboratorio: rutasPrueba,
    );

    test('CP-53 Genera configuracion de un dispositivo autorizado', () {
      final config = generar(equipo1);
      expect(config.dispositivoId, equipo1.id);
      expect(config.clavePublica, clavePrueba);
      expect(config.endpoint, endpointPrueba);
      expect(config.estado, EstadoConfiguracion.pendiente);
    });

    test('CP-54 Rechaza dispositivo no autorizado o usuario suspendido', () {
      expect(() => generar(noAutorizado), throwsStateError);
      expect(() => generar(suspendido), throwsStateError);
      expect(solicitudesIP, isEmpty);
      expect(agente.recibidas, isEmpty);
    });

    test('CP-55 Incorpora direcciones IP unicas del asignador', () {
      final config1 = generar(equipo1);
      final config2 = generar(equipo2);
      expect(config1.ip, '10.8.0.2');
      expect(config2.ip, '10.8.0.3');
      expect(config1.ip, isNot(equals(config2.ip)));
      expect(solicitudesIP, [equipo1.id, equipo2.id]);
    });

    test('CP-56 Establece modo Split Tunnel', () {
      expect(generar(equipo1).modo, ModoConexion.splitTunnel);
    });

    test('CP-57 Incluye solo las rutas del laboratorio solicitadas', () {
      final config = generar(equipo1);
      expect(config.rutas, unorderedEquals(rutasPrueba));
      expect(config.rutas, isNot(contains('0.0.0.0/0')));
    });

    test('CP-58 Valida parametros obligatorios de la configuracion', () {
      expect(generador.validar(configuracionPrueba()), isTrue);
      expect(generador.validar(configuracionPrueba(ip: '')), isFalse);
      expect(generador.validar(configuracionPrueba(clave: '')), isFalse);
      expect(generador.validar(configuracionPrueba(endpoint: '')), isFalse);
    });

    test('CP-59 Entrega configuracion valida al agente local', () {
      final config = configuracionPrueba();
      expect(generador.entregar(config), isTrue);
      expect(agente.recibidas, hasLength(1));
      expect(agente.recibidas.single, same(config));
    });

    test('CP-60 Rechaza configuracion invalida sin invocar al agente', () {
      final config = configuracionPrueba(endpoint: '');
      expect(() => generador.entregar(config), throwsArgumentError);
      expect(agente.recibidas, isEmpty);
    });
  });
}
