import 'dart:async';

import 'package:flutter/material.dart';

import 'api_error.dart';
import 'azure_api.dart';
import 'dispositivos.dart';

typedef DatosRed = ({String nombre, String descripcion});
typedef DatosEquipo = ({String nombre, String sistemaOperativo});

String errorAdministracion(Object e) =>
    e is ExcepcionApi && e.estado == 409 && e.codigo == 'VERSION_SUPERADA'
    ? 'Los datos cambiaron. Actualiza la red y vuelve a editar con la versión vigente.'
    : mensajeSeguro(e);

class FormularioRed extends StatelessWidget {
  const FormularioRed({super.key, this.red});
  final RedAzure? red;

  @override
  Widget build(BuildContext context) {
    var nombre = red?.nombre ?? '';
    var descripcion = red?.descripcion ?? '';
    return _Formulario<DatosRed>(
      titulo: red == null ? 'Crear red' : 'Editar red',
      boton: red == null ? 'Crear' : 'Guardar cambios',
      valor: () => (nombre: nombre.trim(), descripcion: descripcion.trim()),
      campos: [
        _nombre('Nombre de la red', nombre, (v) => nombre = v),
        TextFormField(
          initialValue: descripcion,
          decoration: const InputDecoration(labelText: 'Descripción'),
          maxLines: 3,
          onSaved: (v) => descripcion = v ?? '',
        ),
      ],
    );
  }
}

class FormularioEquipo extends StatelessWidget {
  const FormularioEquipo({super.key, required this.equipo});
  final EquipoAzure equipo;

  @override
  Widget build(BuildContext context) {
    var nombre = equipo.nombre;
    String? so = sistemasOperativosDispositivo.contains(equipo.sistemaOperativo)
        ? equipo.sistemaOperativo
        : null;
    return _Formulario<DatosEquipo>(
      titulo: 'Editar dispositivo',
      boton: 'Guardar cambios',
      valor: () => (nombre: nombre.trim(), sistemaOperativo: so!),
      campos: [
        _nombre('Nombre del dispositivo', nombre, (v) => nombre = v),
        DropdownButtonFormField<String>(
          initialValue: so,
          decoration: const InputDecoration(labelText: 'Sistema operativo'),
          items: [
            for (final sistema in sistemasOperativosDispositivo)
              DropdownMenuItem(value: sistema, child: Text(sistema)),
          ],
          onChanged: (_) {},
          onSaved: (v) => so = v,
          validator: (v) =>
              v == null ? 'Selecciona el sistema operativo.' : null,
        ),
      ],
    );
  }
}

TextFormField _nombre(
  String etiqueta,
  String inicial,
  ValueChanged<String> cambio,
) => TextFormField(
  initialValue: inicial,
  decoration: InputDecoration(labelText: etiqueta),
  maxLength: 100,
  onSaved: (v) => cambio(v ?? ''),
  validator: (v) => (v ?? '').trim().isEmpty ? 'Escribe un nombre.' : null,
);

class _Formulario<T> extends StatelessWidget {
  _Formulario({
    required this.titulo,
    required this.boton,
    required this.valor,
    required this.campos,
  });
  final String titulo, boton;
  final T Function() valor;
  final List<Widget> campos;
  final formulario = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(titulo),
    content: SingleChildScrollView(
      child: SizedBox(
        width: 390,
        child: Form(
          key: formulario,
          child: Column(mainAxisSize: MainAxisSize.min, children: campos),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () {
          if (formulario.currentState!.validate()) {
            formulario.currentState!.save();
            Navigator.pop(context, valor());
          }
        },
        child: Text(boton),
      ),
    ],
  );
}

/// Se conserva al cerrar el diálogo, de modo que reabrirlo no repita el POST.
class SeguimientoRed {
  SeguimientoRed(this.red);

  RedAzure red;
  AccionRed? accion;
  int? usuarioId;
  OperacionAdministrativa? operacion;
  bool get bloqueada => accion != null && operacion?.estado != 'APLICADA';
}

class AdministrarRedDialog extends StatefulWidget {
  const AdministrarRedDialog({
    super.key,
    required this.api,
    required this.red,
    required this.cuenta,
    required this.miembros,
    required this.seguimiento,
    this.soloSeguimiento = false,
  });
  final AzureApi api;
  final RedAzure red;
  final CuentaAzure cuenta;
  final List<Map<String, dynamic>> miembros;
  final SeguimientoRed seguimiento;
  final bool soloSeguimiento;

