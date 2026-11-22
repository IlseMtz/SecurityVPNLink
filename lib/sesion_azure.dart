import 'dart:async';

import 'package:flutter/foundation.dart';

import 'azure_api.dart';

class SesionAzure extends ChangeNotifier {
  SesionAzure({AzureApi? api}) {
    this.api = api ?? AzureApi(obtenerToken: () => _token, alCaducar: limpiar);
  }
  late final AzureApi api;
  String? _token;
  CuentaAzure? cuenta;
  Timer? _caducidad;
  bool _cerrada = false;
  Future<void> ingresar(String correo, String contrasena) async {
    final acceso = await api.login(correo, contrasena);
    if (_cerrada) return;
    _token = acceso.token;
    cuenta = acceso.cuenta;
    _caducidad?.cancel();
    _caducidad = Timer(acceso.expiraEn, limpiar);
    notifyListeners();
  }

  void limpiar() {
    _token = null;
    cuenta = null;
    _caducidad?.cancel();
    if (!_cerrada) notifyListeners();
  }

  Future<void> salir() async {
    try {
      await api.logout();
    } finally {
      limpiar();
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
