const sistemasOperativosDispositivo = {
  'WINDOWS',
  'ANDROID',
  'IOS',
  'LINUX',
  'MACOS',
};

class SolicitudDispositivo {
  const SolicitudDispositivo({
    required this.usuarioId,
    required this.nombre,
    required this.sistemaOperativo,
  });
  final String usuarioId;
  final String nombre;
  final String sistemaOperativo;

  SolicitudDispositivo validada() {
    if ([usuarioId, nombre, sistemaOperativo].any((v) => v.trim().isEmpty)) {
      throw const ExcepcionDispositivos(MotivoRechazo.campoObligatorio);
    }
    final id = int.tryParse(usuarioId);
    if (id == null || id <= 0) {
      throw const ExcepcionDispositivos(MotivoRechazo.usuarioIdInvalido);
    }
    if (!sistemasOperativosDispositivo.contains(sistemaOperativo)) {
      throw const ExcepcionDispositivos(MotivoRechazo.sistemaOperativoInvalido);
    }
    return SolicitudDispositivo(
      usuarioId: id.toString(),
      nombre: nombre.trim(),
      sistemaOperativo: sistemaOperativo,
    );
  }

  Map<String, Object> toJson() {
    final solicitud = validada();
    return {
      'usuarioId': int.parse(solicitud.usuarioId),
      'nombre': solicitud.nombre,
      'sistemaOperativo': solicitud.sistemaOperativo,
    };
  }
}

enum MotivoRechazo { campoObligatorio, usuarioIdInvalido, sistemaOperativoInvalido }

class ExcepcionDispositivos implements Exception {
  const ExcepcionDispositivos(this.motivo);
  final MotivoRechazo motivo;
  @override
  String toString() => 'ExcepcionDispositivos: ${motivo.name}';
}
