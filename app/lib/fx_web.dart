// Efectos solo-web (import condicional en fx.dart).
// ignore: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:convert';
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

final Map<String, Widget> _ytPlayers = {};

/// Reproductor oficial de YouTube incrustado (iframe de
/// youtube-nocookie) con autoplay: solo aparece cuando la
/// persona toca una tarjeta, y ese toque es la orden de
/// reproducir; se pausa solo con los controles del propio
/// reproductor.
///
/// El widget se CACHEA por video. Antes se creaba un iframe
/// nuevo en cada reconstrucción de la pantalla y el video se
/// cortaba al mover la ventana flotante, al tocar fuera de
/// ella (el teclado reconstruye la vista) o al llegar un
/// mensaje (reportado por Mario, 2026-11-26). Devolviendo
/// siempre el mismo widget, Flutter no toca el iframe y la
/// reproducción sigue.
Widget youtubePlayer(String videoId) {
  return _ytPlayers.putIfAbsent(videoId, () {
    final viewType = 'onechat-yt-$videoId';
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int _) {
      final iframe = html.IFrameElement()
        ..src = 'https://www.youtube-nocookie.com/embed/$videoId'
            '?autoplay=1&playsinline=1&rel=0'
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..allow = 'autoplay; accelerometer; encrypted-media; '
            'gyroscope; picture-in-picture'
        ..allowFullscreen = true;
      return iframe;
    });
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: HtmlElementView(viewType: viewType),
    );
  });
}

final Map<String, html.IFrameElement> _cineFrames = {};
final Map<String, Widget> _cinePlayers = {};

/// Reproductor de «Cine juntos»: iframe oficial con la API
/// activada (enablejsapi) y sin controles propios, porque los
/// controles son los de la app y mandan sobre los dos lados a la
/// vez a través del estado compartido en el servidor. También
/// cacheado por sesión+video: el marcador de 1 segundo de la
/// pantalla reconstruye seguido y no debe reiniciar el video.
Widget cinePlayer(String key, String videoId) {
  return _cinePlayers.putIfAbsent('$key|$videoId', () {
    final viewType = 'onechat-cine-$key-$videoId';
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int _) {
      final iframe = html.IFrameElement()
        ..src =
            'https://www.youtube-nocookie.com/embed/$videoId?enablejsapi=1&controls=0&rel=0&playsinline=1&autoplay=1&mute=1'
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..allow = 'autoplay; encrypted-media; picture-in-picture'
        ..allowFullscreen = true;
      _cineFrames[key] = iframe;
      return iframe;
    });
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: HtmlElementView(viewType: viewType),
    );
  });
}

final Map<String, Widget> _cineOverlays = {};
final Map<String, void Function()> _cineTapHandlers = {};

/// Registra qué hacer cuando el usuario toca el reproductor de
/// cine. La capa de toques es un elemento web real sobre el
/// iframe: los widgets dibujados en el lienzo de Flutter NO
/// reciben los toques que caen sobre un iframe (el iframe se
/// los queda, y su botón «Ver en YouTube» saca al usuario del
/// chat; su botón rojo rompe la sincronía).
void setCineTapHandler(String key, void Function() handler) {
  _cineTapHandlers[key] = handler;
}

/// Capa transparente sobre el reproductor de cine que sí recibe
/// los toques del usuario y los pasa al manejador registrado.
Widget cineTapOverlay(String key) {
  return _cineOverlays.putIfAbsent(key, () {
    final viewType = 'onechat-cine-tap-$key';
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int _) {
      final div = html.DivElement()
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.cursor = 'pointer'
        ..style.backgroundColor = 'transparent';
      div.onClick.listen((_) {
        final h = _cineTapHandlers[key];
        if (h != null) h();
      });
      return div;
    });
    return HtmlElementView(viewType: viewType);
  });
}

/// Envía un comando al reproductor de cine (playVideo, pauseVideo
/// o seekTo con la posición en segundos) por postMessage, el
/// mecanismo oficial de la API de iframe de YouTube.
void cineCommand(String key, String func, [double? arg]) {
  final frame = _cineFrames[key];
  final win = frame?.contentWindow;
  if (frame == null || win == null) return;
  final String message;
  if (func == 'seekTo' && arg != null) {
    message = '{"event":"command","func":"seekTo","args":[$arg,true]}';
  } else {
    message = '{"event":"command","func":"$func","args":""}';
  }
  win.postMessage(message, '*');
}

/// Título de un video de YouTube vía su oEmbed oficial (sin
/// clave y con CORS abierto). Si algo falla devuelve null y la
/// interfaz muestra solo «YouTube» como texto del enlace.
Future<String?> fetchYoutubeTitle(String videoId) async {
  try {
    final url = 'https://www.youtube.com/oembed?url='
        'https://www.youtube.com/watch?v=$videoId&format=json';
    final body = await html.HttpRequest.getString(url);
    final data = jsonDecode(body);
    if (data is Map && data['title'] is String) {
      return data['title'] as String;
    }
  } catch (_) {}
  return null;
}
