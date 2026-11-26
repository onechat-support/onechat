// Efectos solo-web (import condicional en fx.dart).
// ignore: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:ui_web' as ui_web;

import 'package:flutter/services.dart' as fservices;
import 'package:material_ui/material_ui.dart';

/// Reproduce uno de los sonidos cortos del chat:
/// assets/sounds/NAME.wav, publicados junto a la app.
void playSound(String name) {
  try {
    final a = html.AudioElement('assets/assets/sounds/$name.wav');
    a.volume = 0.45;
    a.play();
  } catch (_) {}
}

/// Vibración corta al ser mencionado (donde el navegador la
/// permite; en iOS web es limitada, límite conocido).
void buzz() {
  try {
    fservices.HapticFeedback.mediumImpact();
  } catch (_) {}
}

JSObject? _wakeSentinel;

/// Pantalla encendida mientras el chat está abierto (WakeLock
/// API del navegador; si no está disponible, no hace nada).
void setWakelock(bool on) {
  if (on) {
    _requestWakeLock();
    return;
  }
  final sentinel = _wakeSentinel;
  _wakeSentinel = null;
  if (sentinel != null) {
    try {
      sentinel.callMethod<JSAny?>('release'.toJS);
    } catch (_) {}
  }
}

Future<void> _requestWakeLock() async {
  try {
    final nav = globalContext.getProperty<JSObject>('navigator'.toJS);
    final wakeLock = nav.getProperty<JSObject?>('wakeLock'.toJS);
    if (wakeLock == null) return;
    final promise = wakeLock.callMethod<JSPromise<JSObject>>(
        'request'.toJS, 'screen'.toJS);
    _wakeSentinel = await promise.toDart;
  } catch (_) {}
}

int _ytCounter = 0;

/// Reproductor oficial de YouTube incrustado (iframe de
/// youtube-nocookie). No reproduce solo: arranca cuando la
/// persona toca la tarjeta y el propio reproductor.
Widget youtubePlayer(String videoId) {
  final viewType = 'onechat-yt-$videoId-${_ytCounter++}';
  ui_web.platformViewRegistry.registerViewFactory(viewType, (int _) {
    final iframe = html.IFrameElement()
      ..src = 'https://www.youtube-nocookie.com/embed/$videoId?rel=0'
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%'
      ..allow =
          'accelerometer; encrypted-media; gyroscope; picture-in-picture'
      ..allowFullscreen = true;
    return iframe;
  });
  return AspectRatio(
    aspectRatio: 16 / 9,
    child: HtmlElementView(viewType: viewType),
  );
}
