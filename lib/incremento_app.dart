import 'administracion_cuentas.dart';
import 'administracion_catalogos.dart';
import 'resumen_vpn.dart';
import 'estado_emision_vpn.dart';
import 'reporte_auditoria.dart';

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'azure_api.dart';
import 'recursos_internos.dart';
import 'dispositivos.dart';
import 'guardar_configuracion.dart';
import 'sesion_azure.dart';
import 'reposicion_perfil.dart';
import 'api_error.dart' show ExcepcionApi;
import 'tema_securelink.dart';
import 'cuenta_propia.dart';
import 'limites_red.dart';
import 'administrar_red.dart';

class IncrementoApp extends StatefulWidget {
  const IncrementoApp({super.key, this.sesion});
  final SesionAzure? sesion;
  @override
  State<IncrementoApp> createState() => _IncrementoAppState();
}

class _IncrementoAppState extends State<IncrementoApp> {
  late final SesionAzure sesion = widget.sesion ?? SesionAzure();
  final navegador = GlobalKey<NavigatorState>();
  @override
  void initState() {
    super.initState();
    sesion.addListener(cambioSesion);
  }

  void cambioSesion() {
    if (sesion.cuenta == null) {
      navegador.currentState?.popUntil((r) => r.isFirst);
    }
  }

  @override
  void dispose() {
    sesion.removeListener(cambioSesion);
    if (widget.sesion == null) sesion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    navigatorKey: navegador,
    title: 'SecureLink VPN Manager',
    debugShowCheckedModeBanner: false,
    theme: crearTemaSecureLink(),
    home: ListenableBuilder(
      listenable: sesion,
      builder: (_, _) => sesion.cuenta == null
          ? AccesoAzurePage(sesion: sesion)
          : RedesPage(sesion: sesion),
    ),
  );
}

class AccesoAzurePage extends StatefulWidget {
  const AccesoAzurePage({super.key, required this.sesion});
  final SesionAzure sesion;
  @override
  State<AccesoAzurePage> createState() => _AccesoAzurePageState();
}

class _AccesoAzurePageState extends State<AccesoAzurePage> {
  final formulario = GlobalKey<FormState>();
  final correo = TextEditingController();
  final clave = TextEditingController();
  bool ocupado = false, ocultar = true;
  String? error;
  String? avisoRegistro;
  @override
  void dispose() {
    correo.dispose();
    clave.dispose();
    super.dispose();
  }

  Future<void> ingresar() async {
    if (ocupado || !formulario.currentState!.validate()) return;
    setState(() {
      ocupado = true;
      error = null;
      avisoRegistro = null;
    });
    try {
      await widget.sesion.ingresar(correo.text, clave.text);
    } catch (e) {
      if (mounted) {
        setState(() => error = e is ExcepcionApi && e.estado == 401
            ? 'Correo o contraseña incorrectos.'
            : mensajeSeguro(e));
      }
    } finally {
      if (mounted) {
        clave.clear();
        setState(() => ocupado = false);
      }
    }
  }

  Future<void> registrar() async {
    final creado = await showDialog<String>(
      context: context,
      builder: (_) => FormularioCuenta(sesion: widget.sesion, accion: AccionCuenta.registrar),
    );
    if (!mounted || creado == null) return;
    correo.text = creado;
    clave.clear();
    setState(() {
      error = null;
      avisoRegistro = 'Cuenta creada. Inicia sesión para acceder al panel.';
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: LayoutBuilder(
                builder: (context, ancho) {
                  final acceso = Padding(
                    padding: const EdgeInsets.all(32),
                    child: Form(
                      key: formulario,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Iniciar sesión',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Administra los dispositivos de tus redes y entrega sus perfiles VPN.',
                          ),
                          const SizedBox(height: 28),
                          TextFormField(
                            controller: correo,
                            enabled: !ocupado,
                            autofillHints: const [AutofillHints.username],
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Correo electrónico',
                            ),
                            validator: (v) =>
                                v == null ||
                                    !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                        .hasMatch(v.trim())
                                ? 'Escribe un correo válido.'
                                : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: clave,
                            enabled: !ocupado,
                            obscureText: ocultar,
                            autocorrect: false,
                            enableSuggestions: false,
                            autofillHints: const [AutofillHints.password],
                            onFieldSubmitted: (_) => ingresar(),
                            decoration: InputDecoration(
                              labelText: 'Contraseña',
                              suffixIcon: IconButton(
                                tooltip: ocultar
                                    ? 'Mostrar contraseña'
                                    : 'Ocultar contraseña',
                                onPressed: () =>
                                    setState(() => ocultar = !ocultar),
                                icon: Icon(
                                  ocultar
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                            ),
                            validator: (v) => v == null || v.isEmpty
                                ? 'Escribe tu contraseña.'
                                : null,
                          ),
                          if (error != null) aviso(error!, esError: true),
                          if (avisoRegistro ?? widget.sesion.avisoAcceso case final mensaje?
                              when error == null) aviso(mensaje),
                          const SizedBox(height: 24),
                          FilledButton(
                            onPressed: ocupado ? null : ingresar,
                            child: Text(
                              ocupado
                                  ? 'Verificando acceso…'
                                  : 'Iniciar sesión',
                            ),
                          ),
                          TextButton(
                            onPressed: ocupado ? null : registrar,
                            child: const Text('Crear cuenta'),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Usa tu cuenta de SecureLink. La sesión se conserva únicamente mientras la aplicación está abierta.',
                            style: TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  );
                  final marca = Container(
                    color: ColoresSecureLink.marino,
                    padding: const EdgeInsets.all(32),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.shield_outlined,
                          color: Colors.white,
                          size: 56,
                        ),
                        SizedBox(height: 18),
                        Text(
                          'SecureLink',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'VPN Manager',
                          style: TextStyle(color: Colors.white70, fontSize: 17),
                        ),
                        SizedBox(height: 32),
                        Text(
                          'Tus redes.\nTus dispositivos.\nAcceso bajo tu control.',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  );
                  return ancho.maxWidth > 720
                      ? IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(child: marca),
                              Expanded(child: acceso),
                            ],
                          ),
                        )
                      : Column(children: [marca, acceso]);
                },
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

Widget aviso(String texto, {bool esError = false}) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 12),
  child: Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: esError ? const Color(0xFFFDECEC) : const Color(0xFFE9F1FC),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      texto,
      style: TextStyle(
        color: esError ? const Color(0xFF9E2020) : ColoresSecureLink.marino,
      ),
    ),
  ),
);

