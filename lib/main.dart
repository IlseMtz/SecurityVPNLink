import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'usuarios_page.dart';
import 'roles_grupos_page.dart';
import 'tema_securelink.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'SecureLink VPN Manager',
    debugShowCheckedModeBanner: false,
    theme: crearTemaSecureLink(),
    home: const LoginPage(),
  );
}

// SOLO simulación local: no usar este servicio como autenticación real.
// No persiste datos ni envía correo. No habilitado en release.
class SesionDemo {
  static const correo = 'admin@example.test';
  static String _password = 'Demo1234!';
  static bool autenticada = false;
  static String? _codigo;
  static DateTime? _vence;
  static int _intentosCodigo = 0;

  static bool ingresar(String email, String password) {
    autenticada = kDebugMode &&
        email.trim().toLowerCase() == correo && password == _password;
    return autenticada;
  }

  static void salir() => autenticada = false;

  static String? solicitarCodigo(String email) {
    if (!kDebugMode || email.trim().toLowerCase() != correo) return null;
    _codigo = (Random.secure().nextInt(900000) + 100000).toString();
    _vence = DateTime.now().add(const Duration(minutes: 10));
    _intentosCodigo = 0;
    return _codigo;
  }

  static String? cambiar(String actual, String nueva) {
    if (!kDebugMode || !autenticada) return 'Inicia sesión nuevamente.';
    if (actual != _password) return 'La contraseña actual no es correcta.';
    return _guardar(nueva);
  }

  static String? restablecer(String email, String codigo, String nueva) {
    if (!kDebugMode) return 'La recuperación real requiere conectar el backend.';
    if (_codigo == null || _vence == null ||
        !DateTime.now().isBefore(_vence!) || _intentosCodigo >= 5) {
      return 'Código inválido o vencido. Solicita uno nuevo.';
    }
    if (email.trim().toLowerCase() != correo || codigo.trim() != _codigo) {
      _intentosCodigo++;
      return 'Código inválido o vencido. Revisa tus datos.';
    }
    return _guardar(nueva);
  }

  static String? _guardar(String nueva) {
    final error = validarNuevaPassword(nueva);
    if (error != null) return error;
    if (nueva == _password) return 'Elige una contraseña diferente a la anterior.';
    _password = nueva;
    _codigo = null;
    _vence = null;
    _intentosCodigo = 0;
    autenticada = false;
    return null;
  }
}

String? validarCorreo(String? valor) {
  final texto = valor?.trim() ?? '';
  if (texto.isEmpty) return 'Escribe tu correo.';
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(texto)) {
    return 'Escribe un correo válido.';
  }
  return null;
}

// Política provisional de la maqueta; acordar la definitiva con backend.
String? validarNuevaPassword(String? valor) {
  if (valor == null || valor.trim().isEmpty) return 'Escribe una contraseña.';
  if (valor.length < 8) return 'Usa al menos 8 caracteres.';
  if (valor.length > 128) return 'Usa como máximo 128 caracteres.';
  return null;
}

class CampoPassword extends StatefulWidget {
  const CampoPassword({super.key, required this.controller,
    required this.etiqueta, this.validator, this.onSubmitted});
  final TextEditingController controller;
  final String etiqueta;
  final String? Function(String?)? validator;
  final void Function(String)? onSubmitted;
  @override
  State<CampoPassword> createState() => _CampoPasswordState();
}

class _CampoPasswordState extends State<CampoPassword> {
  bool ocultar = true;
  @override
  Widget build(BuildContext context) => TextFormField(
    controller: widget.controller,
    obscureText: ocultar,
    autocorrect: false,
    enableSuggestions: false,
    validator: widget.validator,
    onFieldSubmitted: widget.onSubmitted,
    decoration: InputDecoration(
      labelText: widget.etiqueta,
      prefixIcon: const Icon(Icons.lock_outline),
      suffixIcon: IconButton(
        tooltip: ocultar ? 'Mostrar contraseña' : 'Ocultar contraseña',
        onPressed: () => setState(() => ocultar = !ocultar),
        icon: Icon(ocultar ? Icons.visibility_outlined : Icons.visibility_off_outlined),
      ),
    ),
  );
}

