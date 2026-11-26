import 'package:flutter/material.dart';

import 'api_error.dart';
import 'azure_api.dart';

class RecursosInternosPage extends StatefulWidget {
  const RecursosInternosPage({super.key, required this.api, this.red});

  final AzureApi api;
  final RedAzure? red;

  @override
  State<RecursosInternosPage> createState() => _RecursosInternosPageState();
}

class _RecursosInternosPageState extends State<RecursosInternosPage> {
  List<Map<String, dynamic>> recursos = [], concesiones = [], miembros = [];
  bool ocupado = true, agente = false;
  String? error, aviso;

  RedAzure? get red => widget.red;

  @override
  void initState() {
    super.initState();
    cargar();
  }

  Future<void> cargar([Future<void> Function()? cambio]) async {
    setState(() {
      ocupado = true;
      error = null;
      aviso = null;
    });
    var guardado = false;
    try {
      if (cambio != null) {
        await cambio();
        guardado = true;
      }
      final actual = red;
      if (actual == null) {
        final items = await widget.api.catalogoRecursos();
        if (!mounted) return;
        setState(() => recursos = items);
      } else {
        final datos = await widget.api.recursosRed(actual.id);
        final participantes = await widget.api.miembros(actual.id);
        if (!mounted) return;
        setState(() {
          recursos = listaJson(datos['recursos']);
          concesiones = listaJson(datos['concesiones']);
          miembros = participantes
              .where((m) => m['estado'] == 'ACTIVO')
              .toList();
          agente = datos['agenteDisponible'] == true;
        });
      }
      if (guardado && mounted) {
        setState(
          () => aviso = 'Cambio guardado. El agente sincroniza la política.',
        );
      }
    } on ExcepcionApi catch (e) {
      if (!mounted) return;
      setState(
        () => error = guardado
            ? 'El cambio se guardó. No se pudo refrescar la lista.'
            : 'No se pudo completar la operación (${e.codigo}).',
      );
    } catch (_) {
      if (mounted) {
        setState(() => error = 'No se pudieron cargar los recursos.');
      }
    } finally {
      if (mounted) setState(() => ocupado = false);
    }
  }

  Future<void> editar([Map<String, dynamic>? item]) async {
    final datos = await showDialog<Map<String, Object>>(
      context: context,
      builder: (_) => _RecursoDialog(item: item),
    );
    if (datos != null && mounted) {
      await cargar(
        () => widget.api.guardarRecurso(datos, id: item?['id'] as int?),
      );
    }
  }

  Future<void> autorizar([Map<String, dynamic>? item]) async {
    final datos = await showDialog<Map<String, Object>>(
      context: context,
      builder: (_) =>
          _ConcesionDialog(recursos: recursos, miembros: miembros, item: item),
    );
    if (datos != null && mounted) {
      await cargar(() => widget.api.guardarConcesion(red!.id, datos));
    }
  }

