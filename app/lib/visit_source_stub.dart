import 'visit_source.dart';

/// Fuera de la web no hay referrer: la conexión se clasifica
/// como llegada desde la app.
VisitSource captureVisitSource() =>
    const VisitSource(referrer: '', landing: '');