class TarjetaAcceso extends StatelessWidget {
  const TarjetaAcceso({super.key, required this.titulo,
    required this.descripcion, required this.child});
  final String titulo;
  final String descripcion;
  final Widget child;
  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Card(
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 3,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                color: ColoresSecureLink.marino,
                padding: const EdgeInsets.all(24),
                child: const Column(children: [
                  Icon(Icons.shield_outlined, color: Color(0xFF74D5FF), size: 42),
                  SizedBox(height: 10),
                  Text('SecureLink', style: TextStyle(color: Colors.white,
                    fontSize: 25, fontWeight: FontWeight.bold)),
                  Text('VPN Manager', style: TextStyle(color: Colors.white70)),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(titulo, style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 8),
                    Text(descripcion),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: const Color(0xFFEAF1FF),
                        borderRadius: BorderRadius.circular(12)),
                      
                      //child: Text(kDebugMode
                       // ? 'Demostración local. No se envían correos. Los cambios se pierden al reiniciar la aplicación.'
                       // : 'Autenticación pendiente de integración con el servidor.'),
                    ),
                    const SizedBox(height: 20),
                    child,
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.aviso});
  final String? aviso;
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final formulario = GlobalKey<FormState>();
  final correo = TextEditingController();
  final password = TextEditingController();
  String? error;
  @override
  void dispose() {
    correo.dispose(); password.dispose(); super.dispose();
  }
  void ingresar() {
    if (!formulario.currentState!.validate()) return;
    if (SesionDemo.ingresar(correo.text, password.text)) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const ResumenPage()));
    } else {
      setState(() => error = kDebugMode
        ? 'Correo o contraseña incorrectos.'
        : 'Debes conectar el backend para iniciar sesión en esta versión.');
    }
  }
  Future<void> recuperar() async {
    password.clear();
    await Navigator.of(context).push<void>(MaterialPageRoute(
      builder: (_) => RecuperarPasswordPage(correoInicial: correo.text.trim())));
    if (mounted) setState(() => error = null);
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(child: TarjetaAcceso(
      titulo: 'Iniciar sesión',
      descripcion: 'Accede al panel de administración.',
      child: Form(key: formulario, child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.aviso != null) ...[
            Text(widget.aviso!, style: const TextStyle(color: Color(0xFF166534))),
            const SizedBox(height: 16),
          ],
          TextFormField(controller: correo,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            validator: validarCorreo,
            decoration: const InputDecoration(labelText: 'Correo electrónico',
              prefixIcon: Icon(Icons.mail_outline))),
          const SizedBox(height: 16),
          CampoPassword(controller: password, etiqueta: 'Contraseña',
            validator: (v) => v == null || v.isEmpty ? 'Escribe tu contraseña.' : null,
            onSubmitted: (_) => ingresar()),
          Align(alignment: Alignment.centerRight,
            child: TextButton(onPressed: recuperar,
              child: const Text('¿Olvidaste tu contraseña?'))),
          if (error != null) ...[
            Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            const SizedBox(height: 12),
          ],
          FilledButton(onPressed: ingresar, child: const Text('Iniciar sesión')),
          const SizedBox(height: 12),
          const Text('Acceso restringido a usuarios registrados.', textAlign: TextAlign.center),
        ],
      )),
    )),
  );
}

class RecuperarPasswordPage extends StatefulWidget {
  const RecuperarPasswordPage({super.key, this.correoInicial = ''});
  final String correoInicial;
  @override
  State<RecuperarPasswordPage> createState() => _RecuperarPasswordPageState();
}

