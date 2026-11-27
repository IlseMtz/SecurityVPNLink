import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'azure_api.dart';

class SesionAzure extends ChangeNotifier {
  SesionAzure({AzureApi? api, http.Client? cliente}) {
    this.api =
        api ??
        AzureApi(
          cliente: cliente,
          obtenerToken: () => _token,
          alCaducar: _expirar,
        );
  }
  late final AzureApi api;
  String? _token;
  CuentaAzure? cuenta;
  String? avisoAcceso;
  Timer? _caducidad;
  bool _cerrada = false;
  Future<void> ingresar(String correo, String contrasena) async {
    final acceso = await api.login(correo, contrasena);
    if (_cerrada) return;
    _token = acceso.token;
    cuenta = acceso.cuenta;
    _caducidad?.cancel();
    avisoAcceso = null;
    _caducidad = Timer(acceso.expiraEn, _expirar);
    notifyListeners();
  }

  void _expirar() =>
      limpiar('Tu sesión venció o fue invalidada. Inicia sesión nuevamente.');

  void limpiar([String? aviso]) {
    avisoAcceso = aviso;
    _token = null;
    cuenta = null;
    _caducidad?.cancel();
    if (!_cerrada) notifyListeners();
  }

  Future<void> actualizarPermisos() async {
    final token = _token;
    if (token == null) return;
    final perfil = await api.miPerfil();
    if (_cerrada || _token != token) return;
    if (perfil.estado != 'ACTIVO') { _expirar(); return; }
    cuenta = perfil;
    notifyListeners();
  }

  Future<void> salir() async {
    final token = _token;
    try {
      await api.logout();
      if (_token == token) limpiar('Se cerraron las sesiones de tu cuenta.');
    } catch (_) {
      if (_token == token) {
        limpiar(
          'Se cerró la sesión en este equipo. No se pudo confirmar el cierre en otros equipos.',
        );
      }
    }
  }

  Future<void> editarPerfil(String nombre, String correo) async {
    final token = _token;
    await api.editarMiPerfil(nombre, correo);
    if (_token == token) {
      limpiar('Perfil actualizado. Inicia sesión con tu correo actualizado.');
    }
  }

  Future<void> cambiarContrasena(String actual, String nueva) async {
    final token = _token;
    await api.cambiarMiContrasena(actual, nueva);
    if (_token == token) {
      limpiar('Contraseña actualizada. Inicia sesión nuevamente.');
    }
  }

  @override
  void dispose() {
    _cerrada = true;
    _caducidad?.cancel();
    _token = null;
    api.cerrar();
    super.dispose();
  }
}
