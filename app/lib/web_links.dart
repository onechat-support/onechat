/// Utilidades solo-web: abrir enlaces externos (la página
/// personal del sitio oficial) y elegir una foto del equipo
/// para la Galería. En web vive en web_links_web.dart; en el
/// resto de plataformas, un respaldo sin efecto.
library;

export 'web_links_stub.dart'
    if (dart.library.html) 'web_links_web.dart';