class _RecuperarPasswordPageState extends State<RecuperarPasswordPage> {
  final formulario = GlobalKey<FormState>();
  late final TextEditingController correo = TextEditingController(text: widget.correoInicial);
  bool solicitado = false;
  String correoSolicitado = '';
  String? codigoDemo;
  @override
  void dispose() { correo.dispose(); super.dispose(); }
  void solicitar() {
    if (!formulario.currentState!.validate()) return;
    setState(() {
      correoSolicitado = correo.text.trim().toLowerCase();
      codigoDemo = SesionDemo.solicitarCodigo(correoSolicitado);
      solicitado = true;
    });
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Recuperar contraseña')),
    body: SafeArea(child: TarjetaAcceso(
      titulo: 'Recupera tu acceso',
      descripcion: 'Escribe el correo asociado a tu cuenta.',
      child: Form(key: formulario, child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(controller: correo, validator: validarCorreo,
            keyboardType: TextInputType.emailAddress,
            onChanged: (_) => setState(() { solicitado = false; codigoDemo = null; }),
            decoration: const InputDecoration(labelText: 'Correo electrónico',
              prefixIcon: Icon(Icons.mail_outline))),
          const SizedBox(height: 16),
          FilledButton(onPressed: kDebugMode ? solicitar : null,
            child: Text(solicitado ? 'Generar otro código de prueba' : 'Simular solicitud')),
          if (solicitado) ...[
            const SizedBox(height: 16),
            const Text('Solicitud simulada. Con el servicio real, si la cuenta es válida, recibirás instrucciones en tu correo. Aquí no se ha enviado ningún mensaje.'),
            if (codigoDemo != null) ...[
              const SizedBox(height: 12),
              SelectableText('SOLO DEMO · Código: $codigoDemo\nVigencia: 10 minutos. Un solo uso.',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
            const SizedBox(height: 12),
            OutlinedButton(onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute(builder: (_) => RestablecerPasswordPage(correo: correoSolicitado))),
              child: const Text('Ingresar código y nueva contraseña')),
          ],
          TextButton(onPressed: () => Navigator.of(context).pop(),
            child: const Text('Volver al inicio de sesión')),
        ],
      )),
    )),
  );
}

class RestablecerPasswordPage extends StatelessWidget {
  const RestablecerPasswordPage({super.key, required this.correo});
  final String correo;
  @override
  Widget build(BuildContext context) => FormularioPasswordPage(correo: correo);
}

class CambiarPasswordPage extends StatelessWidget {
  const CambiarPasswordPage({super.key});
  @override
  Widget build(BuildContext context) => const FormularioPasswordPage();
}

// Comparte validaciones y presentación entre cambio y restablecimiento.
class FormularioPasswordPage extends StatefulWidget {
  const FormularioPasswordPage({super.key, this.correo});
  final String? correo;
  @override
  State<FormularioPasswordPage> createState() => _FormularioPasswordPageState();
}

class _FormularioPasswordPageState extends State<FormularioPasswordPage> {
  final formulario = GlobalKey<FormState>();
  final actual = TextEditingController();
  final codigo = TextEditingController();
  final nueva = TextEditingController();
  final confirmar = TextEditingController();
  String? error;
  bool get recuperacion => widget.correo != null;
  @override
  void dispose() {
    actual.dispose(); codigo.dispose(); nueva.dispose(); confirmar.dispose();
    super.dispose();
  }
  void guardar() {
    if (!formulario.currentState!.validate()) return;
    final resultado = recuperacion
      ? SesionDemo.restablecer(widget.correo!, codigo.text, nueva.text)
      : SesionDemo.cambiar(actual.text, nueva.text);
    if (resultado != null) { setState(() => error = resultado); return; }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginPage(
        aviso: 'Contraseña actualizada en la demostración. Inicia sesión con la nueva contraseña.')),
      (route) => false,
    );
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(recuperacion ? 'Restablecer contraseña' : 'Cambiar contraseña')),
    body: SafeArea(child: TarjetaAcceso(
      titulo: recuperacion ? 'Establece una contraseña nueva' : 'Protege tu cuenta',
      descripcion: recuperacion ? 'Cuenta: ${widget.correo}' : 'Cuenta: ${SesionDemo.correo}',
      child: Form(key: formulario, child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (recuperacion)
            TextFormField(controller: codigo,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Código de recuperación',
                prefixIcon: Icon(Icons.key_outlined)),
              validator: (v) => RegExp(r'^\d{6}$').hasMatch(v?.trim() ?? '')
                ? null : 'Escribe el código de 6 dígitos.')
          else
            CampoPassword(controller: actual, etiqueta: 'Contraseña actual',
              validator: (v) => v == null || v.isEmpty ? 'Escribe tu contraseña actual.' : null),
          const SizedBox(height: 16),
          CampoPassword(controller: nueva, etiqueta: 'Nueva contraseña', validator: validarNuevaPassword),
          const SizedBox(height: 8),
          const Text('De 8 a 128 caracteres. Usa una contraseña distinta a la anterior.'),
          const SizedBox(height: 16),
          CampoPassword(controller: confirmar, etiqueta: 'Confirmar nueva contraseña',
            validator: (v) => v == null || v.isEmpty ? 'Confirma la contraseña.'
              : v != nueva.text ? 'Las contraseñas no coinciden.' : null,
            onSubmitted: (_) => guardar()),
          if (error != null) ...[
            const SizedBox(height: 12),
            Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 20),
          FilledButton(onPressed: kDebugMode ? guardar : null,
            child: const Text('Guardar contraseña de demostración')),
          const SizedBox(height: 8),
          const Text('Al guardar, deberás iniciar sesión nuevamente.'),
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        ],
      )),
    )),
  );
}

