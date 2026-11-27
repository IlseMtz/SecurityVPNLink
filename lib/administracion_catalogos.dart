import 'package:flutter/material.dart';
import 'api_error.dart';
import 'azure_api.dart';
import 'administracion_formularios.dart';

class CatalogosAdministrativosPage extends StatefulWidget {
  const CatalogosAdministrativosPage({super.key, required this.api, required this.cuentaActual, required this.grupos});
  final AzureApi api;
  final CuentaAzure cuentaActual;
  final bool grupos;
  @override
  State<CatalogosAdministrativosPage> createState() => _CatalogosAdministrativosPageState();
}

class _CatalogosAdministrativosPageState extends State<CatalogosAdministrativosPage> {
  int pagina = 0;
  Future<PaginaAzure>? datos;
  bool ocupado = false;
  String? aviso;
  bool get autorizado => widget.cuentaActual.administraCuentas;
  String get entidad => widget.grupos ? 'grupo' : 'rol';
  @override
  void initState() { super.initState(); if (autorizado) datos = consultar(); }
  Future<PaginaAzure> consultar() => widget.grupos
    ? widget.api.gruposPanel(pagina: pagina) : widget.api.rolesPanel(pagina: pagina);
  void cargar([int? nueva]) { if (!mounted || !autorizado) return; setState(() { pagina = nueva ?? pagina; datos = consultar(); }); }
  Future<void> ejecutar(Future<void> Function() tarea) async {
    if (!autorizado || ocupado) return;
    setState(() { ocupado = true; aviso = null; });
    try { await tarea(); } catch (e) { if (mounted) setState(() => aviso = mensajeAdministracion(e)); }
    finally { if (mounted) { setState(() => ocupado = false); cargar(); } }
  }
  Future<void> permisos() async {
    await ejecutar(() async {
      final lista = await widget.api.permisosPanel();
      if (!mounted) return;
      await showDialog<void>(context: context, builder: (c) => AlertDialog(
        title: const Text('Permisos del panel'),
        content: SizedBox(width: 520, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Estos permisos controlan acciones del panel; no autorizan destinos IP ni puertos.'),
          for (final p in lista) ListTile(title: Text('${p['codigo'] ?? ''}'), subtitle: Text('${p['nombre'] ?? ''}')),
        ]))), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cerrar'))]));
    });
  }
  Future<void> abrir(Map<String, dynamic> fila) async => ejecutar(() async {
    final id = catalogoId(fila, widget.grupos ? 'id_grupo' : 'id_rol');
    final detalle = widget.grupos ? await widget.api.grupoPanel(id) : await widget.api.rolPanel(id);
    if (!mounted) return;
    final accion = await showDialog<String>(context: context, builder: (c) => AlertDialog(
      title: Text('${detalle['nombre'] ?? entidad}'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${detalle['descripcion'] ?? ''}'),
        Text('Versión: ${detalle['version'] ?? 'No disponible'}'),
        if (widget.grupos) Text(indicadorActivo(detalle['activo']) ? 'Grupo activo' : 'Grupo inactivo')
        else ...[
          Text('Código: ${detalle['codigo'] ?? ''}'),
          if (rolProtegido(detalle)) const Text('Rol de sistema o protección sin confirmar: solo consulta.'),
          const Text('Permisos:'),
          for (final p in (detalle['permisos'] as List? ?? const []))
            Text(p is Map ? '${p['codigo'] ?? p['nombre'] ?? ''}' : '$p'),
        ],
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cerrar')),
        if (widget.grupos) TextButton(onPressed: () => Navigator.pop(c, 'miembros'), child: const Text('Integrantes')),
        if (widget.grupos || !rolProtegido(detalle)) ...[
          TextButton(onPressed: detalle['version'] is int ? () => Navigator.pop(c, 'editar') : null, child: const Text('Editar')),
          if (!widget.grupos || indicadorActivo(detalle['activo'])) TextButton(
            onPressed: () => Navigator.pop(c, 'eliminar'), child: Text(widget.grupos ? 'Desactivar' : 'Eliminar')),
        ],
      ],
    ));
    if (!mounted) return;
    if (accion == 'editar') { await formulario(detalle); return; }
    if (accion == 'eliminar') {
      final confirmado = await confirmarAdministracion(context, widget.grupos ? 'Desactivar grupo' : 'Eliminar rol',
        widget.grupos ? 'Se conservarán integrantes e historial. No se modificará el acceso VPN.'
          : 'Solo se eliminará si es personalizado y no tiene asignaciones. El servidor comprobará esta restricción.');
      if (!confirmado) return;
      if (widget.grupos) { await widget.api.desactivarGrupo(id); } else { await widget.api.eliminarRol(id); }
      if (mounted) setState(() => aviso = widget.grupos ? 'Grupo desactivado; historial conservado.' : 'Rol eliminado.');
      return;
    }
    if (accion == 'miembros') {
      await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => MiembrosGrupoPage(
        api: widget.api, cuentaActual: widget.cuentaActual, grupoId: id)));
    }
  });

  Future<void> formulario([Map<String, dynamic>? detalle]) async {
    final id = detalle == null ? null : catalogoId(detalle, widget.grupos ? 'id_grupo' : 'id_rol');
    Map<int, String>? opciones;
    final seleccion = <int>{};
    if (!widget.grupos) {
      if (detalle != null && rolProtegido(detalle)) return;
      if (detalle != null && detalle['permisos'] is! List) throw const ExcepcionApi(502, 'RESPUESTA_INVALIDA');
      final permisos = await widget.api.permisosPanel();
      final disponibles = permisos.where((p) => p['codigo'] != 'ADMINISTRACION_GLOBAL').toList();
      opciones = {for (final p in disponibles) catalogoId(p, 'id_permiso'): '${p['codigo']} · ${p['nombre'] ?? ''}'};
      for (final p in (detalle?['permisos'] as List? ?? const [])) {
        final codigo = p is Map ? p['codigo'] : p;
        final coincidencias = disponibles.where((v) => v['codigo'] == codigo ||
          (p is Map && catalogoId(v, 'id_permiso') == (p['id_permiso'] ?? p['id'])));
        if (coincidencias.isEmpty) throw const ExcepcionApi(502, 'RESPUESTA_INVALIDA');
        seleccion.add(catalogoId(coincidencias.first, 'id_permiso'));
      }
    }
    if (!mounted) return;
    final guardado = await showDialog<bool>(context: context, barrierDismissible: false,
      builder: (_) => FormularioAdministrativo(
        titulo: '${id == null ? 'Crear' : 'Editar'} $entidad',
        aviso: widget.grupos ? 'Organización administrativa. No modifica membresías de red ni perfiles VPN.'
          : 'ADMINISTRACION_GLOBAL está reservado. Guardar reemplaza los permisos seleccionados.',
        campos: [
          if (!widget.grupos && id == null) CampoAdministrativo('codigo', 'Código', validar: (v) =>
            RegExp(r'^[A-Z][A-Z0-9_]{1,39}$').hasMatch(v.trim()) ? null : 'Usa 2 a 40 caracteres: mayúsculas, números y guion bajo.'),
          CampoAdministrativo('nombre', 'Nombre', inicial: '${detalle?['nombre'] ?? ''}', validar: obligatorio),
          CampoAdministrativo('descripcion', 'Descripción', inicial: '${detalle?['descripcion'] ?? ''}'),
        ],
        opciones: opciones, seleccion: seleccion,
        activo: widget.grupos && id != null ? indicadorActivo(detalle!['activo']) : null,
        guardar: (v, elegidos, activo) async {
          if (widget.grupos) {
            await widget.api.guardarGrupo(id: id, version: detalle?['version'] as int?, nombre: v['nombre']!,
              descripcion: v['descripcion']!, activo: activo ?? true);
          } else {
            await widget.api.guardarRol(id: id, version: detalle?['version'] as int?, codigo: v['codigo'] ?? '',
              nombre: v['nombre']!, descripcion: v['descripcion']!, permisos: elegidos.toList());
          }
        },
      ));
    if (guardado == true && mounted) setState(() => aviso = 'Cambios guardados.');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.grupos ? 'Grupos administrativos' : 'Roles y permisos')),
    body: !autorizado ? const Center(child: Text('No tienes permiso para esta operación.'))
      : Column(children: [
        Padding(padding: const EdgeInsets.all(16), child: Wrap(spacing: 12, children: [
          FilledButton(onPressed: ocupado ? null : () => ejecutar(() => formulario()), child: Text('Crear $entidad')),
          if (!widget.grupos) OutlinedButton(onPressed: ocupado ? null : permisos, child: const Text('Ver permisos')),
          IconButton(tooltip: 'Actualizar catálogo', onPressed: ocupado ? null : () => cargar(), icon: const Icon(Icons.refresh)),
        ])),
        if (aviso != null) Padding(padding: const EdgeInsets.all(12), child: Text(aviso!)),
        if (ocupado)
            const Padding(
              padding: EdgeInsets.all(8),
              child: Text('Operación en curso…'),
            ),
        Expanded(child: FutureBuilder<PaginaAzure>(future: datos, builder: (context, s) {
          if (s.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (s.hasError) return Center(child: Text(mensajeAdministracion(s.error!)));
          final p = s.data!;
          return Column(children: [Expanded(child: p.items.isEmpty ? const Center(child: Text('No hay registros en esta página.'))
            : ListView(children: [for (final item in p.items) ListTile(
              title: Text('${item['nombre'] ?? ''}'),
              subtitle: Text(widget.grupos ? (indicadorActivo(item['activo']) ? 'Activo' : 'Inactivo') : '${item['codigo'] ?? ''}'),
              trailing: const Icon(Icons.chevron_right), onTap: ocupado ? null : () => abrir(item))])),
            PaginadorAdministrativo(pagina: pagina, siguiente: p.haySiguiente, ocupado: ocupado, cambiar: cargar),
          ]);
        })),
      ]),
  );
}

