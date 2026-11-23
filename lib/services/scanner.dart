// =============================================================================
//  scanner.dart – finds Tasmota and WLED devices on your home network.
//
//  How it works (no internet, no cloud lookups):
//    1. Find this device's own address, e.g. 192.168.1.50.
//    2. Try every address in the same range (192.168.1.1 – 192.168.1.254).
//    3. For each address that answers on port 80, ask "are you WLED?",
//       then "are you Tasmota?".
//
//  Only the same /24 range as this device is scanned. If your devices are on
//  a different range, add them by IP address instead.
// =============================================================================

import 'dart:async';

import '../models/device.dart';
import 'local_network.dart';
import 'tasmota.dart';

/// A device found by the scan.
class FoundDevice {
  FoundDevice({required this.ip, required this.type, required this.kind, required this.name, this.needsPassword = false});
  final String ip;
  final DeviceType type;
  final DeviceKind kind;
  final String name;

  /// Tasmota with a web password: add it, then type the password.
  final bool needsPassword;
}

class NetworkScanner {
  NetworkScanner._();

  /// How many addresses are checked at the same time.
  /// Higher = faster scan, but more load on older phones/routers.
  static const int parallel = 24;

  /// Scan the local /24 range. [onProgress] gets 0.0–1.0, [onFound] each device.
  /// Returns false when this device has no home-network address (no Wi-Fi).
  static Future<bool> scan({
    required void Function(double progress) onProgress,
    required void Function(FoundDevice device) onFound,
    bool Function()? isCancelled,
  }) async {
    final own = await LocalNetwork.ownAddress();
    if (own == null) return false;

    final prefix = own.substring(0, own.lastIndexOf('.') + 1); // e.g. "192.168.1."
    final addresses = [for (var i = 1; i <= 254; i++) '$prefix$i']..remove(own);

    var done = 0;
    var next = 0;

    // A small pool of workers, each taking the next address until none are left.
    Future<void> worker() async {
      while (next < addresses.length) {
        if (isCancelled?.call() ?? false) return;
        final ip = addresses[next++];
        final found = await _probe(ip);
        if (found != null) onFound(found);
        done++;
        onProgress(done / addresses.length);
      }
    }

    await Future.wait([for (var i = 0; i < parallel; i++) worker()]);
    return true;
  }

  /// Checks one address. Returns null if it's not a supported device.
  static Future<FoundDevice?> _probe(String ip) async {
    if (!await LocalNetwork.isPortOpen(ip)) return null;

    const quick = Duration(milliseconds: 1500);

    // WLED?
    try {
      final answer = await LocalNetwork.getJson(ip, '/json/info', timeout: quick);
      if (answer is Map && answer.containsKey('ver') && answer.containsKey('leds')) {
        return FoundDevice(ip: ip, type: DeviceType.wled, kind: DeviceKind.strip, name: '${answer['name'] ?? 'WLED'}');
      }
    } catch (_) {/* not WLED */}

    // Tasmota?
    try {
      final info = await TasmotaClient.identify(ip);
      return FoundDevice(ip: ip, type: DeviceType.tasmota, kind: info.kind, name: info.name);
    } on TasmotaPasswordException {
      return FoundDevice(ip: ip, type: DeviceType.tasmota, kind: DeviceKind.plug, name: 'Tasmota $ip', needsPassword: true);
    } catch (_) {/* not Tasmota */}

    return null;
  }
}
