/// Identidad del dispositivo (Fase S1 antitóxicos).
/// El Destierro bloquea cuenta + dispositivo + IP: para el
/// dispositivo se usan un identificador persistente (se
/// guarda en varios almacenes del navegador a la vez) y
/// una huella calculada con señales técnicas del equipo.
/// En web vive en device_identity_web.dart; en el resto de
/// plataformas, un respaldo simple en memoria.
library;

export 'device_identity_stub.dart'
    if (dart.library.html) 'device_identity_web.dart';

class DeviceIdentity {
  const DeviceIdentity({required this.deviceId, required this.fingerprint});
  final String deviceId;
  final String fingerprint;
}
