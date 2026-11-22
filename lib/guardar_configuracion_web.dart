import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

Future<bool> guardarConfiguracion(Uint8List bytes, String nombre) async {
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: 'text/plain'),
  );
  final url = web.URL.createObjectURL(blob);
  final enlace = web.HTMLAnchorElement()
    ..href = url
    ..download = nombre;
  web.document.body!.append(enlace);
  enlace.click();
  enlace.remove();
  // Se libera únicamente la URL temporal, nunca se escribe en localStorage.
  Future<void>.delayed(
    const Duration(seconds: 2),
    () => web.URL.revokeObjectURL(url),
  );
  return true;
}
