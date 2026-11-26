import 'package:material_ui/material_ui.dart';

/// Fuera de web no hay efectos por ahora (la app pública es web).
void playSound(String name) {}

void buzz() {}

void setWakelock(bool on) {}

/// Sin navegador no hay reproductor incrustado: se muestra un
/// aviso simple (la tarjeta ya ofrece abrir el video fuera).
Widget youtubePlayer(String videoId) => const SizedBox.shrink();
