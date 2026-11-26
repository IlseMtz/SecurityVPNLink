import 'dart:async';
import 'package:flutter/material.dart';
import 'azure_api.dart';

/// Solo ofrece operaciones documentadas en V6. El servidor autoriza cada petición.
class AdministracionCuentasPage extends StatefulWidget {
  const AdministracionCuentasPage({super.key, required this.api, required this.cuentaActual});
  final AzureApi api;
  final CuentaAzure cuentaActual;
  @override
  State<AdministracionCuentasPage> createState() => _AdministracionCuentasPageState();
}

class _AdministracionCuentasPageState extends State<AdministracionCuentasPage> {
  int pagina = 0;
  Future<PaginaAzure>? datos;
  @override
  void initState() {
    super.initState();
    if (widget.cuentaActual.administraCuentas) datos = widget.api.cuentas();
  }
  void cargar(int nueva) => setState(() {
    pagina = nueva;
    datos = widget.api.cuentas(pagina: nueva);
  });
  Future<void> abrir(int id) async {
    await showDialog<void>(context: context, builder: (_) => EstadoCuentaDialog(
      api: widget.api, usuarioId: id, cuentaActual: widget.cuentaActual));
    if (mounted) cargar(pagina);
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Administrar cuentas')),
    body: !widget.cuentaActual.administraCuentas
      ? const Center(child: Text('No tienes permiso para administrar cuentas.'))
      : FutureBuilder<PaginaAzure>(future: datos, builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(mensajeSeguro(snapshot.error!)),
            TextButton(onPressed: () => cargar(pagina), child: const Text('Reintentar')),
          ]));
          final resultado = snapshot.data;
          if (resultado == null) return const Center(child: Text('No hay datos disponibles.'));
          return Column(children: [
            const Padding(padding: EdgeInsets.all(16), child: Text(
              'Suspender una cuenta solicita retirar sus perfiles VPN en todas las redes. '
              'Reactivarla no recupera los perfiles revocados.')),
            Expanded(child: resultado.items.isEmpty
              ? const Center(child: Text('No hay cuentas en esta página.'))
              : ListView.builder(itemCount: resultado.items.length, itemBuilder: (context, index) {
                  final cuenta = resultado.items[index];
                  final id = cuenta['id'];
                  return Card(margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: ListTile(
                      leading: const Icon(Icons.person_outline),
                      title: Text('${cuenta['nombre'] ?? 'Cuenta'}'),
                      subtitle: Text('${cuenta['correo'] ?? ''}\n${cuenta['estado'] ?? 'Sin confirmar'} · Usuario $id'),
                      isThreeLine: true,
                      trailing: const Icon(Icons.chevron_right),
                      onTap: id is int && id > 0 ? () => abrir(id) : null,
                    ));
                })),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              IconButton(tooltip: 'Página anterior', onPressed: pagina > 0 ? () => cargar(pagina - 1) : null,
                icon: const Icon(Icons.chevron_left)),
              Text('Página ${pagina + 1}'),
              IconButton(tooltip: 'Página siguiente', onPressed: resultado.haySiguiente ? () => cargar(pagina + 1) : null,
                icon: const Icon(Icons.chevron_right)),
              IconButton(tooltip: 'Actualizar cuentas', onPressed: () => cargar(pagina), icon: const Icon(Icons.refresh)),
            ]),
          ]);
        }),
  );
}

class EstadoCuentaDialog extends StatefulWidget {
  const EstadoCuentaDialog({super.key, required this.api, required this.usuarioId, required this.cuentaActual});
  final AzureApi api;
  final int usuarioId;
  final CuentaAzure cuentaActual;
  @override
  State<EstadoCuentaDialog> createState() => _EstadoCuentaDialogState();
}

class _EstadoCuentaDialogState extends State<EstadoCuentaDialog> {
  Map<String, dynamic>? cuenta, retirada;
  String? error;
  bool ocupado = false;
  bool consultaPendiente = false;
  int consultas = 0;
  Timer? timer;
  bool get autorizado => widget.cuentaActual.administraCuentas;
  String get estado => '${retirada?['estadoCuenta'] ?? cuenta?['estado'] ?? 'SIN_CONFIRMAR'}';
  bool get completa => retirada?['retiradaCompleta'] == true;

