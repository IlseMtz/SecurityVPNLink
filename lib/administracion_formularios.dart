import 'dart:convert';
import 'package:flutter/material.dart';
import 'api_error.dart';
import 'azure_api.dart';

String mensajeAdministracion(Object e) {
  if (e is ExcepcionApi && e.codigo == 'CANCELADO') return 'Operación cancelada. No se modificó el grupo.';
  if (e is ExcepcionApi && e.estado == 409) {
    return 'El servidor rechazó el cambio. Puede haber una versión desactualizada, '
      'un nombre o correo duplicado, un rol asignado o una restricción del último ADMIN activo. '
      'Cierra y vuelve a consultar los datos antes de intentar otra vez.';
  }
  return mensajeSeguro(e);
}

int catalogoId(Map<String, dynamic> item, String clave) => idJson(item[clave] ?? item['id']);
bool indicadorActivo(Object? valor) => valor == true || valor == 1;
bool rolProtegido(Map<String, dynamic> rol) =>
    ['ADMIN', 'SOPORTE', 'USUARIO_VPN'].contains(rol['codigo']) ||
    !(rol['sistema'] == false || rol['sistema'] == 0);

String? obligatorio(String valor) => valor.trim().isEmpty ? 'Completa este campo.' : null;
String? correoValido(String valor) => RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(valor.trim())
    ? null : 'Escribe un correo válido.';

class CampoAdministrativo {
  const CampoAdministrativo(this.clave, this.etiqueta, {this.inicial = '', this.secreto = false,
    this.validar, this.editable = true});
  final String clave, etiqueta, inicial;
  final bool secreto, editable;
  final String? Function(String)? validar;
}

/// No muestra cuerpos HTTP ni conserva contraseñas fuera del formulario.
class FormularioAdministrativo extends StatefulWidget {
  const FormularioAdministrativo({super.key, required this.titulo, required this.campos,
    required this.guardar, this.aviso, this.opciones, this.seleccion = const {},
    this.minimo = 0, this.maximo, this.activo, this.confirmacion});
  final String titulo;
  final String? aviso, confirmacion;
  final List<CampoAdministrativo> campos;
  final Map<int, String>? opciones;
  final Set<int> seleccion;
  final int minimo;
  final int? maximo;
  final bool? activo;
  final Future<void> Function(Map<String, String>, Set<int>, bool?) guardar;
  @override
  State<FormularioAdministrativo> createState() => _FormularioAdministrativoState();
}

class _FormularioAdministrativoState extends State<FormularioAdministrativo> {
  final form = GlobalKey<FormState>();
  late final controles = {for (final c in widget.campos) c.clave: TextEditingController(text: c.inicial)};
  late final seleccion = {...widget.seleccion};
  late bool? activo = widget.activo;
  bool ocupado = false, requiereConsulta = false;
  String? error;
  @override
  void dispose() { for (final c in controles.values) { c.dispose(); } super.dispose(); }
  Future<void> enviar() async {
    if (ocupado || requiereConsulta || !form.currentState!.validate()) return;
    if (seleccion.length < widget.minimo || (widget.maximo != null && seleccion.length > widget.maximo!)) {
      setState(() => error = 'Selecciona entre ${widget.minimo} y ${widget.maximo ?? widget.opciones?.length ?? 0} opciones.');
      return;
    }
    if (widget.confirmacion != null && !await confirmarAdministracion(context, widget.titulo, widget.confirmacion!)) return;
    if (!mounted || ocupado) return;
    setState(() { ocupado = true; error = null; });
    try {
      await widget.guardar({for (final c in controles.entries) c.key: c.value.text}, seleccion, activo);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() {
        error = mensajeAdministracion(e);
        requiereConsulta = e is ExcepcionApi && [0, 401, 403, 409, 502, 503, 504].contains(e.estado);
      });
    } finally { if (mounted) setState(() => ocupado = false); }
  }
  @override
  Widget build(BuildContext context) => PopScope(canPop: !ocupado, child: AlertDialog(
    title: Text(widget.titulo),
    content: SizedBox(width: 520, child: SingleChildScrollView(child: Form(key: form,
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (widget.aviso != null) Text(widget.aviso!),
        for (final c in widget.campos) Padding(padding: const EdgeInsets.symmetric(vertical: 8),
          child: TextFormField(controller: controles[c.clave], enabled: !ocupado && c.editable && !requiereConsulta,
            obscureText: c.secreto, autocorrect: !c.secreto, enableSuggestions: !c.secreto,
            keyboardType: c.clave == 'correo' ? TextInputType.emailAddress : TextInputType.text,
            decoration: InputDecoration(labelText: c.etiqueta), validator: (v) => c.validar?.call(v ?? ''))),
        if (activo != null) SwitchListTile(title: const Text('Grupo activo'), value: activo!,
          onChanged: ocupado || requiereConsulta ? null : (v) => setState(() => activo = v)),
        if (widget.opciones != null) ...[
          const SizedBox(height: 12),
          Text('Seleccionados: ${seleccion.length}'),
          for (final o in widget.opciones!.entries) CheckboxListTile(title: Text(o.value), value: seleccion.contains(o.key),
            onChanged: ocupado || requiereConsulta ? null : (v) => setState(() {
              if (v == true) { seleccion.add(o.key); } else { seleccion.remove(o.key); }
            })),
        ],
        if (error != null) Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        if (requiereConsulta) const Text('Cierra este formulario y actualiza la lista antes de volver a abrirlo.'),
        if (ocupado) const LinearProgressIndicator(),
      ])))),
    actions: [TextButton(onPressed: ocupado ? null : () => Navigator.pop(context, false), child: const Text('Cancelar')),
      FilledButton(onPressed: ocupado || requiereConsulta ? null : enviar, child: const Text('Guardar'))],
  ));
}

Future<bool> confirmarAdministracion(BuildContext context, String titulo, String texto) async =>
  await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: Text(titulo), content: Text(texto),
    actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
      FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Confirmar'))])) == true;

Future<bool> formularioCuentaAdministrada(BuildContext context, AzureApi api, {Map<String, dynamic>? cuenta}) async {
  final id = cuenta == null ? null : idJson(cuenta['id']);
  return await showDialog<bool>(context: context, barrierDismissible: false, builder: (_) => FormularioAdministrativo(
    titulo: id == null ? 'Crear cuenta' : 'Editar perfil de cuenta',
    aviso: id == null ? 'La cuenta se crea con USUARIO_VPN. Los roles se asignan por separado.'
      : 'Guardar invalidará las sesiones de esta cuenta.',
    confirmacion: id == null ? null : 'Se actualizará el perfil y se invalidarán sus sesiones. ¿Continuar?',
    campos: [
      CampoAdministrativo('nombre', 'Nombre', inicial: '${cuenta?['nombre'] ?? ''}', validar: obligatorio),
      CampoAdministrativo('correo', 'Correo', inicial: '${cuenta?['correo'] ?? ''}', validar: correoValido),
      if (id == null) CampoAdministrativo('clave', 'Contraseña inicial', secreto: true, validar: (v) =>
        v.runes.length < 12 || utf8.encode(v).length > 72 ? 'Usa al menos 12 caracteres y máximo 72 bytes UTF-8.' : null),
    ],
    guardar: (v, _, _) async {
      if (id == null) { await api.crearCuentaAdministrada(v['nombre']!, v['correo']!, v['clave']!); }
      else { await api.editarCuentaAdministrada(id, v['nombre']!, v['correo']!); }
    },
  )) == true;
}
