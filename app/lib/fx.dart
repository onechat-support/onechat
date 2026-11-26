/// Efectos del chat (Lote C): sonidos, vibración, pantalla
/// encendida (wakelock) y el reproductor de YouTube incrustado.
/// En web vive en fx_web.dart; en el resto de plataformas, un
/// respaldo sin efecto (la app pública es web).
library;

export 'fx_stub.dart' if (dart.library.html) 'fx_web.dart';
