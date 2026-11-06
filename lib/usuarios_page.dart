import 'package:flutter/material.dart';

class UsuarioDemo {
  const UsuarioDemo({
    required this.id,
    required this.nombre,
    required this.correo,
    required this.estado,
    this.roles = const [],
    this.grupos = const [],
  });

  final String id;
  final String nombre;
  final String correo;
  final String estado;
  final List<String> roles;
  final List<String> grupos;

  String get rol => roles.isEmpty ? 'Sin asignar' : roles.join(', ');
  String get grupo => grupos.isEmpty ? 'Sin asignar' : grupos.join(', ');

  UsuarioDemo copiar({
    String? nombre,
    String? correo,
    String? estado,
    List<String>? roles,
    List<String>? grupos,
  }) {
    return UsuarioDemo(
      id: id,
      nombre: nombre ?? this.nombre,
      correo: correo ?? this.correo,
      estado: estado ?? this.estado,
      roles: List.unmodifiable(roles ?? this.roles),
      grupos: List.unmodifiable(grupos ?? this.grupos),
    );
  }

  UsuarioDemo conEstado(String nuevoEstado) => copiar(estado: nuevoEstado);
}

const usuariosDemo = [
  UsuarioDemo(
    id: '1',
    nombre: 'Administración de prueba',
    correo: 'admin@example.test',
    roles: ['Administrador'], 
    grupos: ['Tecnologías de la información'],
    estado: 'ACTIVO',
  ),
  UsuarioDemo(
    id: '2',
    nombre: 'Mariana Torres',
    correo: 'mariana@example.test',
    roles: ['Soporte'],
    grupos: ['Mesa de ayuda'],
    estado: 'ACTIVO',
  ),
  UsuarioDemo(
    id: '42',
    nombre: 'Luis García',
    correo: 'luis@example.test',
    roles: ['Usuario VPN'], 
    grupos: ['Ventas'],
    estado: 'SUSPENDIDO',
  ),
  UsuarioDemo(
    id: '43',
    nombre: 'Andrea López',
    correo: 'andrea@example.test',
    roles: ['Usuario VPN'], 
    grupos: ['Administración'],
    estado: 'DADO_DE_BAJA',
  ),
];

const etiquetasEstado = {
  'ACTIVO': 'Activo',
  'SUSPENDIDO': 'Suspendido',
  'DADO_DE_BAJA': 'Dado de baja',
};

class UsuariosPage extends StatefulWidget {
  const UsuariosPage({super.key, required this.usuarios});

  final List<UsuarioDemo> usuarios;

  @override
  State<UsuariosPage> createState() => _UsuariosPageState();
}

class _UsuariosPageState extends State<UsuariosPage> {
  final buscador = TextEditingController();
  String busqueda = '';
  String estado = 'TODOS';

  @override
  void dispose() {
    buscador.dispose();
    super.dispose();
  }

  void limpiarFiltros() {
    buscador.clear();
    setState(() {
      busqueda = '';
      estado = 'TODOS';
    });
  }

