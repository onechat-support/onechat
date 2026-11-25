// Capacidades solo-web (ver web_links.dart): este archivo
// jamás se importa fuera del navegador.
// ignore: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:async';
// ignore: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

void openExternalUrl(String url) {
  html.window.open(url, '_blank');
}

/// Abre el selector de archivos del navegador y devuelve los
/// bytes de la imagen elegida junto a su nombre, o null si
/// el usuario cancela.
Future<(Uint8List, String)?> pickImageBytes() async {
  final input = html.FileUploadInputElement()
    ..accept = 'image/*'
    ..multiple = false;
  final completer = Completer<(Uint8List, String)?>();
  input.onChange.listen((_) async {
    final file = input.files?.firstOrNull;
    if (file == null) {
      if (!completer.isCompleted) completer.complete(null);
      return;
    }
    final reader = html.FileReader();
    reader.onLoadEnd.listen((_) {
      if (completer.isCompleted) return;
      final result = reader.result;
      if (result is ByteBuffer) {
        completer.complete((result.asUint8List(), file.name));
      } else if (result is Uint8List) {
        completer.complete((result, file.name));
      } else {
        completer.complete(null);
      }
    });
    reader.onError.listen((_) {
      if (!completer.isCompleted) completer.complete(null);
    });
    reader.readAsArrayBuffer(file);
  });
  input.click();
  // Si el usuario cancela, onChange no llega nunca: el
  // llamador no debe quedar colgado para siempre.
  return completer.future.timeout(
    const Duration(minutes: 3),
    onTimeout: () => null,
  );
}