  @override
  State<AdministrarRedDialog> createState() => _AdministrarRedDialogState();
}

class _AdministrarRedDialogState extends State<AdministrarRedDialog> {
  late RedAzure red = widget.red;
  late List<Map<String, dynamic>> miembros = widget.miembros;
  SeguimientoRed get seguimiento => widget.seguimiento;
  OperacionAdministrativa? get operacion => seguimiento.operacion;
  Timer? _consulta;
  bool ocupado = false;
  bool esperandoPresentarAplicada = false;
  String? error;

  @override
  void initState() {
    super.initState();
    if (operacion?.terminal == false) programarConsulta();
  }

  @override
  void dispose() {
    _consulta?.cancel();
    super.dispose();
  }

  Future<void> ejecutar(Future<void> Function() tarea) async {
    if (!mounted || ocupado || !red.esPropietario(widget.cuenta)) return;
    setState(() {
      ocupado = true;
      error = null;
    });
    try {
      await tarea();
    } catch (e) {
      if (mounted) setState(() => error = errorAdministracion(e));
    } finally {
      if (mounted) setState(() => ocupado = false);
      if (mounted && operacion?.terminal == false) programarConsulta();
    }
  }

  void programarConsulta() {
    _consulta?.cancel();
    _consulta = Timer(const Duration(seconds: 4), consultar);
  }

  Future<void> consultar() async {
    final pendiente = operacion;
    if (pendiente == null || (pendiente.terminal && !widget.soloSeguimiento))
      return;
    await ejecutar(() async {
      final nueva = await widget.api.consultarOperacionRed(
        red.id,
        pendiente.id,
      );
      seguimiento.operacion = nueva;
      if (!mounted) return;
      setState(() => esperandoPresentarAplicada = nueva.estado == 'APLICADA');
    });
  }

  Future<void> solicitar(AccionRed accion, {int? usuarioId}) async {
    if (ocupado ||
        !red.esPropietario(widget.cuenta) ||
        (accion == AccionRed.retirarMiembro &&
            (usuarioId == null || usuarioId == widget.cuenta.id))) {
      return;
    }
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(accion.etiqueta),
        content: Text(switch (accion) {
          AccionRed.suspender =>
            'Retira temporalmente el acceso y conserva perfiles y cupos.',
          AccionRed.reactivar =>
            'Restaura el acceso de los perfiles que sigan vigentes.',
          AccionRed.eliminar => 'Retira los perfiles de la red de forma definitiva. El cupo se libera cuando la operación queda aplicada.',
          AccionRed.retirarMiembro =>
            'Retira al usuario $usuarioId y revoca sus perfiles de esta red.',
        }),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;
    await ejecutar(() async {
      final nueva = await widget.api.solicitarOperacionRed(
        red.id,
        accion,
        usuarioId: usuarioId,
      );
      seguimiento
        ..accion = accion
        ..usuarioId = usuarioId
        ..operacion = nueva;
    });
  }

  Future<void> editar() async {
    final version = red.version;
    if (version == null) return;
    final datos = await showDialog<DatosRed>(
      context: context,
      builder: (_) => FormularioRed(red: red),
    );
    if (datos == null || !mounted) return;
    await ejecutar(() async {
      await widget.api.editarRed(
        red.id,
        datos.nombre,
        datos.descripcion,
        version,
      );
      final actualizada = await widget.api.red(red.id);
      if (mounted) setState(() => red = actualizada);
    });
  }