class RedesPage extends StatefulWidget {
  const RedesPage({super.key, required this.sesion});
  final SesionAzure sesion;
  @override
  State<RedesPage> createState() => _RedesPageState();
}

class _RedesPageState extends State<RedesPage> {
  List<RedAzure> redes = [];
  RedAzure? red;
  List<EquipoAzure> equipos = [];
  List<Map<String, dynamic>> miembros = [];
  bool ocupado = true, enviando = false;
  String? error;
  int revision = 0;
  final operacionesRed = <int, SeguimientoRed>{};
  AzureApi get api => widget.sesion.api;
  bool get propietario {
    final cuenta = widget.sesion.cuenta;
    return cuenta != null && (red?.esPropietario(cuenta) ?? false);
  }
  int get redesPropias => redes.where((r) => r.propietarioId == widget.sesion.cuenta?.id).length;
  int get equiposHabilitados => equipos.where((e) => e.activo).length;
  bool get redBloqueada => operacionesRed[red?.id]?.bloqueada ?? false;
  @override
  void initState() {
    super.initState();
    cargarRedes();
  }

  Future<void> cargarRedes() async {
    setState(() {
      ocupado = true;
      error = null;
    });
    try {
      final nuevas = await api.redes();
      if (!mounted) return;
      redes = nuevas;
      if (redes.isEmpty) {
        setState(() {
          red = null;
          equipos = [];
          ocupado = false;
        });
        return;
      }
      final seleccion =
          redes.where((r) => r.id == red?.id).firstOrNull ?? redes.first;
      await cargar(seleccion.id);
    } catch (e) {
      if (mounted) {
        setState(() {
          error = mensajeSeguro(e);
          ocupado = false;
        });
      }
    }
  }

  Future<void> cargar(int id) async {
    final actual = ++revision;
    setState(() {
      ocupado = true;
      error = null;
      equipos = [];
      miembros = [];
      red = null;
    });
    try {
      final nueva = await api.red(id);
      final lista = await api.dispositivos(id);
      final cuenta = widget.sesion.cuenta;
      if (!mounted || actual != revision || cuenta == null) return;
      final integrantes = nueva.esPropietario(cuenta)
          ? await api.miembros(id)
          : <Map<String, dynamic>>[];
      if (!mounted || actual != revision) return;
      setState(() {
        red = nueva;
        equipos = lista;
        miembros = integrantes;
        ocupado = false;
      });
    } catch (e) {
      if (mounted && actual == revision) {
        setState(() {
          ocupado = false;
          error = mensajeSeguro(e);
        });
      }
    }
  }

  Future<void> crearRed() async {
    if (redesPropias >= 3 || enviando) return;
    final datos = await showDialog<DatosRed>(context: context, builder: (_) => const FormularioRed());
    if (datos == null || !mounted) return;
    setState(() { enviando = true; error = null; });
    try {
      final nueva = await api.crearRed(datos.nombre, descripcion: datos.descripcion);
      if (!mounted) return;
      redes = [...redes, nueva];
      await cargar(nueva.id);
    } catch (e) {
      if (mounted) setState(() => error = e is ExcepcionApi && e.estado == 409
          ? 'La red no se pudo crear. Actualiza el listado y revisa el límite de tres redes propias.'
          : mensajeSeguro(e));
    } finally {
      if (mounted) setState(() => enviando = false);
    }
  }

  Future<void> alta() async {
    final seleccion = red;
    if (!propietario || seleccion == null || enviando || redBloqueada || equiposHabilitados >= 5) return;
    final solicitud = await showDialog<SolicitudDispositivo>(
      context: context,
      builder: (_) => AltaEquipoDialog(miembros: miembros),
    );
    if (solicitud == null || !mounted || red?.id != seleccion.id) return;
    setState(() {
      enviando = true;
      error = null;
    });
    try {
      await api.registrar(seleccion.id, solicitud);
      if (mounted) await cargar(seleccion.id);
    } catch (e) {
      if (mounted) setState(() => error = e is ExcepcionApi && e.estado == 409
          ? 'No se pudo registrar el dispositivo. Revisa el estado de la red y el límite de cinco dispositivos habilitados.'
          : mensajeSeguro(e));
    } finally {
      if (mounted) setState(() => enviando = false);
    }
  }

  Future<void> administrarRed() async {
    final seleccion = red;
    if (!propietario || seleccion == null || enviando) return;
    final seguimiento = operacionesRed.putIfAbsent(seleccion.id, () => SeguimientoRed(seleccion))
      ..red = seleccion;
    await abrirSeguimiento(seguimiento, integrantes: miembros);
  }

  Future<void> abrirSeguimiento(SeguimientoRed seguimiento, {List<Map<String, dynamic>>? integrantes}) async {
    final cuenta = widget.sesion.cuenta;
    if (cuenta == null || !seguimiento.red.esPropietario(cuenta)) return;
    await showDialog<void>(context: context, builder: (_) => AdministrarRedDialog(
      api: api, red: seguimiento.red, cuenta: cuenta, miembros: integrantes ?? const [],
      seguimiento: seguimiento, soloSeguimiento: integrantes == null,
    ));
    if (mounted && widget.sesion.cuenta != null) await cargarRedes();
  }