  Future<void> retirar(Map<String, dynamic> item) async {
    final aceptar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Retirar autorización'),
        content: Text(
          'Retirar el acceso de ${usuario(item['usuarioId'])} a ${recurso(item['recursoId'])}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Retirar'),
          ),
        ],
      ),
    );
    if (aceptar == true && mounted) {
      await cargar(
        () => widget.api.retirarConcesion(
          red!.id,
          idJson(item['recursoId']),
          idJson(item['usuarioId']),
        ),
      );
    }
  }

  String usuario(dynamic id) {
    for (final m in miembros) {
      if (m['usuarioId'] == id) return '${m['nombre']}';
    }
    return 'Usuario $id';
  }

  String recurso(dynamic id) {
    for (final r in recursos) {
      if (r['id'] == id) return '${r['nombre']}';
    }
    return 'Recurso $id';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        red == null ? 'Recursos internos' : 'Recursos de ${red!.nombre}',
      ),
      actions: [
        IconButton(
          onPressed: ocupado ? null : () => cargar(),
          icon: const Icon(Icons.refresh),
          tooltip: 'Actualizar recursos',
        ),
      ],
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 850),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (ocupado) const LinearProgressIndicator(),
            if (error != null)
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (aviso != null) Text(aviso!),
            if (red != null && !ocupado && error == null && !agente)
              const Text('Sin confirmación reciente del agente.'),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                icon: const Icon(Icons.add),
                onPressed: ocupado
                    ? null
                    : red == null
                    ? () => editar()
                    : miembros.isEmpty || recursos.isEmpty
                    ? null
                    : () => autorizar(),
                label: Text(
                  red == null ? 'Crear recurso' : 'Autorizar recurso',
                ),
              ),
            ),
            for (final r in recursos)
              Card(
                child: ListTile(
                  title: Text('${r['nombre']}'),
                  subtitle: Text(
                    '${r['direccion']} · ${r['protocolo']}/${r['puerto']}'
                    '${_activo(r) ? '' : ' · Inactivo'}',
                  ),
                  trailing: red == null
                      ? IconButton(
                          tooltip: 'Editar recurso',
                          onPressed: ocupado ? null : () => editar(r),
                          icon: const Icon(Icons.edit),
                        )
                      : null,
                ),
              ),
            if (red != null) ...[
              const SizedBox(height: 24),
              Text(
                'Autorizaciones por usuario',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (concesiones.isEmpty && !ocupado)
                const Text('Todavía no hay autorizaciones.'),
              for (final c in concesiones)
                Card(
                  child: ListTile(
                    title: Text(
                      '${usuario(c['usuarioId'])} · ${recurso(c['recursoId'])}',
                    ),
                    subtitle: Text(
                      '${_dias(c['dias'] as int)} · ${c['inicio']} a ${c['fin']} · ${c['zona']}',
                    ),
                    trailing: Wrap(
                      children: [
                        IconButton(
                          tooltip: 'Editar horario',
                          icon: const Icon(Icons.schedule),
                          onPressed:
                              ocupado ||
                                  !miembros.any(
                                    (m) => m['usuarioId'] == c['usuarioId'],
                                  ) ||
                                  !recursos.any(
                                    (r) => r['id'] == c['recursoId'],
                                  )
                              ? null
                              : () => autorizar(c),
                        ),
                        IconButton(
                          tooltip: 'Retirar autorización',
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: ocupado ? null : () => retirar(c),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    ),
  );
}

bool _activo(Map<String, dynamic> recurso) =>
    recurso['activo'] == true || recurso['activo'] == 1;
const _semana = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
String _dias(int mask) => [
  for (var i = 0; i < 7; i++)
    if (mask & (1 << i) != 0) _semana[i],
].join(', ');

class _RecursoDialog extends StatefulWidget {
  const _RecursoDialog({this.item});
  final Map<String, dynamic>? item;
  @override
  State<_RecursoDialog> createState() => _RecursoDialogState();
}

class _RecursoDialogState extends State<_RecursoDialog> {
  final form = GlobalKey<FormState>();
  final Map<String, Object> datos = {};
  late String protocolo = widget.item?['protocolo'] as String? ?? 'TCP';
  late bool activo = widget.item == null || _activo(widget.item!);

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.item == null ? 'Crear recurso' : 'Editar recurso'),
    content: SizedBox(
      width: 450,
      child: Form(
        key: form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                initialValue: widget.item?['nombre'] as String?,
                maxLength: 120,
                decoration: const InputDecoration(labelText: 'Nombre'),
                validator: (v) => v!.trim().isEmpty ? 'Indica el nombre' : null,
                onSaved: (v) => datos['nombre'] = v!.trim(),
              ),
              TextFormField(
                initialValue: widget.item?['direccion'] as String?,
                decoration: const InputDecoration(
                  labelText: 'Dirección IPv4',
                  hintText: '172.30.77.10',
                ),
                validator: (v) =>
                    RegExp(
                      r'^172\.30\.77\.(?:[2-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-4])$',
                    ).hasMatch(v!.trim())
                    ? null
                    : 'Usa una dirección del segmento 172.30.77.0/24',
                onSaved: (v) => datos['direccion'] = v!.trim(),
              ),
              DropdownButtonFormField<String>(
                initialValue: protocolo,
                decoration: const InputDecoration(labelText: 'Protocolo'),
                items: ['TCP', 'UDP']
                    .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                    .toList(),
                onChanged: (p) => setState(() => protocolo = p!),
              ),
              TextFormField(
                initialValue: widget.item?['puerto']?.toString() ?? '80',
                decoration: const InputDecoration(labelText: 'Puerto'),
                keyboardType: TextInputType.number,
                validator: (v) {
                  final p = int.tryParse(v!.trim());
                  return p == null || p < 1 || p > 65535
                      ? 'Puerto de 1 a 65535'
                      : null;
                },
                onSaved: (v) => datos['puerto'] = int.parse(v!.trim()),
              ),
              SwitchListTile(
                value: activo,
                onChanged: (v) => setState(() => activo = v),
                title: const Text('Activo'),
              ),
              if (widget.item != null)
                const Text(
                  'Desactivar el recurso o cambiar su destino retira sus concesiones.',
                ),
            ],
          ),
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
          if (!form.currentState!.validate()) return;
          form.currentState!.save();
          Navigator.pop(context, {
            ...datos,
            'protocolo': protocolo,
            'activo': activo,
          });
        },
        child: const Text('Guardar'),
      ),
    ],
  );
}

