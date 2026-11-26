import 'package:flutter/material.dart';

import 'api_error.dart';
import 'azure_api.dart';

class LimitesRedDialog extends StatefulWidget {
  const LimitesRedDialog({super.key, required this.api, required this.red});

  final AzureApi api;
  final RedAzure red;

  @override
  State<LimitesRedDialog> createState() => _LimitesRedDialogState();
}

class _LimitesRedDialogState extends State<LimitesRedDialog> {
  late Future<LimitesRed> carga = widget.api.limitesRed(widget.red.id);
  int? seleccionado;
  bool guardando = false;
  String? error;

  Future<void> guardar(LimitesRed actual, int limite) async {
    setState(() {
      guardando = true;
      error = null;
    });
    try {
      await widget.api.actualizarLimitesRed(
        widget.red.id,
        limite,
        actual.version,
      );
      if (mounted) Navigator.pop(context);
    } on ExcepcionApi catch (e) {
      if (!mounted) return;
      setState(() {
        error = switch (e.codigo) {
          'VERSION_DESACTUALIZADA' => 'La red cambió. Recarga sus límites.',
          'LIMITE_INFERIOR_A_OCUPACION' =>
            'El límite es inferior a los cupos usados por un miembro.',
          _ => 'No se pudieron guardar los límites.',
        };
      });
    } finally {
      if (mounted) setState(() => guardando = false);
    }
  }

  void recargar() => setState(() {
    error = null;
    seleccionado = null;
    carga = widget.api.limitesRed(widget.red.id);
  });

  @override
  Widget build(BuildContext context) => FutureBuilder<LimitesRed>(
    future: carga,
    builder: (context, snapshot) {
      final datos = snapshot.connectionState == ConnectionState.done
          ? snapshot.data
          : null;
      final limite = seleccionado ?? datos?.limiteEquiposUsuario;
      return AlertDialog(
        title: const Text('Límites de la red'),
        scrollable: true,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Modalidad actual · ${widget.red.modoTunel ?? "Sin datos"}'),
            if (snapshot.connectionState != ConnectionState.done)
              const LinearProgressIndicator()
            else if (datos == null)
              const Text(
                'No se pudieron consultar los límites en este servidor.',
              )
            else ...[
              const Text('Hasta cinco dispositivos por red.'),
              DropdownButtonFormField<int>(
                key: ValueKey(datos.version),
                initialValue: datos.limiteEquiposUsuario,
                decoration: const InputDecoration(
                  labelText: 'Dispositivos por usuario',
                ),
                onChanged: guardando
                    ? null
                    : (valor) => setState(() => seleccionado = valor),
                items: [
                  for (var n = 1; n <= 5; n++)
                    DropdownMenuItem(value: n, child: Text('$n')),
                ],
              ),
              const SizedBox(height: 12),
              if (datos.ocupadosPorUsuario.isEmpty)
                const Text('Sin cupos ocupados.')
              else
                for (final uso in datos.ocupadosPorUsuario.entries)
                  Text('Usuario ${uso.key} · ${uso.value} dispositivos'),
            ],
            if (error != null) Text(error!),
          ],
        ),
        actions: [
          if (snapshot.hasError || error != null)
            TextButton(
              onPressed: guardando ? null : recargar,
              child: const Text('Recargar'),
            ),
          TextButton(
            onPressed: guardando ? null : () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
          if (datos != null && limite != null)
            FilledButton(
              onPressed: guardando || limite == datos.limiteEquiposUsuario
                  ? null
                  : () => guardar(datos, limite),
              child: const Text('Guardar'),
            ),
        ],
      );
    },
  );
}