  Future<void> editarEquipo(EquipoAzure equipo) async {
    final seleccion = red;
    final version = equipo.version;
    if (!propietario || seleccion == null || version == null || redBloqueada || enviando) return;
    final datos = await showDialog<DatosEquipo>(context: context, builder: (_) => FormularioEquipo(equipo: equipo));
    if (datos == null || !mounted || !propietario || red?.id != seleccion.id) return;
    setState(() { enviando = true; error = null; });
    try {
      await api.editarDispositivo(seleccion.id, equipo.id, datos.nombre, datos.sistemaOperativo, version);
      if (mounted) await cargar(seleccion.id);
    } catch (e) {
      if (mounted) setState(() => error = errorAdministracion(e));
    } finally {
      if (mounted) setState(() => enviando = false);
    }
  }

  Future<void> detalle(EquipoAzure equipo) async {
    final seleccion = red!;
    await showDialog<void>(
      context: context,
      builder: (_) => EquipoDialog(
        api: api,
        red: seleccion,
        equipo: equipo,
        cuenta: widget.sesion.cuenta!,
      ),
    );
    if (mounted && widget.sesion.cuenta != null && red?.id == seleccion.id) {
      await cargar(seleccion.id);
    }
  }

  Future<void> abrirAdministracion(String tipo) async {
    try {
      await widget.sesion.actualizarPermisos();
      final cuenta = widget.sesion.cuenta;
      if (!mounted || cuenta == null) return;
      if (tipo == 'cuentas' ? !cuenta.abreCuentas : !cuenta.administraCuentas) {
        setState(() => error = 'No tienes permiso para esta operación.');
        return;
      }
      await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => tipo == 'cuentas'
        ? AdministracionCuentasPage(api: api, cuentaActual: cuenta)
        : CatalogosAdministrativosPage(api: api, cuentaActual: cuenta, grupos: tipo == 'grupos')));
      if (mounted && widget.sesion.cuenta != null) await widget.sesion.actualizarPermisos();
    } catch (e) { if (mounted) setState(() => error = mensajeSeguro(e)); }
  }

  Future<void> verAuditoria() async {
    final seleccion = red;
    if (!propietario || seleccion == null) return;
    await showDialog<void>(
      context: context,
      builder: (_) => AuditoriaDialog(api: api, redId: seleccion.id),
    );
  }

  Future<void> salir() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Cerrar todas mis sesiones'),
        content: const Text(
          'El servidor invalidará todas las sesiones API de esta cuenta, también en otros equipos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Cerrar sesiones'),
          ),
        ],
      ),
    );
    if (mounted && confirmar == true) await widget.sesion.salir();
  }

  @override
  Widget build(BuildContext context) {
    final cuenta = widget.sesion.cuenta!;
    return Scaffold(
      appBar: AppBar(
        title: const Text('SecureLink'),
        actions: [
          if (MediaQuery.sizeOf(context).width > 650)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(child: Text(cuenta.nombre)),
            ),
          IconButton(
            tooltip: 'Mi cuenta',
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => MiCuentaDialog(sesion: widget.sesion),
            ),
            icon: const Icon(Icons.manage_accounts_outlined),
          ),
          IconButton(
            tooltip: 'Cerrar todas mis sesiones',
            onPressed: salir,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Dispositivos autorizados',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Registra equipos y entrega su configuración de WireGuard.',
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Actualizar redes y dispositivos',
                      onPressed: ocupado ? null : cargarRedes,
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Wrap(spacing: 12, runSpacing: 8, children: [
                  if (cuenta.abreCuentas)
                    OutlinedButton.icon(icon: const Icon(Icons.manage_accounts),
                      label: const Text('Administrar cuentas'),
                      onPressed: () => abrirAdministracion('cuentas')),
                  if (cuenta.administraCuentas) ...[
                    OutlinedButton.icon(icon: const Icon(Icons.admin_panel_settings_outlined),
                      label: const Text('Roles y permisos'), onPressed: () => abrirAdministracion('roles')),
                    OutlinedButton.icon(icon: const Icon(Icons.groups_outlined),
                      label: const Text('Grupos administrativos'), onPressed: () => abrirAdministracion('grupos')),
                  ],
                  if (cuenta.consultaAuditoria)
                    OutlinedButton.icon(icon: const Icon(Icons.history),
                      label: const Text('Auditoría global'),
                      onPressed: () => showDialog<void>(context: context,
                        builder: (_) => AuditoriaDialog(api: api))),
                  if (cuenta.administraCuentas)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.dns_outlined),
                      label: const Text('Catálogo de recursos internos'),
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                        builder: (_) => RecursosInternosPage(api: api),
                      )),
                    ),
                ]),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (redes.isNotEmpty)
                      SizedBox(
                        width: 320,
                        child: DropdownButtonFormField<int>(
                          key: ValueKey(red?.id),
                          initialValue: red?.id,
                          decoration: const InputDecoration(
                            labelText: 'Red seleccionada',
                          ),
                          items: redes
                              .map(
                                (r) => DropdownMenuItem(
                                  value: r.id,
                                  child: Text(
                                    r.nombre,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: ocupado || enviando
                              ? null
                              : (id) {
                                  if (id != null) cargar(id);
                                },
                        ),
                      ),
                    OutlinedButton.icon(
                      onPressed: ocupado || enviando || redesPropias >= 3 ? null : crearRed,
                      icon: const Icon(Icons.add),
                      label: const Text('Crear red'),
                    ),
                    if (redesPropias >= 3) const Text('Límite de tres redes propias alcanzado.'),
                    if (propietario)
                      OutlinedButton.icon(onPressed: enviando ? null : administrarRed,
                        icon: const Icon(Icons.settings_outlined), label: const Text('Administrar red')),
                    if (red != null)
                      Chip(
                        label: Text(
                          propietario
                              ? 'Propietario de la red'
                              : 'Miembro de la red',
                        ),
                      ),
                  ],
                ),
                if (error != null) aviso(error!, esError: true),
                for (final seguimiento in operacionesRed.values)
                  if (seguimiento.operacion != null && seguimiento.red.esPropietario(cuenta))
                    Align(alignment: Alignment.centerLeft, child: TextButton.icon(
                      onPressed: ocupado || enviando ? null : () => abrirSeguimiento(seguimiento),
                      icon: const Icon(Icons.history_toggle_off),
                      label: Text('Operación de ${seguimiento.red.nombre}: ${seguimiento.operacion!.estado}'),
                    )),
                if (ocupado)
                  const Padding(
                    padding: EdgeInsets.all(48),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (redes.isEmpty && error == null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 52),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.hub_outlined,
                          size: 54,
                          color: ColoresSecureLink.azul,
                        ),
                        const SizedBox(height: 16),
                        const Text('Todavía no tienes redes.'),
                        const SizedBox(height: 8),
                        const Text(
                          'Crea una red para registrar sus primeros dispositivos.',
                        ),
                      ],
                    ),
                  )
                else if (red != null) ...[
                  const SizedBox(height: 20),
                  aviso(
                    'Estado de la red: ${red!.estado}. ${red!.cidr == null ? 'La subred se asignará con la primera configuración aplicada.' : 'Subred: ${red!.cidr}.'} Un dispositivo habilitado no equivale a una conexión activa.',
                  ),
                  if (red!.descripcion.isNotEmpty) Text(red!.descripcion),
                  if (redBloqueada) const Text('Hay una operación administrativa sin aplicar. Consulta su estado en Administrar red.'),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${equipos.length} dispositivos',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      if (propietario)
                        FilledButton.icon(
                          onPressed: enviando || redBloqueada || equiposHabilitados >= 5 || red!.estado == 'SUSPENDIDA'
                              ? null
                              : alta,
                          icon: const Icon(Icons.add),
                          label: const Text('Registrar dispositivo'),
                        ),
                    ],
                  ),
                  if (propietario)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => showDialog<void>(
                          context: context,
                          builder: (_) => LimitesRedDialog(api: api, red: red!),
                        ),
                        icon: const Icon(Icons.tune),
                        label: const Text('Límites de la red'),
                      ),
                    ),
                  if (propietario) Text('$equiposHabilitados de 5 dispositivos habilitados.'),
                  if (!propietario)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'Solo el propietario de la red puede registrar equipos.',
                      ),
                    ),
                  const SizedBox(height: 16),
                  if (equipos.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('Esta red aún no tiene dispositivos.'),
                    ),
                  for (final equipo in equipos)
                    Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        leading: Icon(
                          equipo.sistemaOperativo == 'IOS' ||
                                  equipo.sistemaOperativo == 'ANDROID'
                              ? Icons.smartphone
                              : Icons.computer,
                          color: ColoresSecureLink.azul,
                          size: 32,
                        ),
                        title: Text(equipo.nombre),
                        subtitle: Text(
                          '${equipo.sistemaOperativo} · Usuario ${equipo.usuarioId}\n${equipo.estado} · Dispositivo ${equipo.id}',
                        ),
                        isThreeLine: true,
                        trailing: propietario
                            ? IconButton(
                                tooltip: equipo.version == null ? 'Versión del dispositivo no disponible' : 'Editar dispositivo ${equipo.nombre}',
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: enviando || redBloqueada || equipo.version == null ? null : () => editarEquipo(equipo),
                              )
                            : const Icon(Icons.chevron_right),
                        onTap: () => detalle(equipo),
                      ),
                    ),
                  if (propietario && red != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        icon: const Icon(Icons.vpn_lock_outlined),
                        label: const Text('Acceso a recursos internos'),
                        onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                          builder: (_) => RecursosInternosPage(api: api, red: red),
                        )),
                      ),
                    ),
                  if (propietario)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: verAuditoria,
                        icon: const Icon(Icons.history),
                        label: const Text('Consultar auditoría de esta red'),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AltaEquipoDialog extends StatefulWidget {
  const AltaEquipoDialog({super.key, required this.miembros});
  final List<Map<String, dynamic>> miembros;
  @override
  State<AltaEquipoDialog> createState() => _AltaEquipoDialogState();
}