  Future<void> abrirFormulario([UsuarioDemo? original]) async {
  final resultado = await Navigator.of(context).push<UsuarioDemo>(
    MaterialPageRoute(
      builder: (_) => UsuarioFormPage(
        usuarios: widget.usuarios,
        original: original,
      ),
    ),
  );

  // Al pulsar Cancelar o volver atrás, el formulario devuelve null.
  if (!mounted || resultado == null) return;

  setState(() {
    if (original == null) {
      widget.usuarios.add(resultado);
    } else {
      final indice = widget.usuarios.indexWhere((u) => u.id == original.id);
      widget.usuarios[indice] = resultado;
    }

    // Hace visible la cuenta que se acaba de guardar.
    buscador.clear();
    busqueda = '';
    estado = 'TODOS';
  });

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(original == null ? 'Usuario creado.' : 'Usuario actualizado.'),
    ),
  );
}

  Future<void> verDetalle(UsuarioDemo usuario) async {
  final adminsActivos = widget.usuarios.where(
  (u) => u.estado == 'ACTIVO' && u.roles.contains('Administrador'),
);

final esUltimoAdmin = usuario.estado == 'ACTIVO' &&
    usuario.roles.contains('Administrador') &&
    adminsActivos.length == 1;

  final accion = await showDialog<String>(
    context: context,
    builder: (context) => SimpleDialog(
      title: Text(usuario.nombre),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Correo: ${usuario.correo}'),
              Text('Rol: ${usuario.rol}'),
              Text('Grupo: ${usuario.grupo}'),
              Text('Estado: ${etiquetasEstado[usuario.estado]}'),
              Text('ID: ${usuario.id}'),
              if (esUltimoAdmin)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text('Debe quedar al menos un administrador activo.'),
                ),
            ],
          ),
        ),
        if (usuario.estado != 'DADO_DE_BAJA')
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'editar'),
            child: const Text('Editar'),
          ),
        if (usuario.estado == 'ACTIVO' && !esUltimoAdmin)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'SUSPENDIDO'),
            child: const Text('Suspender usuario'),
          ),
        if (usuario.estado == 'SUSPENDIDO')
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'ACTIVO'),
            child: const Text('Reactivar usuario'),
          ),
        if (usuario.estado != 'DADO_DE_BAJA' && !esUltimoAdmin)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'DADO_DE_BAJA'),
            child: const Text('Dar de baja'),
          ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
      ],
    ),
  );

  if (!mounted || accion == null) return;

  if (accion == 'editar') {
    await abrirFormulario(usuario);
    return;
  }

  await confirmarCambioEstado(usuario, accion);
}

Future<void> confirmarCambioEstado(
  UsuarioDemo usuario,
  String nuevoEstado,
) async {
  const acciones = {
    'SUSPENDIDO': 'Suspender',
    'ACTIVO': 'Reactivar',
    'DADO_DE_BAJA': 'Dar de baja',
  };

  final accion = acciones[nuevoEstado]!;
  final requiereMotivo = nuevoEstado != 'ACTIVO';
  final formulario = GlobalKey<FormState>();

  final confirmado = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('$accion usuario'),
      content: SingleChildScrollView(
        child: Form(
          key: formulario,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${usuario.nombre} · ${usuario.correo}'),
              const SizedBox(height: 12),
              Text('Estado actual: ${etiquetasEstado[usuario.estado]}'),
              Text('Nuevo estado: ${etiquetasEstado[nuevoEstado]}'),
              if (requiereMotivo) ...[
                const SizedBox(height: 16),
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Motivo'),
                  maxLines: 2,
                  validator: (valor) => (valor ?? '').trim().isEmpty
                      ? 'Escribe el motivo para continuar.'
                      : null,
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            if (formulario.currentState!.validate()) {
              Navigator.pop(context, true);
            }
          },
          child: Text(accion),
        ),
      ],
    ),
  );

  if (!mounted || confirmado != true) return;

  final indice = widget.usuarios.indexWhere((u) => u.id == usuario.id);
  if (indice == -1) return;

  setState(() {
    widget.usuarios[indice] = usuario.conEstado(nuevoEstado);
  });

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        '${usuario.nombre}: ${etiquetasEstado[nuevoEstado]} '
        '(modo demostración).',
      ),
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    final visibles = widget.usuarios.where((usuario) {
      final coincideTexto =
          usuario.nombre.toLowerCase().contains(busqueda) ||
          usuario.correo.toLowerCase().contains(busqueda);
      final coincideEstado = estado == 'TODOS' || usuario.estado == estado;
      return coincideTexto && coincideEstado;
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: () => abrirFormulario(),
                icon: const Icon(Icons.person_add_outlined),
                label: const Text('Nuevo usuario'),
              ),
            ),
            const SizedBox(height: 16),
        TextField(
          controller: buscador,
          decoration: const InputDecoration(
            labelText: 'Buscar por nombre o correo',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (valor) {
            setState(() => busqueda = valor.trim().toLowerCase());
          },
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final opcion in {'TODOS': 'Todos', ...etiquetasEstado}.entries)
              ChoiceChip(
                label: Text(opcion.value),
                selected: estado == opcion.key,
                onSelected: (_) => setState(() => estado = opcion.key),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (visibles.isEmpty) ...[
          const Text('Ningún usuario coincide con tu búsqueda.'),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: limpiarFiltros,
              child: const Text('Limpiar filtros'),
            ),
          ),
        ] else ...[
          Text('Usuarios encontrados: ${visibles.length}'),
          const SizedBox(height: 8),
          for (final usuario in visibles)
            Card(
              child: ListTile(
                title: Text(usuario.nombre),
                subtitle: Text(
                  '${usuario.correo}\n'
                  '${usuario.rol} · ${etiquetasEstado[usuario.estado]}',
                ),
                isThreeLine: true,
                trailing: const Icon(Icons.chevron_right),
                onTap: () => verDetalle(usuario),
              ),
            ),
        ],
      ],
    );
  }
}

