/// Origen de la visita (v1.29): la app declara desde dónde
/// llegó el visitante (el referrer del navegador y la
/// dirección de entrada con sus UTM) para que el servidor
/// clasifique la conexión en el Panel de control: Instagram,
/// buscadores, redes sociales, directo... En web vive en
/// visit_source_web.dart; en el resto, un respaldo vacío.
library;

export 'visit_source_stub.dart'
    if (dart.library.html) 'visit_source_web.dart';

class VisitSource {
  const VisitSource({required this.referrer, required this.landing});
  final String referrer;
  final String landing;
}
