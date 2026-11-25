import 'dart:typed_data';

/// Fuera de web no hay navegador: abrir enlaces no hace nada
/// y no se pueden elegir fotos (la app pública es web).
void openExternalUrl(String url) {}

Future<(Uint8List, String)?> pickImageBytes() async => null;
