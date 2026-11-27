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
///
/// Pulido 2026-11-26 (una foto de Mario «no se veía» ni en la
/// web ni en el chat):
/// - El input se adjunta al DOM: en Safari/iOS un input
///   suelto puede no abrir el selector o no disparar el
///   evento de cambio, y la subida moría en silencio.
/// - La imagen se convierte SIEMPRE a JPEG en el propio
///   navegador (máx. 1600 px, calidad 0,85): las fotos del
///   iPhone llegan en HEIC, que Chrome y Android no saben
///   mostrar, y pesan varios MB. Si la conversión falla, se
///   devuelven los bytes originales.
Future<(Uint8List, String)?> pickImageBytes() async {
  final input = html.FileUploadInputElement()
    ..accept = 'image/*'
    ..multiple = false
    ..style.display = 'none';
  html.document.body?.append(input);
  final completer = Completer<(Uint8List, String)?>();

  void finish((Uint8List, String)? value) {
    input.remove();
    if (!completer.isCompleted) completer.complete(value);
  }

  input.onChange.listen((_) async {
    final file = input.files?.firstOrNull;
    if (file == null) {
      finish(null);
      return;
    }
    try {
      final jpeg = await _toJpeg(file);
      if (jpeg != null) {
        finish((jpeg, 'foto.jpg'));
        return;
      }
    } catch (_) {
      // Sin conversión: se sigue con los bytes originales.
    }
    final reader = html.FileReader();
    reader.onLoadEnd.listen((_) {
      final result = reader.result;
      if (result is ByteBuffer) {
        finish((result.asUint8List(), file.name));
      } else if (result is Uint8List) {
        finish((result, file.name));
      } else {
        finish(null);
      }
    });
    reader.onError.listen((_) => finish(null));
    reader.readAsArrayBuffer(file);
  });
  input.click();
  // Si el usuario cancela, onChange no llega nunca: el
  // llamador no debe quedar colgado para siempre.
  return completer.future.timeout(
    const Duration(minutes: 3),
    onTimeout: () {
      input.remove();
      return null;
    },
  );
}

/// Convierte la imagen a JPEG con canvas. Devuelve null si
/// el navegador no pudo decodificarla o dibujarla.
Future<Uint8List?> _toJpeg(html.File file) async {
  final url = html.Url.createObjectUrlFromBlob(file);
  try {
    final img = html.ImageElement(src: url);
    await img.onLoad.first.timeout(const Duration(seconds: 20));
    final w0 = img.naturalWidth;
    final h0 = img.naturalHeight;
    if (w0 == 0 || h0 == 0) return null;
    const maxSide = 1600;
    var w = w0, h = h0;
    if (w > maxSide || h > maxSide) {
      final scale = maxSide / (w > h ? w : h);
      w = (w * scale).round();
      h = (h * scale).round();
    }
    final canvas = html.CanvasElement(width: w, height: h);
    final ctx = canvas.context2D;
    ctx.fillStyle = '#ffffff';
    ctx.fillRect(0, 0, w, h);
    ctx.drawImageScaled(img, 0, 0, w, h);
    final dataUrl = canvas.toDataUrl('image/jpeg', 0.85);
    final comma = dataUrl.indexOf(',');
    if (comma < 0) return null;
    return Uri.parse(dataUrl).data?.contentAsBytes();
  } catch (_) {
    return null;
  } finally {
    html.Url.revokeObjectUrl(url);
  }
}
