import 'package:flutter/material.dart';
import 'usuarios_page.dart';

const rolesDelSistema = ['Administrador', 'Soporte', 'Usuario VPN'];

class RolesGruposPage extends StatefulWidget {
  const RolesGruposPage({
    super.key,
    required this.usuarios,
    required this.grupos,
  });

  final List<UsuarioDemo> usuarios;
  final List<String> grupos;

  @override
  State<RolesGruposPage> createState() => _RolesGruposPageState();
}

class _RolesGruposPageState extends State<RolesGruposPage> {
  Future<void> editarGrupo([String? original]) async {
    final formulario = GlobalKey<FormState>();
    var nombre = original ?? '';

    final nuevoNombre = await showDialog<String>(
      context: context,
      builder: (dialogo) => AlertDialog(
        title: Text(original == null ? 'Nuevo grupo' : 'Editar grupo'),
        content: Form(
          key: formulario,
          child: TextFormField(
            initialValue: nombre,
            autofocus: true,
            maxLength: 100,
            decoration: const InputDecoration(labelText: 'Nombre del grupo'),
            onChanged: (valor) => nombre = valor.trim(),
            validator: (valor) {
              final texto = (valor ?? '').trim();
              if (texto.isEmpty) return 'Escribe el nombre del grupo.';

              final existe = widget.grupos.any(
                (grupo) =>
                    grupo != original &&
                    grupo.toLowerCase() == texto.toLowerCase(),
              );
              return existe ? 'Ya existe un grupo con ese nombre.' : null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogo),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (formulario.currentState!.validate()) {
                Navigator.pop(dialogo, nombre);
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (!mounted || nuevoNombre == null || nuevoNombre == original) return;

    setState(() {
      if (original == null) {
        widget.grupos.add(nuevoNombre);
        return;
      }

      final indice = widget.grupos.indexOf(original);
      widget.grupos[indice] = nuevoNombre;

      // En la demo usamos nombres. Al renombrar, conservamos las membresías.
      for (var i = 0; i < widget.usuarios.length; i++) {
        final usuario = widget.usuarios[i];
        if (usuario.grupos.contains(original)) {
          widget.usuarios[i] = usuario.copiar(
            grupos: [
              for (final grupo in usuario.grupos)
                grupo == original ? nuevoNombre : grupo,
            ],
          );
        }
      }
    });
  }

  Future<void> asignar(UsuarioDemo usuario) async {
    final roles = usuario.roles.toSet();
    final grupos = usuario.grupos.toSet();
    final esUltimoAdmin = usuario.estado == 'ACTIVO' &&
        usuario.roles.contains('Administrador') &&
        widget.usuarios.where((u) =>
            u.estado == 'ACTIVO' && u.roles.contains('Administrador')).length == 1;

    final guardar = await showDialog<bool>(
      context: context,
      builder: (dialogo) => StatefulBuilder(
        builder: (context, actualizar) => AlertDialog(
          title: Text('Asignaciones de ${usuario.nombre}'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Roles'),
                  for (final rol in rolesDelSistema)
                    CheckboxListTile(
                      title: Text(rol),
                      value: roles.contains(rol),
                      subtitle: esUltimoAdmin && rol == 'Administrador'
                          ? const Text('Debe quedar un administrador activo.')
                          : null,
                      onChanged: esUltimoAdmin && rol == 'Administrador'
                          ? null
                          : (marcado) => actualizar(() {
                                if (marcado == true) {
                                  roles.add(rol);
                                } else {
                                  roles.remove(rol);
                                }
                              }),
                    ),
                  const Divider(),
                  const Text('Grupos o departamentos'),
                  for (final grupo in widget.grupos)
                    CheckboxListTile(
                      title: Text(grupo),
                      value: grupos.contains(grupo),
                      onChanged: (marcado) => actualizar(() {
                        if (marcado == true) {
                          grupos.add(grupo);
                        } else {
                          grupos.remove(grupo);
                        }
                      }),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogo, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogo, true),
              child: const Text('Guardar asignaciones'),
            ),
          ],
        ),
      ),
    );

    if (!mounted || guardar != true) return;

    final indice = widget.usuarios.indexWhere((u) => u.id == usuario.id);
    if (indice < 0) return;

    setState(() {
      widget.usuarios[indice] = widget.usuarios[indice].copiar(
        roles: roles.toList(),
        grupos: grupos.toList(),
      );
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Asignaciones guardadas para ${usuario.nombre}.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final titulo = Theme.of(context).textTheme.titleLarge;

    return Scaffold(
      appBar: AppBar(title: const Text('Roles y grupos')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Grupos o departamentos', style: titulo),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: () => editarGrupo(),
              icon: const Icon(Icons.group_add_outlined),
              label: const Text('Nuevo grupo'),
            ),
          ),
          for (final grupo in widget.grupos)
            ListTile(
              title: Text(grupo),
              trailing: IconButton(
                tooltip: 'Editar $grupo',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => editarGrupo(grupo),
              ),
            ),
          const Divider(height: 32),
          Text('Asignaciones por usuario', style: titulo),
          for (final usuario in widget.usuarios)
            ListTile(
              title: Text(usuario.nombre),
              subtitle: Text('${usuario.rol}\n${usuario.grupo}'),
              isThreeLine: true,
              trailing: usuario.estado == 'DADO_DE_BAJA'
                  ? const Text('Baja')
                  : const Icon(Icons.chevron_right),
              onTap: usuario.estado == 'DADO_DE_BAJA'
                  ? null
                  : () => asignar(usuario),
            ),
        ],
      ),
    );
  }
}