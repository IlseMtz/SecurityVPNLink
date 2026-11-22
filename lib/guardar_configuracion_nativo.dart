import 'dart:typed_data';

import 'package:flutter/services.dart';

Future<bool> guardarConfiguracion(Uint8List bytes, String nombre) async {
  return await const MethodChannel(
        'securelink/exportacion',
      ).invokeMethod<bool>('guardarConf', {'bytes': bytes, 'nombre': nombre}) ??
      false;
}