  @override
  void initState() {
    super.initState();
    if (autorizado) cargar();
  }
  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }
  Future<void> cargar() async {
    if (!autorizado || ocupado) return;
    timer?.cancel();
    setState(() { ocupado = true; error = null; cuenta = null; retirada = null; });
    try {
      final perfil = await widget.api.cuentaAdministrada(widget.usuarioId);
      final acceso = await widget.api.accesosCuenta(widget.usuarioId);
      if (!mounted) return;
      setState(() { cuenta = perfil; retirada = acceso; consultaPendiente = false; });
      programar();
    } catch (e) {
      if (mounted) setState(() => error = mensajeSeguro(e));
    } finally {
      if (mounted) setState(() => ocupado = false);
    }
  }
  void programar() {
    timer?.cancel();
    consultas = 0;
    if (estado != 'SUSPENDIDO' || completa) return;
    timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (++consultas > 20) { timer?.cancel(); return; }
      consultarRetirada();
    });
  }
  Future<void> consultarRetirada() async {
    if (!mounted || ocupado || !autorizado) return;
    setState(() { ocupado = true; error = null; });
    try {
      final datos = await widget.api.accesosCuenta(widget.usuarioId);
      if (!mounted) return;
      setState(() { retirada = datos; consultaPendiente = false; });
      if (completa) timer?.cancel();
    } catch (e) {
      timer?.cancel();
      if (mounted) setState(() { error = mensajeSeguro(e); consultaPendiente = true; });
    } finally {
      if (mounted) setState(() => ocupado = false);
    }
  }
  Future<void> cambiar(String nuevo) async {
    if (!autorizado || ocupado || cuenta == null || consultaPendiente) return;
    if (nuevo == 'SUSPENDIDO' && widget.usuarioId == widget.cuentaActual.id) return;
    if (nuevo == 'ACTIVO' && (estado != 'SUSPENDIDO' || !completa)) return;
    final confirmar = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: Text(nuevo == 'SUSPENDIDO' ? 'Suspender cuenta' : 'Reactivar cuenta'),
      content: Text(nuevo == 'SUSPENDIDO'
        ? 'Se impedirá iniciar sesión y se solicitará retirar todos los perfiles VPN de esta cuenta. ¿Continuar?'
        : 'La cuenta podrá volver a iniciar sesión. Sus perfiles revocados no se reactivarán. ¿Continuar?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Confirmar')),
      ],
    ));
    if (confirmar != true || !mounted || ocupado) return;
    timer?.cancel();
    setState(() { ocupado = true; error = null; });
    try {
      final datos = await widget.api.cambiarEstadoCuenta(widget.usuarioId, nuevo);
      if (!mounted) return;
      setState(() { retirada = datos; consultaPendiente = false; });
      programar();
    } catch (e) {
      if (mounted) setState(() { error = mensajeSeguro(e); consultaPendiente = true; });
    } finally {
      if (mounted) setState(() => ocupado = false);
    }
  }
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Cuenta ${widget.usuarioId}'),
    content: SizedBox(width: 560, child: SingleChildScrollView(child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        if (!autorizado) const Text('No tienes permiso para administrar cuentas.')
        else ...[
          if (cuenta != null) Text('${cuenta!['nombre'] ?? ''} · ${cuenta!['correo'] ?? ''}'),
          Text('Estado de cuenta: $estado'),
          if (retirada != null) Text(completa
            ? 'El servidor confirma la retirada completa de los perfiles anteriores.'
            : 'Retirada VPN sin confirmar. No se garantiza todavía el bloqueo de todos los perfiles.'),
          if (retirada?['configuraciones'] is List)
            Text('Configuraciones registradas: ${(retirada!['configuraciones'] as List).length}'),
          if (error != null) Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
          if (consultaPendiente) const Text('Actualiza los datos para comprobar el resultado antes de repetir la operación.'),
          if (ocupado) const Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator()),
          if (widget.usuarioId == widget.cuentaActual.id)
            const Text('No puedes suspender tu propia cuenta.'),
          if (estado == 'ACTIVO' && widget.usuarioId != widget.cuentaActual.id)
            FilledButton(onPressed: ocupado || consultaPendiente ? null : () => cambiar('SUSPENDIDO'), child: const Text('Suspender cuenta')),
          if (estado == 'SUSPENDIDO') ...[
            FilledButton(onPressed: ocupado || consultaPendiente || !completa ? null : () => cambiar('ACTIVO'), child: const Text('Reactivar cuenta')),
            if (!completa && widget.usuarioId != widget.cuentaActual.id)
              TextButton(onPressed: ocupado || consultaPendiente ? null : () => cambiar('SUSPENDIDO'), child: const Text('Reintentar retirada de perfiles')),
          ],
          TextButton(onPressed: ocupado ? null : cargar, child: const Text('Actualizar cuenta y retirada')),
        ],
      ],
    ))),
    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar'))],
  );
}
