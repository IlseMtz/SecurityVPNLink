import 'package:flutter/material.dart';

/// Presenta datos reportados por la API; no activa el túnel del cliente.
class ResumenVpn extends StatelessWidget {
  const ResumenVpn({
    super.key,
    required this.operacion,
    required this.modo,
    required this.conexion,
  });
  final Map<String, dynamic>? operacion;
  final String? modo;
  final Map<String, dynamic>? conexion;

  Widget tarjeta(String titulo, String detalle, Color color, IconData icono) {
    return Card(
      color: color.withValues(alpha: 0.08),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icono, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(detalle),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final estado = operacion?['estado'];
    final (titulo, detalle, color, icono) = switch (estado) {
      'PENDIENTE' => (
        'Pendiente',
        'Solicitud registrada. Esperando su aplicación.',
        Colors.orange,
        Icons.schedule,
      ),
      'EN_PROCESO' => (
        'En proceso',
        'El servidor está procesando la configuración.',
        Colors.blue,
        Icons.sync,
      ),
      'APLICADA' => (
        'Aplicada',
        'El servidor confirmó la operación. Esto no conecta automáticamente tu computadora.',
        Colors.green,
        Icons.check_circle_outline,
      ),
      'FALLIDA' => (
        'Fallida',
        'El servidor no pudo completar la operación. Solicita a soporte revisar el detalle antes de volver a emitir.',
        Colors.red,
        Icons.error_outline,
      ),
      'CANCELADA' => (
        'Cancelada',
        'La operación fue cancelada. No confirma una nueva configuración aplicada.',
        Colors.grey,
        Icons.cancel_outlined,
      ),
      _ => (
        'Sin confirmar',
        'No se ha confirmado el resultado de la emisión. Consulta el estado antes de repetirla.',
        Colors.orange,
        Icons.help_outline,
      ),
    };
    final modoTexto = switch (modo) {
      'FULL' => 'Full Tunnel: el perfil dirige el tráfico de Internet a través de la VPN cuando lo activas en WireGuard.',
      'SPLIT' => 'Split Tunnel: solo las rutas configuradas deben pasar por la VPN. Verifica las rutas del perfil y el acceso al laboratorio.',
      _ => 'El servidor no informó un modo de túnel reconocido.',
    };
    final ahora = DateTime.now().toUtc();
    DateTime? fecha(String campo) {
      final valor = conexion?[campo];
      return valor is String ? DateTime.tryParse(valor)?.toUtc() : null;
    }

    final handshake = fecha('ultimoHandshake');
    final observado = fecha('observadoEn');
    bool vigente(DateTime? fecha, int segundos) =>
        fecha != null &&
        !fecha.isAfter(ahora) &&
        ahora.difference(fecha) <= Duration(seconds: segundos);
    final actualizado = vigente(observado, 60);
    final actividad =
        conexion?['actividadReciente'] == true &&
        actualizado &&
        vigente(handshake, 180);
    final estadoActividad = actividad
        ? 'Actividad reciente reportada.'
        : 'Sin actividad observada. Sin actividad reciente reportada.';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (operacion != null)
          tarjeta('Emisión: $titulo', detalle, color, icono),
        tarjeta('Modo de túnel', modoTexto, Colors.blue, Icons.alt_route),
        tarjeta(
          'Actividad del dispositivo',
          conexion == null
              ? 'Sin consultar. Una configuración aplicada no demuestra una conexión activa.'
              : '$estadoActividad${actualizado ? '' : ' Desactualizado.'}\n'
                    'Peer presente: ${conexion!['peerPresente'] == true
                        ? 'Sí'
                        : conexion!['peerPresente'] == false
                        ? 'No'
                        : 'Sin informar'}.\n'
                    'Último handshake: ${conexion!['ultimoHandshake'] ?? 'Sin registro'}.\n'
                    'Recibidos: ${conexion!['bytesRecibidos'] ?? '—'} bytes. Enviados: ${conexion!['bytesEnviados'] ?? '—'} bytes.\n'
                    'Observado en: ${conexion!['observadoEn'] ?? 'Sin informar'}.\n'
                    'Esta observación no garantiza acceso al laboratorio.',
          actividad ? Colors.green : Colors.blueGrey,
          Icons.network_check,
        ),
      ],
    );
  }
}
