// ignore: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'visit_source.dart';

/// Lee el referrer del documento y la dirección actual (con
/// sus parámetros UTM) tal como los dejó el navegador al
/// entrar. Se captura una sola vez por carga de la app: es la
/// señal de la visita que está entrando.
VisitSource captureVisitSource() {
  try {
    return VisitSource(
      referrer: html.document.referrer,
      landing: html.window.location.href,
    );
  } catch (_) {
    return const VisitSource(referrer: '', landing: '');
  }
}