  Future<void> agregar() async {
    var id = '';
    final usuarioId = await showDialog<int>(
      context: context,
      builder: (_) => _Formulario<int>(
        titulo: 'Agregar miembro',
        boton: 'Agregar',
        valor: () => int.parse(id.trim()),
        campos: [
          TextFormField(
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'ID de una cuenta activa',
            ),
            onSaved: (v) => id = v ?? '',
            validator: (v) =>
                !RegExp(r'^[1-9]\d*$').hasMatch((v ?? '').trim()) ||
                    int.tryParse(v!.trim()) == null
                ? 'Escribe un ID de usuario válido.'
                : null,
          ),
        ],
      ),
    );
    if (usuarioId == null || !mounted) return;
    await ejecutar(() async {
      await widget.api.agregarMiembro(red.id, usuarioId);
      final lista = await widget.api.miembros(red.id);
      if (mounted) setState(() => miembros = lista);
    });
  }

  Future<void> recargar() => ejecutar(() async {
    final actualizada = await widget.api.red(red.id);
    final lista = await widget.api.miembros(red.id);
    if (mounted) {
      setState(() {
        red = actualizada;
        miembros = lista;
      });
    }
  });

  @override
  Widget build(BuildContext context) {
    final actual = operacion;
    final accion = seguimiento.accion;
    final editable =
        !ocupado && !seguimiento.bloqueada && !esperandoPresentarAplicada;
    return PopScope(
      canPop: !ocupado,
      child: AlertDialog(
        title: Text('Administrar red: ${red.nombre}'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!widget.soloSeguimiento && !esperandoPresentarAplicada)
                  Text('Estado de la red: ${red.estado}'),
                if (!widget.soloSeguimiento && red.descripcion.isNotEmpty)
                  Text(red.descripcion),
                if (actual != null && accion != null) ...[
                  const SizedBox(height: 12),
                  Text('${accion.etiqueta}: ${actual.estado}'),
                  SelectableText('UUID: ${actual.id}'),
                  if (!actual.terminal || widget.soloSeguimiento)
                    TextButton(
                      onPressed: ocupado ? null : consultar,
                      child: const Text('Actualizar operación'),
                    ),
                  if (actual.estado == 'FALLIDA') ...[
                    const Text(
                      'El servidor aún no confirmó el cambio. Reintenta la misma solicitud.',
                    ),
                    TextButton(
                      onPressed: ocupado
                          ? null
                          : () => solicitar(
                              accion,
                              usuarioId: seguimiento.usuarioId,
                            ),
                      child: const Text('Reintentar operación'),
                    ),
                  ],
                  if (esperandoPresentarAplicada)
                    const Text(
                      'Cambio confirmado. Cierra esta ventana para actualizar el panel.',
                    ),
                ],
                if (ocupado) const LinearProgressIndicator(),
                if (error != null)
                  Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                if (!esperandoPresentarAplicada && !widget.soloSeguimiento) ...[
                  Wrap(
                    spacing: 8,
                    children: [
                      TextButton(
                        onPressed: editable && red.version != null
                            ? editar
                            : null,
                        child: const Text('Editar red'),
                      ),
                      TextButton(
                        onPressed: editable ? recargar : null,
                        child: const Text('Actualizar datos'),
                      ),
                      if (red.estado == 'ACTIVA' || red.estado == 'PENDIENTE')
                        TextButton(
                          onPressed: editable
                              ? () => solicitar(AccionRed.suspender)
                              : null,
                          child: const Text('Suspender red'),
                        ),
                      if (red.estado == 'SUSPENDIDA')
                        TextButton(
                          onPressed: editable
                              ? () => solicitar(AccionRed.reactivar)
                              : null,
                          child: const Text('Reactivar red'),
                        ),
                      TextButton(
                        onPressed: editable
                            ? () => solicitar(AccionRed.eliminar)
                            : null,
                        child: const Text('Eliminar red'),
                      ),
                    ],
                  ),
                  if (red.version == null)
                    const Text(
                      'El servidor no informó la versión necesaria para editar.',
                    ),
                  const Divider(),
                  Text(
                    'Miembros de la red',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  TextButton(
                    onPressed: editable ? agregar : null,
                    child: const Text('Agregar miembro'),
                  ),
                  for (final miembro in miembros)
                    ListTile(
                      title: Text(
                        '${miembro['nombre'] ?? 'Usuario'} · ${miembro['usuarioId']}',
                      ),
                      subtitle: Text(
                        '${miembro['correo'] ?? ''} · ${miembro['rolRed'] ?? ''} · ${miembro['estado'] ?? ''}',
                      ),
                      trailing:
                          miembro['usuarioId'] is int &&
                              miembro['usuarioId'] != widget.cuenta.id &&
                              miembro['rolRed'] != 'PROPIETARIO'
                          ? IconButton(
                              tooltip:
                                  'Retirar miembro ${miembro['usuarioId']}',
                              onPressed: editable
                                  ? () => solicitar(
                                      AccionRed.retirarMiembro,
                                      usuarioId: miembro['usuarioId'] as int,
                                    )
                                  : null,
                              icon: const Icon(Icons.person_remove_outlined),
                            )
                          : null,
                    ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: ocupado ? null : () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
}