class ResumenPage extends StatefulWidget {
  const ResumenPage({super.key});

  @override
  State<ResumenPage> createState() => _ResumenPageState();
}

class _ResumenPageState extends State<ResumenPage> {
  bool mostrarUsuarios = false;

  final List<UsuarioDemo> usuarios = List.of(usuariosDemo);

  late final List<String> grupos =
      usuarios.expand((usuario) => usuario.grupos).toSet().toList();

  void cerrarSesion() {
    SesionDemo.salir();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  void elegirSeccion(bool usuarios, bool cerrarMenu) {
    if (cerrarMenu) Navigator.of(context).pop();
    setState(() => mostrarUsuarios = usuarios);
  }

  Future<void> abrirRoles(bool cerrarMenu) async {
    final navegador = Navigator.of(context);
    if (cerrarMenu) navegador.pop();

    await navegador.push<void>(
      MaterialPageRoute(
        builder: (_) => RolesGruposPage(
          usuarios: usuarios,
          grupos: grupos,
        ),
      ),
    );

    if (mounted) setState(() {});
  }

  Future<void> abrirPassword(bool cerrarMenu) async {
    final navegador = Navigator.of(context);
    if (cerrarMenu) navegador.pop();
    await navegador.push<void>(MaterialPageRoute(
      builder: (_) => const CambiarPasswordPage()));
  }

  Widget construirMenu({required bool cerrarMenu}) {
    return Container(
      color: Colors.white,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20, horizontal: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.shield_outlined,
                    color: ColoresSecureLink.azul,
                    size: 30,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'SecureLink',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: ColoresSecureLink.marino,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            const SizedBox(height: 12),
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              selected: !mostrarUsuarios,
              selectedTileColor: const Color(0xFFEAF1FF),
              selectedColor: ColoresSecureLink.azul,
              leading: const Icon(Icons.dashboard_outlined),
              title: const Text('Resumen'),
              onTap: () => elegirSeccion(false, cerrarMenu),
            ),
            const SizedBox(height: 6),
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              selected: mostrarUsuarios,
              selectedTileColor: const Color(0xFFEAF1FF),
              selectedColor: ColoresSecureLink.azul,
              leading: const Icon(Icons.people_outline),
              title: const Text('Usuarios'),
              onTap: () => elegirSeccion(true, cerrarMenu),
            ),
            const SizedBox(height: 6),
            ListTile(
              leading: const Icon(Icons.groups_outlined),
              title: const Text('Roles y grupos'),
              onTap: () => abrirRoles(cerrarMenu),
            ),
            const SizedBox(height: 6),
            ListTile(
              leading: const Icon(Icons.password_outlined),
              title: const Text('Cambiar contraseña'),
              onTap: () => abrirPassword(cerrarMenu),
            ),
            const Divider(height: 32),
            const ListTile(
              leading: CircleAvatar(
                backgroundColor: Color(0xFFEAF1FF),
                child: Icon(
                  Icons.person_outline,
                  color: ColoresSecureLink.azul,
                ),
              ),
              title: Text('Administrador'),
              subtitle: Text('Sesión de demostración'),
            ),
          ],
        ),
      ),
    );
  }

  Widget construirResumen() {
    final activos = usuarios.where((u) => u.estado == 'ACTIVO').length;
    final suspendidos =
        usuarios.where((u) => u.estado == 'SUSPENDIDO').length;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          'Resumen general',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: ColoresSecureLink.marino,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Modo demostración · Datos de esta sesión',
          style: TextStyle(color: ColoresSecureLink.secundario),
        ),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, espacio) {
            final columnas = espacio.maxWidth >= 950
                ? 4
                : espacio.maxWidth >= 500
                    ? 2
                    : 1;

            final ancho =
                (espacio.maxWidth - (columnas - 1) * 16) / columnas;

            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                TarjetaResumen(
                  ancho: ancho,
                  titulo: 'Usuarios registrados',
                  valor: '${usuarios.length}',
                  icono: Icons.people_outline,
                  color: ColoresSecureLink.azul,
                ),
                TarjetaResumen(
                  ancho: ancho,
                  titulo: 'Usuarios activos',
                  valor: '$activos',
                  icono: Icons.verified_user_outlined,
                  color: const Color(0xFF15803D),
                ),
                TarjetaResumen(
                  ancho: ancho,
                  titulo: 'Usuarios suspendidos',
                  valor: '$suspendidos',
                  icono: Icons.pause_circle_outline,
                  color: const Color(0xFFB45309),
                ),
                TarjetaResumen(
                  ancho: ancho,
                  titulo: 'Grupos registrados',
                  valor: '${grupos.length}',
                  icono: Icons.groups_outlined,
                  color: const Color(0xFF7C3AED),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 28),
        const Text(
          'Administración',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Card(
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: ColoresSecureLink.borde),
          ),
          child: Column(
            children: [
              ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: const Icon(
                  Icons.manage_accounts_outlined,
                  color: ColoresSecureLink.azul,
                ),
                title: const Text('Gestionar usuarios'),
                subtitle: const Text('Consultar cuentas y cambiar su estado'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => setState(() => mostrarUsuarios = true),
              ),
              const Divider(height: 1),
              ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: const Icon(
                  Icons.groups_outlined,
                  color: Color(0xFF7C3AED),
                ),
                title: const Text('Roles y grupos'),
                subtitle: const Text('Administrar departamentos y asignaciones'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => abrirRoles(false),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final escritorio = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      appBar: AppBar(
        title: const Text('SecureLink VPN Manager'),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: cerrarSesion,
          ),
          const SizedBox(width: 12),
        ],
      ),
      drawer: escritorio
          ? null
          : Drawer(child: construirMenu(cerrarMenu: true)),
      body: Row(
        children: [
          if (escritorio) ...[
            SizedBox(
              width: 250,
              child: construirMenu(cerrarMenu: false),
            ),
            const VerticalDivider(width: 1),
          ],
          Expanded(
            child: mostrarUsuarios
                ? UsuariosPage(usuarios: usuarios)
                : construirResumen(),
          ),
        ],
      ),
    );
  }
}

class TarjetaResumen extends StatelessWidget {
  const TarjetaResumen({
    super.key,
    required this.ancho,
    required this.titulo,
    required this.valor,
    required this.icono,
    required this.color,
  });

  final double ancho;
  final String titulo;
  final String valor;
  final IconData icono;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: ancho,
      child: Card(
        margin: EdgeInsets.zero,
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: ColoresSecureLink.borde),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: color.withAlpha(24),
                child: Icon(icono, color: color),
              ),
              const SizedBox(height: 18),
              Text(
                valor,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: ColoresSecureLink.marino,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                titulo,
                style: const TextStyle(color: ColoresSecureLink.secundario),
              ),
            ],
          ),
        ),
      ),
    );
  }
}