class UsuarioFormPage extends StatefulWidget {
  const UsuarioFormPage({
    super.key,
    required this.usuarios,
    this.original,
  });

  final List<UsuarioDemo> usuarios;
  final UsuarioDemo? original;

  @override
  State<UsuarioFormPage> createState() => _UsuarioFormPageState();
}

class _UsuarioFormPageState extends State<UsuarioFormPage> {
  final formulario = GlobalKey<FormState>();
  late final TextEditingController nombre;
  late final TextEditingController correo;

  bool get esAlta => widget.original == null;

  @override
  void initState() {
    super.initState();
    nombre = TextEditingController(text: widget.original?.nombre ?? '');
    correo = TextEditingController(text: widget.original?.correo ?? '');
  }

  @override
  void dispose() {
    nombre.dispose();
    correo.dispose();
    super.dispose();
  }

  String? validarCorreo(String? valor) {
    final texto = (valor ?? '').trim();
    if (texto.isEmpty) return 'Escribe el correo.';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(texto)) {
      return 'Escribe un correo válido.';
    }

    final duplicado = widget.usuarios.any(
      (u) =>
          u.id != widget.original?.id &&
          u.correo.trim().toLowerCase() == texto.toLowerCase(),
    );
    return duplicado ? 'Ya existe un usuario con este correo.' : null;
  }

  void guardar() {
    if (!formulario.currentState!.validate()) return;

    final anterior = widget.original;
    final usuario = UsuarioDemo(
      id: anterior?.id ?? 'demo-${DateTime.now().microsecondsSinceEpoch}',
      nombre: nombre.text.trim(),
      correo: correo.text.trim(),
      roles: anterior?.roles ?? const [],
      grupos: anterior?.grupos ?? const [],
      estado: anterior?.estado ?? 'ACTIVO',
    );

    Navigator.of(context).pop(usuario);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(esAlta ? 'Nuevo usuario' : 'Editar usuario')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Form(
                  key: formulario,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: nombre,
                        maxLength: 120,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(labelText: 'Nombre'),
                        validator: (valor) => (valor ?? '').trim().isEmpty
                            ? 'Escribe el nombre.'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: correo,
                        maxLength: 254,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Correo electrónico',
                        ),
                        validator: validarCorreo,
                      ),
                      if (esAlta) ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          obscureText: true,
                          enableSuggestions: false,
                          autocorrect: false,
                          decoration: const InputDecoration(
                            labelText: 'Contraseña inicial de prueba',
                            helperText: 'Usa una contraseña ficticia.',
                          ),
                          validator: (valor) => (valor ?? '').trim().isEmpty
                              ? 'Escribe una contraseña inicial.'
                              : null,
                        ),
                      ],
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: guardar,
                        child: Text(esAlta ? 'Crear usuario' : 'Guardar cambios'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancelar'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}