class _AltaEquipoDialogState extends State<AltaEquipoDialog> {
  final formulario = GlobalKey<FormState>();
  final nombre = TextEditingController();
  int? usuarioId;
  String? so;
  @override
  void dispose() {
    nombre.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activos = widget.miembros
        .where((m) => m['estado'] == 'ACTIVO')
        .toList();
    return AlertDialog(
      title: const Text('Registrar dispositivo'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Form(
            key: formulario,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Asocia el equipo a un miembro activo de esta red.'),
                const SizedBox(height: 20),
                DropdownButtonFormField<int>(
                  initialValue: usuarioId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Propietario del dispositivo',
                  ),
                  items: activos
                      .map(
                        (m) => DropdownMenuItem(
                          value: idJson(m['usuarioId']),
                          child: Text(
                            '${m['nombre']} (${m['correo']})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => usuarioId = v),
                  validator: (v) =>
                      v == null ? 'Selecciona un miembro activo.' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: nombre,
                  maxLength: 100,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del dispositivo',
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Escribe el nombre del dispositivo.'
                      : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: so,
                  decoration: const InputDecoration(
                    labelText: 'Sistema operativo',
                  ),
                  items: sistemasOperativosDispositivo
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) => setState(() => so = v),
                  validator: (v) =>
                      v == null ? 'Selecciona el sistema operativo.' : null,
                ),
                if (activos.isEmpty)
                  aviso(
                    'No hay miembros activos disponibles para registrar equipos.',
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
          onPressed: activos.isEmpty
              ? null
              : () {
                  if (formulario.currentState!.validate()) {
                    Navigator.pop(
                      context,
                      SolicitudDispositivo(
                        usuarioId: '$usuarioId',
                        nombre: nombre.text.trim(),
                        sistemaOperativo: so!,
                      ),
                    );
                  }
                },
          child: const Text('Registrar'),
        ),
      ],
    );
  }
}

class EquipoDialog extends StatefulWidget {
  const EquipoDialog({
    super.key,
    required this.api,
    required this.red,
    required this.equipo,
    required this.cuenta,
  });
  final AzureApi api;
  final RedAzure red;
  final EquipoAzure equipo;
  final CuentaAzure cuenta;
  @override
  State<EquipoDialog> createState() => _EquipoDialogState();
}

class _EquipoDialogState extends State<EquipoDialog> {
  Map<String, dynamic>? vpn, operacion, conexion;
  String? error;
  bool ocupado = false, consultando = false, redActiva = false;
  Timer? timer;
  Timer? timerActividad;
  bool observando = false;
  bool get propietario => widget.red.esPropietario(widget.cuenta);
  bool get acceso => propietario || widget.equipo.usuarioId == widget.cuenta.id;
  bool revocacionSolicitada = false;
  int revisionPerfil = 0;
  String? modoTunel;
  String? estadoRed;
  bool get permiteEmision => estadoRed == 'ACTIVA' || estadoRed == 'PENDIENTE';
  bool get retiradaPersistida => ['REVOCADA', 'REVOCADO'].contains(vpn?['estadoDeseado']) || ['REVOCADA', 'REVOCADO'].contains(vpn?['estadoAplicado']);
  bool get bloqueaPerfil => revocacionSolicitada || retiradaPersistida;
  int consultasRevocacion = 0;
  bool get aplicada => !bloqueaPerfil && puedeEntregarPerfil(
    redActiva: redActiva,
    dispositivoActivo: widget.equipo.activo,
    cuentaActiva: widget.cuenta.estado == 'ACTIVO',
    estadoPerfil: vpn?['estadoAplicado'] as String?,
    estadoOperacion: operacion?['estado'] as String?,
    consultaEnCurso: consultando,
  );
  @override
  void initState() {
    super.initState();
    estadoRed = widget.red.estado;
    redActiva = widget.red.estado == 'ACTIVA';
    modoTunel = widget.red.modoTunel;
    if (acceso) consultarVpn();
  }

  @override
  void dispose() {
    timer?.cancel();
    timerActividad?.cancel();
    super.dispose();
  }

  Future<void> consultarVpn() async {
    final revision = ++revisionPerfil;
    setState(() => vpn = null);
    try {
      final red = await widget.api.red(widget.red.id);
      if (!mounted || revision != revisionPerfil) return;
      setState(() {
        estadoRed = red.estado;
        redActiva = red.estado == 'ACTIVA';
        modoTunel = red.modoTunel;
      });
      final datos = await widget.api.vpn(widget.red.id, widget.equipo.id);
      if (mounted && revision == revisionPerfil) {
        setState(() {
          vpn = datos;
          redActiva = red.estado == 'ACTIVA';
          modoTunel = red.modoTunel;
        });
      }
    } catch (e) {
      if (mounted &&
          revision == revisionPerfil &&
          !(e is ExcepcionApi && e.estado == 404)) {
        setState(() => error = mensajeSeguro(e));
      }
    }
  }

  Future<void> revocarDispositivo() async {
    if (!propietario || ocupado || consultando ||
        (bloqueaPerfil && !['FALLIDA', 'CANCELADA'].contains(operacion?['estado'])) ||
        !widget.equipo.activo || widget.cuenta.estado != 'ACTIVO') return;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Confirmar revocación'),
        content: const Text('Se solicitará retirar el acceso de este dispositivo sin crear un reemplazo.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Confirmar revocación')),
        ],
      ),
    );
    if (confirmar != true || !mounted || ocupado || consultando) return;
    timer?.cancel();
    timerActividad?.cancel();
    revisionPerfil++;
    consultasRevocacion = 0;
    setState(() {
      ocupado = true;
      revocacionSolicitada = true;
      vpn = null;
      conexion = null;
      error = null;
      operacion = {'estado': 'SIN_CONFIRMAR'};
    });
    try {
      final respuesta = await widget.api.revocar(widget.red.id, widget.equipo.id);
      if (!mounted) return;
      setState(() => operacion = respuesta);
      // Consultar no equivale a volver a enviar la revocación.
      if (!terminal && respuesta['id'] is String) {
        timer = Timer.periodic(const Duration(seconds: 3), (_) {
          if (++consultasRevocacion > 20) {
            timer?.cancel();
          } else {
            actualizarOperacion();
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = mensajeSeguro(e));
      // Un fallo de transporte no demuestra que el servidor rechazó la orden.
    } finally {
      if (mounted) setState(() => ocupado = false);
    }
  }

  Future<void> solicitar() async {
    if (bloqueaPerfil || ocupado ||
        !propietario ||
        !widget.equipo.activo ||
        !permiteEmision ||
        widget.cuenta.estado != 'ACTIVO' ||
        (operacion != null && !terminal)) {
      return;
    }
    revisionPerfil++;
    timer?.cancel();
    setState(() {
      ocupado = true;
      vpn = null;
      operacion = {'estado': 'SIN_CONFIRMAR'};
      error = null;
    });
    try {
      final datos = await widget.api.solicitar(widget.red.id, widget.equipo.id);
      if (!mounted) return;
      setState(() => operacion = datos);
      await actualizarOperacion();
      timer?.cancel();
      if (mounted && !terminal) {
        timer = Timer.periodic(
          const Duration(seconds: 4),
          (_) => actualizarOperacion(),
        );
      }
    } catch (e) {
      if (mounted) setState(() => error = mensajeSeguro(e));
    } finally {
      if (mounted) setState(() => ocupado = false);
    }
  }

  bool get terminal =>
      ['APLICADA', 'FALLIDA', 'CANCELADA'].contains(operacion?['estado']);
  Future<void> actualizarOperacion() async {
    if (consultando || operacion?['id'] is! String) return;
    setState(() => consultando = true);
    try {
      final nueva = await widget.api.operacion(
        widget.red.id,
        operacion!['id'] as String,
      );
      if (!mounted) return;
      setState(() {
        operacion = nueva;
        error = null;
      });
      if (terminal) {
        timer?.cancel();
        if (nueva['estado'] == 'APLICADA' && !revocacionSolicitada) await consultarVpn();
      }
    } catch (e) {
      timer?.cancel();
      if (mounted) setState(() => error = mensajeSeguro(e));
    } finally {
      if (mounted) setState(() => consultando = false);
    }
  }

  Future<void> observar() async {
    if (!mounted || !acceso || bloqueaPerfil || !widget.equipo.activo || observando || ocupado) {
      return;
    }
    timerActividad ??= Timer.periodic(
      const Duration(seconds: 30),
      (_) => observar(),
    );
    setState(() {
      observando = true;
      ocupado = true;
      error = null;
    });
    try {
      final datos = await widget.api.conexion(widget.red.id, widget.equipo.id);
      if (mounted) setState(() => conexion = datos);
    } catch (e) {
      if (mounted) setState(() => error = mensajeSeguro(e));
    } finally {
      if (mounted) {
        setState(() {
          observando = false;
          ocupado = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.equipo.nombre),
    content: SizedBox(
      width: 560,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${widget.equipo.sistemaOperativo} · Usuario ${widget.equipo.usuarioId} · ${widget.equipo.estado}',
            ),
            const SizedBox(height: 12),
            if (!acceso)
              aviso(
                'Solo el propietario de la red o del dispositivo puede obtener su configuración.',
              ),
            if (error != null) aviso(error!, esError: true),
            if (bloqueaPerfil) ...[
              aviso('Revocación: ${operacion?['estado'] ?? vpn?['estadoAplicado'] ?? 'SIN_CONFIRMAR'}. '
                '${operacion?['estado'] == 'APLICADA' ? 'El servidor confirmó la retirada del perfil.' : 'La entrega de configuración permanece bloqueada. Una solicitud pendiente no confirma la retirada.'}'),
              if (operacion?['id'] == null)
                TextButton(onPressed: ocupado ? null : consultarVpn,
                  child: const Text('Verificar estado del perfil')),
              if (propietario && ['FALLIDA', 'CANCELADA'].contains(operacion?['estado']))
                TextButton(onPressed: ocupado || consultando ? null : revocarDispositivo,
                  child: const Text('Reintentar revocación')),
            ],
            if (operacion != null && !bloqueaPerfil)
              aviso(
                operacion!['estado'] == 'SIN_CONFIRMAR'
                    ? 'Emisión sin confirmar. No repitas la solicitud hasta verificar en el servidor si se registró; no se habilitará la entrega del perfil anterior.'
                    : 'Operación: ${operacion!['estado'] ?? 'PENDIENTE'}. ${terminal ? '' : 'Todavía no confirma la aplicación del perfil.'}',
              ),
            if (!bloqueaPerfil) ResumenVpn(
              operacion: operacion,
              modo: modoTunel,
              conexion: conexion,
            ),
            if (vpn != null) ...[
              Text(
                'Configuración aplicada: ${vpn!['estadoAplicado'] ?? 'Sin confirmar'}',
              ),
              if (vpn!['direccionIp'] != null)
                Text('IP asignada: ${vpn!['direccionIp']}'),
            ],
            if (propietario && widget.equipo.activo && !bloqueaPerfil) ...[
              OutlinedButton(
                onPressed: ocupado || consultando || widget.cuenta.estado != 'ACTIVO' ? null : revocarDispositivo,
                child: const Text('Revocar dispositivo'),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed:
                    ocupado ||
                        !permiteEmision ||
                        widget.cuenta.estado != 'ACTIVO' ||
                        (operacion != null && !terminal)
                    ? null
                    : solicitar,
                child: Text(
                  ocupado ? 'Procesando…' : 'Solicitar configuración VPN',
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'La provisión la realiza el agente. Un estado pendiente o fallido no confirma acceso a la VPN.',
              ),
            ],
            if (operacion != null)
              TextButton(
                onPressed: ocupado || consultando || operacion?['id'] is! String
                    ? null
                    : actualizarOperacion,
                child: const Text('Actualizar operación'),
              ),
            if (acceso && widget.equipo.activo && !bloqueaPerfil) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                icon: const Icon(Icons.qr_code),
                onPressed: aplicada && !ocupado
                    ? () => showDialog<void>(
                        context: context,
                        builder: (_) => EntregaDialog(
                          api: widget.api,
                          redId: widget.red.id,
                          equipo: widget.equipo,
                        ),
                      )
                    : null,
                label: const Text('Entregar archivo o QR'),
              ),
              if (!aplicada)
                const Text(
                  'La entrega se habilita cuando el perfil esté aplicado y la red esté activa.',
                ),
              TextButton(
                onPressed: ocupado ? null : consultarVpn,
                child: const Text('Actualizar configuración'),
              ),
              TextButton(
                onPressed: ocupado ? null : observar,
                child: const Text('Consultar actividad observada'),
              ),
            ],
            if (propietario && widget.equipo.activo && !bloqueaPerfil)
              TextButton(
                onPressed: ocupado ? null : reponer,
                child: const Text('Reponer un perfil perdido'),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cerrar'),
      ),
    ],
  );

  Future<void> reponer() async {
    if (bloqueaPerfil || ocupado || !propietario) return;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Reponer perfil perdido'),
        content: const Text(
          'Si no existe copia protegida recuperable, se debe revocar definitivamente el perfil actual y registrar un dispositivo nuevo. El perfil anterior dejará de servir. ¿Confirmas que necesitas reemplazarlo?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Revocar y reponer'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;
    setState(() {
      ocupado = true;
      error = null;
    });
    try {
      final repuesto = await ReposicionPerfil(widget.api).ejecutar(
        widget.red,
        widget.equipo,
        widget.cuenta,
        vigente: () => mounted,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Perfil anterior revocado. Abre el nuevo dispositivo ${repuesto.equipo.id} para verificar la aplicación y entregar su configuración.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is ReposicionPendiente
              ? 'Revocación ${e.estado}. No se ha confirmado una nueva entrega. Actualiza el estado antes de continuar.'
              : '${mensajeSeguro(e)} Si la revocación ya se aplicó, el perfil anterior sigue revocado; revisa los dispositivos antes de repetir.',
        );
      }
    } finally {
      if (mounted) setState(() => ocupado = false);
    }
  }
}

class EntregaDialog extends StatefulWidget {
  const EntregaDialog({
    super.key,
    required this.api,
    required this.redId,
    required this.equipo,
  });
  final AzureApi api;
  final int redId;
  final EquipoAzure equipo;
  @override
  State<EntregaDialog> createState() => _EntregaDialogState();
}

class _EntregaDialogState extends State<EntregaDialog>
    with WidgetsBindingObserver {
  bool identidad = false, ocupado = false;
  String? error, resultado;
  Uint8List? imagen;
  void borrar() {
    final anterior = imagen;
    imagen = null;
    if (anterior != null) {
      MemoryImage(anterior).evict();
      anterior.fillRange(0, anterior.length, 0);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    borrar();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && mounted) {
      setState(() {
        borrar();
        identidad = false;
      });
    }
  }

  Future<void> entregar(bool qr) async {
    if (!identidad || ocupado) return;
    setState(() {
      ocupado = true;
      error = null;
      resultado = null;
      borrar();
    });
    Uint8List? archivo;
    try {
      if (qr) {
        final bytes = await widget.api.qr(widget.redId, widget.equipo.id);
        if (mounted && identidad) {
          setState(() => imagen = bytes);
        } else {
          bytes.fillRange(0, bytes.length, 0);
        }
      } else {
        archivo = await widget.api.archivo(widget.redId, widget.equipo.id);
        if (!mounted || !identidad) return;
        final guardado = await guardarConfiguracion(
          archivo,
          'securelink-red-${widget.redId}-equipo-${widget.equipo.id}.conf',
        );
        if (mounted) {
          setState(
            () => resultado = guardado
                ? 'Se solicitó guardar el archivo. Entrégalo únicamente al propietario e impórtalo desde WireGuard.'
                : 'Se canceló el guardado.',
          );
        }
      }
    } catch (e) {
      if (mounted) setState(() => error = mensajeSeguro(e));
    } finally {
      final bytes = archivo;
      if (bytes != null) bytes.fillRange(0, bytes.length, 0);
      if (mounted) setState(() => ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Entrega presencial de configuración'),
    content: SizedBox(
      width: 520,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${widget.equipo.nombre} · Propietario: usuario ${widget.equipo.usuarioId}',
            ),
            aviso(
              'El archivo y el QR contienen una clave privada. El propietario puede importarlos en WireGuard sin entrar previamente al panel. No los publiques, captures ni compartas con otras personas.',
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'He verificado presencialmente la identidad del propietario y le entregaré su propio perfil.',
              ),
              value: identidad,
              onChanged: ocupado
                  ? null
                  : (v) => setState(() {
                      identidad = v == true;
                      if (!identidad) borrar();
                    }),
            ),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: identidad && !ocupado
                      ? () => entregar(false)
                      : null,
                  icon: const Icon(Icons.download),
                  label: const Text('Descargar .conf'),
                ),
                OutlinedButton.icon(
                  onPressed: identidad && !ocupado
                      ? () => entregar(true)
                      : null,
                  icon: const Icon(Icons.qr_code),
                  label: const Text('Mostrar QR'),
                ),
              ],
            ),
            if (ocupado)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (error != null) aviso(error!, esError: true),
            if (resultado != null) aviso(resultado!),
            if (imagen != null) ...[
              const SizedBox(height: 16),
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(16),
                child: Image.memory(
                  imagen!,
                  width: 280,
                  height: 280,
                  gaplessPlayback: false,
                  errorBuilder: (_, _, _) => const Text(
                    'No se pudo mostrar el QR. Cierra esta ventana y vuelve a solicitarlo.',
                  ),
                ),
              ),
              TextButton(
                onPressed: () => setState(borrar),
                child: const Text('Ocultar y descartar QR'),
              ),
            ],
            const SizedBox(height: 16),
            const Text(
              'Después de importar, conecta WireGuard y verifica la salida IPv4 y el aislamiento entre redes según las indicaciones de tu administrador. Descargar el perfil no confirma una conexión activa.',
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cerrar y descartar'),
      ),
    ],
  );
}

