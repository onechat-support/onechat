// La identidad de dispositivo es una capacidad solo-web:
// este archivo jamás se importa fuera del navegador (import
// condicional en device_identity.dart).
// ignore: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:math';

import 'device_identity.dart';

DeviceIdentity? _cached;

String _newId() {
  final rnd = Random.secure();
  String hex(int n) =>
      List.generate(n, (_) => rnd.nextInt(16).toRadixString(16)).join();
  return 'dev-${hex(8)}-${hex(4)}-${hex(4)}-${hex(12)}';
}

String? _cookie(String name) {
  for (final part in html.document.cookie?.split(';') ?? const []) {
    final kv = part.trim().split('=');
    if (kv.length == 2 && kv[0] == name) return Uri.decodeComponent(kv[1]);
  }
  return null;
}

void _setCookie(String name, String value) {
  final exp = DateTime.now().add(const Duration(days: 365));
  html.document.cookie =
      '$name=${Uri.encodeComponent(value)}; expires=${exp.toUtc().toString()}; path=/; SameSite=Lax';
}

/// FNV-1a de 32 bits → huella corta y estable.
String _fnv(String input) {
  var h = 0x811c9dc5;
  for (final c in input.codeUnits) {
    h ^= c;
    h = (h * 0x01000193) & 0xffffffff;
  }
  return 'fp${h.toRadixString(16).padLeft(8, '0')}';
}

String _canvasSignal() {
  try {
    final canvas = html.CanvasElement(width: 300, height: 60);
    final ctx = canvas.context2D;
    ctx.font = '16px Arial';
    ctx.fillStyle = '#00C2A8';
    ctx.fillText('ONEchat · huella · 12345', 8, 24);
    ctx.fillStyle = 'rgba(79,140,255,0.7)';
    ctx.fillRect(120, 30, 90, 14);
    return canvas.toDataUrl().hashCode.toRadixString(16);
  } catch (_) {
    return 'nocanvas';
  }
}

/// Identidad del dispositivo en web: el identificador se
/// guarda en localStorage Y en una cookie (borrar uno solo
/// no alcanza para «ser otro equipo»); la huella combina
/// señales del navegador y del hardware gráfico.
Future<DeviceIdentity> getDeviceIdentity() async {
  if (_cached != null) return _cached!;

  var id = html.window.localStorage['onechat_device_id'] ?? _cookie('oc_did');
  if (id == null || id.isEmpty) id = _newId();
  try {
    html.window.localStorage['onechat_device_id'] = id;
  } catch (_) {}
  _setCookie('oc_did', id);

  final nav = html.window.navigator;
  final screen = html.window.screen;
  final signals = [
    nav.userAgent,
    nav.language,
    '${screen?.width}x${screen?.height}x${screen?.colorDepth}',
    '${DateTime.now().timeZoneOffset.inMinutes}',
    '${nav.hardwareConcurrency ?? ''}',
    nav.platform ?? '',
    _canvasSignal(),
  ].join('|');

  _cached = DeviceIdentity(deviceId: id, fingerprint: _fnv(signals));
  return _cached!;
}
