import 'package:material_ui/material_ui.dart';

/// Fuera de web no hay efectos por ahora (la app pública es web).
void playSound(String name) {}

void buzz() {}

void setWakelock(bool on) {}

/// Sin navegador no hay reproductor incrustado: se muestra un
/// aviso simple (la tarjeta ya ofrece abrir el video fuera).
Widget youtubePlayer(String videoId) => const SizedBox.shrink();

/// Reproductor de «Cine juntos» fuera de web: sin efecto.
Widget cinePlayer(String key, String videoId) => const SizedBox.shrink();

/// Comando al reproductor de cine fuera de web: sin efecto.
void cineCommand(String key, String func, [double? arg]) {}

/// Capa de toques sobre el reproductor fuera de web: sin efecto.
Widget cineTapOverlay(String key) => const SizedBox.shrink();

/// Manejador de toques del reproductor fuera de web: sin efecto.
void setCineTapHandler(String key, void Function() handler) {}

/// Título de un video de YouTube fuera de web: sin efecto.
Future<String?> fetchYoutubeTitle(String videoId) async => null;
