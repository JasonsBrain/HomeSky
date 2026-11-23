// =============================================================================
//  local_network.dart – THE privacy gate.
//
//  Every network request in Homesky goes through this file. It enforces one
//  rule: the app may only talk to private home-network addresses
//  (10.x.x.x, 172.16–31.x.x, 192.168.x.x, 169.254.x.x).
//
//  Anything else – a public IP, a domain name, a redirect to the internet –
//  is refused before a single byte leaves the device. So even a bug elsewhere
//  in the app can't send your data to the internet.
//
//  Other privacy choices made here:
//    - No proxy is ever used (requests go straight to the device).
//    - Redirects are not followed (a device can't bounce us to the internet).
//    - No User-Agent header, so the app doesn't announce what it is.
//    - Short timeouts, so a dead device never freezes the app.
// =============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Thrown when code tries to reach an address outside the home network.
/// If you ever see this, something tried to leave your network and was stopped.
class NotLocalAddressException implements Exception {
  NotLocalAddressException(this.host);
  final String host;

  @override
  String toString() => 'Blocked: $host is not a private home-network address.';
}

/// Thrown when a device doesn't answer, answers with an error, or answers
/// with something that isn't JSON.
class DeviceUnreachableException implements Exception {
  DeviceUnreachableException(this.message);
  final String message;

  @override
  String toString() => message;
}

class LocalNetwork {
  LocalNetwork._(); // Static helpers only – no instances.

  /// How long to wait for a device before giving up.
  /// Raise this if a device on weak Wi-Fi keeps showing "not responding".
  static const Duration defaultTimeout = Duration(seconds: 3);

  // One shared HTTP client for the whole app.
  static final HttpClient _client = HttpClient()
    ..connectionTimeout = defaultTimeout
    // Never use a system proxy: requests go directly to the device.
    ..findProxy = ((uri) => 'DIRECT')
    // Send no User-Agent header.
    ..userAgent = null
    // Plain HTTP on the home network only; no credentials are cached.
    ..autoUncompress = true;

  // ---------------------------------------------------------------------------
  //  Address checks
  // ---------------------------------------------------------------------------

  /// True only for a plain IPv4 address in a private (home network) range.
  /// Domain names are rejected on purpose: a name could point anywhere.
  static bool isPrivateIPv4(String host) {
    final parts = host.trim().split('.');
    if (parts.length != 4) return false;

    final numbers = <int>[];
    for (final part in parts) {
      final n = int.tryParse(part);
      if (n == null || n < 0 || n > 255) return false;
      numbers.add(n);
    }

    final a = numbers[0];
    final b = numbers[1];
    if (a == 10) return true; //                    10.0.0.0/8
    if (a == 172 && b >= 16 && b <= 31) return true; // 172.16.0.0/12
    if (a == 192 && b == 168) return true; //         192.168.0.0/16
    if (a == 169 && b == 254) return true; //         169.254.0.0/16 (link-local)
    return false;
  }

  /// This device's own address on the home network, or null when there is
  /// none (e.g. Wi-Fi is off). Used for the "No Wi-Fi" banner and scanning.
  static Future<String?> ownAddress() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      // Prefer Wi-Fi / Ethernet style interface names, then anything private.
      String? fallback;
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!isPrivateIPv4(addr.address)) continue;
          final name = iface.name.toLowerCase();
          if (name.contains('wlan') || name.contains('wi-fi') || name.contains('wifi') || name.contains('eth') || name.contains('en')) {
            return addr.address;
          }
          fallback ??= addr.address;
        }
      }
      return fallback;
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  //  Requests
  // ---------------------------------------------------------------------------

  /// Builds an http:// address, refusing anything that isn't a private IP.
  static Uri _buildUri(String host, String path, Map<String, String>? query) {
    if (!isPrivateIPv4(host)) {
      throw NotLocalAddressException(host);
    }
    return Uri(scheme: 'http', host: host.trim(), path: path, queryParameters: query);
  }

  /// GET a device and decode its JSON answer.
  static Future<dynamic> getJson(
    String host,
    String path, {
    Map<String, String>? query,
    Duration timeout = defaultTimeout,
  }) async {
    final uri = _buildUri(host, path, query);
    return _send(() => _client.getUrl(uri), timeout: timeout);
  }

  /// POST JSON to a device and decode its JSON answer.
  static Future<dynamic> postJson(
    String host,
    String path,
    Object body, {
    Duration timeout = defaultTimeout,
  }) async {
    final uri = _buildUri(host, path, null);
    return _send(
      () => _client.postUrl(uri),
      body: jsonEncode(body),
      timeout: timeout,
    );
  }

  /// Quick check whether something answers on port 80 at [host].
  /// Used by the network scan so we only send real requests to live devices.
  static Future<bool> isPortOpen(String host, {Duration timeout = const Duration(milliseconds: 400)}) async {
    if (!isPrivateIPv4(host)) throw NotLocalAddressException(host);
    try {
      final socket = await Socket.connect(host, 80, timeout: timeout);
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  // Shared request logic for GET and POST.
  static Future<dynamic> _send(
    Future<HttpClientRequest> Function() open, {
    String? body,
    required Duration timeout,
  }) async {
    try {
      final request = await open().timeout(timeout);
      // Never follow a redirect: it could point outside the home network.
      request.followRedirects = false;
      // Use a fresh connection for every request. The small web servers in
      // WLED/Tasmota (ESP8266/ESP32 chips) handle "keep-alive" connections
      // badly: reusing one can hang until it times out, which shows up as
      // "not responding" even though the device is fine.
      request.persistentConnection = false;
      if (body != null) {
        request.headers.contentType = ContentType.json;
        request.write(body);
      }
      final response = await request.close().timeout(timeout);
      final text = await response.transform(utf8.decoder).join().timeout(timeout);

      if (response.statusCode != 200) {
        throw DeviceUnreachableException('Device answered with error ${response.statusCode}.');
      }
      return jsonDecode(text);
    } on NotLocalAddressException {
      rethrow;
    } on DeviceUnreachableException {
      rethrow;
    } on TimeoutException {
      throw DeviceUnreachableException('Device did not answer within ${timeout.inSeconds} s.');
    } on SocketException catch (e) {
      // Include the system's reason (e.g. "Connection refused") to help fix problems.
      throw DeviceUnreachableException('Could not reach the device (${e.osError?.message ?? e.message}).');
    } on HttpException catch (e) {
      throw DeviceUnreachableException('Connection to the device failed (${e.message}).');
    } on FormatException {
      throw DeviceUnreachableException('Device sent an answer Homesky does not understand.');
    }
  }
}
