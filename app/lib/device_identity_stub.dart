import 'dart:math';

import 'device_identity.dart';

DeviceIdentity? _cached;

/// Respaldo fuera de web: identidad por sesión de proceso.
/// (La app pública es web; esto mantiene compilables las
/// demás plataformas.)
Future<DeviceIdentity> getDeviceIdentity() async {
  if (_cached != null) return _cached!;
  final rnd = Random.secure();
  String hex(int n) =>
      List.generate(n, (_) => rnd.nextInt(16).toRadixString(16)).join();
  _cached = DeviceIdentity(
    deviceId: 'dev-${hex(8)}-${hex(4)}-${hex(4)}-${hex(12)}',
    fingerprint: 'fp-stub',
  );
  return _cached!;
}