class _ConcesionDialog extends StatefulWidget {
  const _ConcesionDialog({
    required this.recursos,
    required this.miembros,
    this.item,
  });
  final List<Map<String, dynamic>> recursos, miembros;
  final Map<String, dynamic>? item;
  @override
  State<_ConcesionDialog> createState() => _ConcesionDialogState();
}

class _ConcesionDialogState extends State<_ConcesionDialog> {
  final form = GlobalKey<FormState>();
  final Map<String, Object> datos = {};
  late int dias = widget.item?['dias'] as int? ?? 127;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.item == null ? 'Autorizar recurso' : 'Editar horario'),
    content: SizedBox(
      width: 450,
      child: Form(
        key: form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (label, key, items, id) in [
                ('Miembro', 'usuarioId', widget.miembros, 'usuarioId'),
                ('Recurso', 'recursoId', widget.recursos, 'id'),
              ])
                DropdownButtonFormField<int>(
                  initialValue: widget.item?[key] as int?,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: label),
                  items: items
                      .map(
                        (m) => DropdownMenuItem(
                          value: idJson(m[id]),
                          child: Text('${m['nombre']}'),
                        ),
                      )
                      .toList(),
                  onChanged: widget.item == null ? (_) {} : null,
                  validator: (v) => v == null ? 'Selecciona una opción' : null,
                  onSaved: (v) => datos[key] = v!,
                ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                children: [
                  for (var i = 0; i < 7; i++)
                    FilterChip(
                      label: Text(_semana[i]),
                      selected: dias & (1 << i) != 0,
                      onSelected: (_) => setState(() => dias ^= 1 << i),
                    ),
                ],
              ),
              if (dias == 0) const Text('Selecciona al menos un día.'),
              for (final key in ['inicio', 'fin'])
                TextFormField(
                  initialValue: (widget.item?[key] as String? ?? '00:00')
                      .substring(0, 5),
                  decoration: InputDecoration(
                    labelText: '${key == 'inicio' ? 'Inicio' : 'Fin'} (HH:mm)',
                  ),
                  validator: (v) =>
                      RegExp(r'^(?:[01][0-9]|2[0-3]):[0-5][0-9]$')
                          .hasMatch(v!.trim())
                      ? null
                      : 'Usa HH:mm',
                  onSaved: (v) => datos[key] = '${v!.trim()}:00',
                ),
              TextFormField(
                initialValue:
                    widget.item?['zona'] as String? ?? 'America/Mexico_City',
                maxLength: 64,
                decoration: const InputDecoration(
                  labelText: 'Zona horaria IANA',
                ),
                validator: (v) =>
                    v!.trim().isEmpty ? 'Indica una zona horaria' : null,
                onSaved: (v) => datos['zona'] = v!.trim(),
              ),
              const Text(
                'Horas iguales habilitan 24 horas desde el inicio indicado. El horario puede cruzar medianoche.',
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: dias == 0
            ? null
            : () {
                if (!form.currentState!.validate()) return;
                form.currentState!.save();
                Navigator.pop(context, {...datos, 'dias': dias});
              },
        child: const Text('Guardar'),
      ),
    ],
  );
}