class PaginadorAdministrativo extends StatelessWidget {
  const PaginadorAdministrativo({super.key, required this.pagina, required this.siguiente, required this.cambiar, this.ocupado = false});
  final int pagina;
  final bool siguiente, ocupado;
  final void Function(int) cambiar;
  @override
  Widget build(BuildContext context) => Row(mainAxisAlignment: MainAxisAlignment.center, children: [
    IconButton(tooltip: 'Página anterior', onPressed: ocupado || pagina == 0 ? null : () => cambiar(pagina - 1), icon: const Icon(Icons.chevron_left)),
    Text('Página ${pagina + 1}'),
    IconButton(tooltip: 'Página siguiente', onPressed: ocupado || !siguiente ? null : () => cambiar(pagina + 1), icon: const Icon(Icons.chevron_right)),
  ]);
}

class MiembrosGrupoPage extends StatefulWidget {
  const MiembrosGrupoPage({super.key, required this.api, required this.cuentaActual, required this.grupoId});
  final AzureApi api;
  final CuentaAzure cuentaActual;
  final int grupoId;
  @override
  State<MiembrosGrupoPage> createState() => _MiembrosGrupoPageState();
}
class _MiembrosGrupoPageState extends State<MiembrosGrupoPage> {
  int pagina = 0, revision = 0;
  bool ocupado = false;
  Map<String, dynamic>? grupo;
  PaginaAzure? miembros;
  String? error;
  bool get autorizado => widget.cuentaActual.administraCuentas;
  @override
  void initState() { super.initState(); if (autorizado) cargar(0); }
  Future<void> cargar(int p) async {
    if (!autorizado) return;
    final r = ++revision;
    setState(() { ocupado = true; error = null; });
    try {
      final g = await widget.api.grupoPanel(widget.grupoId);
      final m = await widget.api.miembrosGrupo(widget.grupoId, pagina: p);
      if (mounted && r == revision) setState(() { grupo = g; miembros = m; pagina = p; });
    } catch (e) { if (mounted && r == revision) setState(() { grupo = null; miembros = null; error = mensajeAdministracion(e); }); }
    finally { if (mounted && r == revision) setState(() => ocupado = false); }
  }
  Future<void> agregar() async {
    if (!autorizado || ocupado || !indicadorActivo(grupo?['activo'])) return;
    final ok = await showDialog<bool>(context: context, barrierDismissible: false, builder: (_) => FormularioAdministrativo(
      titulo: 'Agregar integrante', aviso: 'Ingresa el ID de una cuenta existente. Su acceso a las redes VPN no cambiará.',
      campos: [CampoAdministrativo('id', 'ID de usuario', validar: (v) => (int.tryParse(v.trim()) ?? 0) > 0 ? null : 'Escribe un ID positivo.')],
      guardar: (v, _, _) async {
        final id = int.parse(v['id']!.trim());
        final cuenta = await widget.api.cuentaAdministrada(id);
        if (!mounted) return;
        final confirma = await confirmarAdministracion(context, 'Confirmar integrante',
          'Agregar a ${cuenta['nombre'] ?? ''} (${cuenta['correo'] ?? ''}), usuario $id, a ${grupo?['nombre'] ?? 'este grupo'}.');
        if (!confirma) throw const ExcepcionApi(400, 'CANCELADO');
        await widget.api.asociarGrupo(widget.grupoId, id, agregar: true);
      },
    ));
    if (mounted && ok == true) await cargar(0);
  }
  Future<void> retirar(Map<String, dynamic> usuario) async {
    if (!autorizado || ocupado) return;
    final valorId = usuario['id_usuario'] ?? usuario['id'];
    if (valorId is! int || valorId <= 0) {
      setState(() => error = 'Identificador de integrante inválido. Actualiza la lista.');
      return;
    }
    final id = valorId;
    if (!await confirmarAdministracion(context, 'Retirar integrante',
      'Retirar a ${usuario['nombre'] ?? 'usuario $id'} del grupo. Sus membresías de red y perfiles VPN se conservan.')) return;
    if (!mounted) return;
    setState(() { ocupado = true; error = null; });
    try { await widget.api.asociarGrupo(widget.grupoId, id, agregar: false); if (mounted) await cargar(pagina); }
    catch (e) { if (mounted) setState(() => error = mensajeAdministracion(e)); }
    finally { if (mounted) setState(() => ocupado = false); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text('Integrantes · ${grupo?['nombre'] ?? widget.grupoId}')),
    body: !autorizado ? const Center(child: Text('No tienes permiso para esta operación.')) : Column(children: [
      const Padding(padding: EdgeInsets.all(16), child: Text('Pertenecer a este grupo no concede acceso a redes VPN.')),
      Wrap(spacing: 12, children: [FilledButton(onPressed: ocupado || !indicadorActivo(grupo?['activo']) ? null : agregar,
        child: const Text('Agregar integrante')),
        TextButton(onPressed: ocupado ? null : () => cargar(pagina), child: const Text('Actualizar integrantes'))]),
      if (grupo != null && !indicadorActivo(grupo!['activo'])) const Text('Grupo inactivo: reactívalo desde Editar para agregar integrantes.'),
      if (error != null) Text(error!),
      if (ocupado) const LinearProgressIndicator(),
      Expanded(child: ListView(children: [
        if (miembros?.items.isEmpty == true) const ListTile(title: Text('No hay integrantes en esta página.')),
        for (final m in miembros?.items ?? <Map<String, dynamic>>[]) ListTile(title: Text('${m['nombre'] ?? ''}'),
          subtitle: Text('${m['correo'] ?? ''}'), trailing: TextButton(onPressed: ocupado ? null : () => retirar(m), child: const Text('Retirar'))),
      ])),
      PaginadorAdministrativo(pagina: pagina, siguiente: miembros?.haySiguiente ?? false, ocupado: ocupado, cambiar: cargar),
    ]));
}