class AuditoriaDialog extends StatefulWidget {
  const AuditoriaDialog({super.key, required this.api, this.redId});
  final AzureApi api;
  final int? redId;
  @override
  State<AuditoriaDialog> createState() => _AuditoriaDialogState();
}

class _AuditoriaDialogState extends State<AuditoriaDialog> {
  final usuario = TextEditingController();
  final dispositivo = TextEditingController();
  final desde = TextEditingController();
  final hasta = TextEditingController();
  String filtroUsuario = '';
  String filtroDispositivo = '';
  DateTime? inicio, fin;
  String? errorFiltros;
  @override
  void dispose() {
    usuario.dispose(); dispositivo.dispose(); desde.dispose(); hasta.dispose();
    super.dispose();
  }
  DateTime? fechaFiltro(String texto) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(texto)) return null;
    final fecha = DateTime.tryParse('${texto}T00:00:00Z');
    return fecha != null && fecha.toIso8601String().startsWith(texto) ? fecha : null;
  }
  void aplicarFiltros() {
    final a = desde.text.trim(), b = hasta.text.trim(), u = usuario.text.trim();
    final d = fechaFiltro(a), h = fechaFiltro(b);
    final equipo = dispositivo.text.trim();
    bool idInvalido(String id) => id.isNotEmpty &&
        (!RegExp(r'^[1-9]\d*$').hasMatch(id) || int.tryParse(id) == null);
    setState(() {
      if (idInvalido(u) || idInvalido(equipo) ||
          (a.isNotEmpty && d == null) || (b.isNotEmpty && h == null) ||
          (d != null && h != null && d.isAfter(h))) {
        errorFiltros = 'Usa un ID positivo y fechas válidas AAAA-MM-DD, desde antes de hasta.';
        return;
      }
      errorFiltros = null;
      filtroUsuario = u; filtroDispositivo = equipo; inicio = d; fin = h?.add(const Duration(days: 1));
      pagina = 0;
      datos = cargar();
    });
  }
  bool coincide(Map<String, dynamic> evento) {
    if (filtroUsuario.isNotEmpty &&
        '${evento['usuarioId'] ?? evento['actorId']}' != filtroUsuario) return false;
    if (filtroDispositivo.isNotEmpty &&
        (evento['objetoTipo'] != 'DISPOSITIVO' ||
        evento['objetoId'].toString() != filtroDispositivo)) return false;
    if (inicio == null && fin == null) return true;
    final fecha = DateTime.tryParse('${evento['fecha'] ?? evento['fechaEvento']}');
    return fecha != null && (inicio == null || !fecha.isBefore(inicio!)) &&
        (fin == null || fecha.isBefore(fin!));
  }
  Future<void> exportarPagina(List<Map<String, dynamic>> eventos, {bool pdf = false}) async {
    if (!kIsWeb) return;
    try {
      await guardarConfiguracion(
        pdf ? await pdfAuditoria(eventos) : csvAuditoria(eventos),
        'securelink-auditoria-pagina-${pagina + 1}.${pdf ? 'pdf' : 'csv'}',
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo descargar el reporte.')),
      );
    }
  }

  int pagina = 0;
  Future<PaginaAzure> cargar() => widget.api.paginaAuditoria(
    redId: widget.redId, pagina: pagina,
    usuarioId: filtroUsuario.isEmpty ? null : int.parse(filtroUsuario),
    dispositivoId: int.tryParse(filtroDispositivo),
    desde: inicio, hasta: fin?.subtract(const Duration(milliseconds: 1)));
  late Future<PaginaAzure> datos = cargar();
  void cambiarPagina(int nueva) => setState(() { pagina = nueva; datos = cargar(); });
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.redId == null ? 'Auditoría global' : 'Auditoría de la red'),
    content: SizedBox(
      width: 640,
      height: 600,
      child: Column(children: [
        const Text('Busca en el historial del servidor. Fechas en UTC.'),
        TextFormField(controller: usuario, decoration: const InputDecoration(labelText: 'Usuario')),
        TextFormField(controller: dispositivo, decoration: const InputDecoration(labelText: 'Dispositivo')),
        TextFormField(controller: desde, decoration: const InputDecoration(labelText: 'Desde', hintText: 'AAAA-MM-DD')),
        TextFormField(controller: hasta, decoration: const InputDecoration(labelText: 'Hasta', hintText: 'AAAA-MM-DD')),
        Wrap(children: [
          TextButton(onPressed: aplicarFiltros, child: const Text('Aplicar filtros')),
          TextButton(onPressed: () { usuario.clear(); dispositivo.clear(); desde.clear(); hasta.clear(); aplicarFiltros(); },
            child: const Text('Limpiar filtros')),
        ]),
        if (errorFiltros != null) Text(errorFiltros!),
        Expanded(child: FutureBuilder<PaginaAzure>(
        future: datos,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                aviso(mensajeSeguro(snapshot.error!), esError: true),
                TextButton(
                  onPressed: () => setState(
                    () => datos = cargar(),
                  ),
                  child: const Text('Reintentar'),
                ),
              ],
            );
          }
          if (snapshot.connectionState != ConnectionState.done || !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.data!.items.isEmpty && pagina == 0) {
            return const Center(
              child: Text('No hay eventos disponibles para esta consulta.'),
            );
          }
          final visibles = snapshot.data!.items.where(coincide).toList();
          return Column(children: [
            Expanded(child: visibles.isEmpty
              ? const Center(child: Text('Sin eventos para estos filtros.'))
              : ListView(children: [
              for (final evento in visibles)
                ListTile(
                  title: Text(
                    '${evento['accion'] ?? 'Operación'} · ${evento['resultado'] ?? ''}',
                  ),
                  subtitle: Text(
                    'Actor: ${evento['usuarioId'] ?? evento['actorId'] ?? 'No disponible'} · Objeto: ${evento['objetoId'] ?? evento['entidadId'] ?? 'No disponible'}\n${evento['fecha'] ?? evento['fechaEvento'] ?? ''}',
                  ),
                ),
            ])),
            if (kIsWeb)
              Wrap(
                children: [
                  for (final formato in ['CSV', 'PDF'])
                    TextButton.icon(
                      onPressed: visibles.isEmpty ? null : () => exportarPagina(visibles, pdf: formato == 'PDF'),
                      icon: const Icon(Icons.download),
                      label: Text('Exportar esta página ($formato)'),
                    ),
                ],
              ),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              IconButton(tooltip: 'Página anterior', onPressed: pagina > 0 ? () => cambiarPagina(pagina - 1) : null,
                icon: const Icon(Icons.chevron_left)),
              Text('Página ${pagina + 1}${snapshot.data!.total == null ? '' : ' · ${snapshot.data!.total} eventos'}'),
              IconButton(tooltip: 'Página siguiente', onPressed: snapshot.data!.haySiguiente ? () => cambiarPagina(pagina + 1) : null,
                icon: const Icon(Icons.chevron_right)),
            ]),
          ]);
        },
        )),
      ]),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cerrar'),
      ),
    ],
  );
}
