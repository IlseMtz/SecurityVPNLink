import 'dart:convert';

import 'package:flutter/material.dart';

import 'api_error.dart';
import 'azure_api.dart';
import 'sesion_azure.dart';

enum AccionCuenta { registrar, editar, cambiarContrasena }

class MiCuentaDialog extends StatefulWidget {
  const MiCuentaDialog({super.key, required this.sesion});
  final SesionAzure sesion;

  @override
  State<MiCuentaDialog> createState() => _MiCuentaDialogState();
}

class _MiCuentaDialogState extends State<MiCuentaDialog> {
  late Future<CuentaAzure> perfil = widget.sesion.api.miPerfil();

  void abrirFormulario(AccionCuenta accion, CuentaAzure cuenta) {
    showDialog<void>(
      context: context,
      builder: (_) => FormularioCuenta(
        sesion: widget.sesion,
        accion: accion,
        cuenta: cuenta,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Mi cuenta'),
    content: FutureBuilder<CuentaAzure>(
      future: perfil,
      builder: (context, resultado) {
        if (resultado.hasError) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(mensajeSeguro(resultado.error!)),
              TextButton(
                onPressed: () =>
                    setState(() => perfil = widget.sesion.api.miPerfil()),
                child: const Text('Reintentar'),
              ),
            ],
          );
        }
        final cuenta = resultado.data;
        if (cuenta == null) {
          return const Center(
            widthFactor: 1,
            heightFactor: 1,
            child: CircularProgressIndicator(),
          );
        }
        return SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                cuenta.nombre,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(cuenta.correo),
              Text('ID de usuario: ${cuenta.id}'),
              Text('Estado: ${cuenta.estado}'),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => abrirFormulario(AccionCuenta.editar, cuenta),
                child: const Text('Editar perfil'),
              ),
              OutlinedButton(
                onPressed: () =>
                    abrirFormulario(AccionCuenta.cambiarContrasena, cuenta),
                child: const Text('Cambiar contraseña'),
              ),
            ],
          ),
        );
      },
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cerrar'),
      ),
    ],
  );
}

class FormularioCuenta extends StatefulWidget {
  const FormularioCuenta({
    super.key,
    required this.sesion,
    required this.accion,
    this.cuenta,
  });
  final SesionAzure sesion;
  final AccionCuenta accion;
  final CuentaAzure? cuenta;

  @override
  State<FormularioCuenta> createState() => _FormularioCuentaState();
}

class _FormularioCuentaState extends State<FormularioCuenta> {
  final formulario = GlobalKey<FormState>();
  late final nombre = TextEditingController(text: widget.cuenta?.nombre);
  late final correo = TextEditingController(text: widget.cuenta?.correo);
  final actual = TextEditingController();
  final nueva = TextEditingController();
  final confirmar = TextEditingController();
  bool ocupado = false;
  String? error;

  bool get alta => widget.accion == AccionCuenta.registrar;
  bool get cambio => widget.accion == AccionCuenta.cambiarContrasena;

  @override
  void dispose() {
    nombre.dispose();
    correo.dispose();
    actual.dispose();
    nueva.dispose();
    confirmar.dispose();
    super.dispose();
  }

  Future<void> enviar() async {
    if (ocupado || !formulario.currentState!.validate()) return;
    setState(() {
      ocupado = true;
      error = null;
    });
    try {
      switch (widget.accion) {
        case AccionCuenta.registrar:
          final direccion = correo.text.trim();
          await widget.sesion.api.registrarCuenta(
            nombre.text,
            direccion,
            nueva.text,
          );
          if (mounted) Navigator.pop(context, direccion);
        case AccionCuenta.editar:
          await widget.sesion.editarPerfil(nombre.text, correo.text);
        case AccionCuenta.cambiarContrasena:
          await widget.sesion.cambiarContrasena(actual.text, nueva.text);
      }
    } catch (e) {
      if (!mounted) return;
      setState(
        () => error = switch (e) {
          ExcepcionApi(codigo: 'CONTRASENA_ACTUAL_INCORRECTA') =>
            'La contraseña actual es incorrecta.',
          ExcepcionApi(estado: 400 || 403 || 422) when cambio => 'El servidor rechazó el cambio. Revisa la contraseña actual y los requisitos de la nueva.',
          ExcepcionApi(estado: 409) when !cambio =>
            'No se pudo usar ese correo. Comprueba que esté disponible.',
          _ => mensajeSeguro(e),
        },
      );
    } finally {
      if (mounted) setState(() => ocupado = false);
    }
  }

  Widget campoClave(
    String etiqueta,
    TextEditingController control,
    String? Function(String) validar,
  ) => TextFormField(
    controller: control,
    enabled: !ocupado,
    obscureText: true,
    autocorrect: false,
    enableSuggestions: false,
    decoration: InputDecoration(labelText: etiqueta),
    validator: (valor) => validar(valor ?? ''),
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !ocupado,
    child: AlertDialog(
      title: Text(switch (widget.accion) {
        AccionCuenta.registrar => 'Registro de cuenta',
        AccionCuenta.editar => 'Editar perfil',
        AccionCuenta.cambiarContrasena => 'Cambiar contraseña',
      }),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 360,
          child: Form(
            key: formulario,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!alta)
                  const Text('Al guardar, se cerrarán todas tus sesiones.'),
                if (!cambio) ...[
                  TextFormField(
                    controller: nombre,
                    enabled: !ocupado,
                    decoration: const InputDecoration(labelText: 'Nombre'),
                    validator: (valor) => (valor ?? '').trim().isEmpty
                        ? 'Escribe tu nombre.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: correo,
                    enabled: !ocupado,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Correo electrónico',
                    ),
                    validator: (valor) =>
                        RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                            .hasMatch((valor ?? '').trim())
                        ? null
                        : 'Escribe un correo válido.',
                  ),
                ],
                if (cambio) ...[
                  campoClave(
                    'Contraseña actual',
                    actual,
                    (valor) =>
                        valor.isEmpty ? 'Escribe tu contraseña actual.' : null,
                  ),
                  const SizedBox(height: 12),
                ],
                if (alta || cambio) ...[
                  if (alta) const SizedBox(height: 12),
                  campoClave('Nueva contraseña', nueva, (valor) {
                    if (valor.runes.length < 12 ||
                        utf8.encode(valor).length > 72) {
                      return 'Usa al menos 12 caracteres y hasta 72 bytes.';
                    }
                    return cambio && valor == actual.text
                        ? 'La nueva contraseña debe ser distinta.'
                        : null;
                  }),
                  const SizedBox(height: 12),
                  campoClave(
                    'Confirmar contraseña',
                    confirmar,
                    (valor) => valor == nueva.text
                        ? null
                        : 'Las contraseñas no coinciden.',
                  ),
                ],
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: ocupado ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: ocupado ? null : enviar,
          child: Text(
            ocupado
                ? 'Guardando…'
                : alta
                ? 'Registrar cuenta'
                : 'Guardar cambios',
          ),
        ),
      ],
    ),
  );
}
