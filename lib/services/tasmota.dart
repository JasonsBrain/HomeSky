// =============================================================================
//  tasmota.dart – talks to Tasmota devices (plugs, switches, bulbs).
//
//  Tasmota has a simple web API: http://<ip>/cm?cmnd=<command>
//  Command reference: https://tasmota.github.io/docs/Commands/
//
//  Commands used here:
//    Status 0          → everything: power, dimmer, colour, energy meter
//    Power On / Off    → switch
//    Dimmer <0-100>    → brightness (bulbs)
//    Color r,g,b       → colour (colour bulbs)
//
//  Password: if you set a web password in Tasmota, Homesky sends it with
//  every request (user=admin&password=...). That is how Tasmota's API works.
//  It only ever travels on your home network (see local_network.dart).
// =============================================================================

import '../models/device.dart';
import 'local_network.dart';

/// Tasmota asked for a password, or the saved one is wrong.
class TasmotaPasswordException implements Exception {
  @override
  String toString() => 'This Tasmota device needs its web password.';
}

/// What we learn about a Tasmota device when adding it.
class TasmotaInfo {
  TasmotaInfo({required this.kind, required this.name, required this.hasEnergy});
  final DeviceKind kind;
  final String name;
  final bool hasEnergy;
}

class TasmotaClient {
  TasmotaClient._();

  // ---------------------------------------------------------------------------
  //  Low level
  // ---------------------------------------------------------------------------

  /// Send one Tasmota command and return its JSON answer.
  static Future<Map<String, dynamic>> send(Device device, String command) =>
      _sendTo(device.ip, device.password, command);

  static Future<Map<String, dynamic>> _sendTo(String ip, String password, String command) async {
    final query = <String, String>{
      if (password.isNotEmpty) 'user': 'admin',
      if (password.isNotEmpty) 'password': password,
      'cmnd': command,
    };
    final answer = await LocalNetwork.getJson(ip, '/cm', query: query);
    if (answer is! Map<String, dynamic>) {
      throw DeviceUnreachableException('Unexpected answer from Tasmota.');
    }
    // Tasmota answers {"WARNING":"Need user=<username>&password=<password>"}
    // when a password is required.
    if (answer.containsKey('WARNING')) throw TasmotaPasswordException();
    return answer;
  }

  // ---------------------------------------------------------------------------
  //  Reading status
  // ---------------------------------------------------------------------------

  /// Refresh [state] with the device's current status.
  static Future<void> refresh(Device device, DeviceState state) async {
    final status = await send(device, 'Status 0');
    final sts = _map(status['StatusSTS']); // switch/light status
    final sns = _map(status['StatusSNS']); // sensors, incl. energy meter

    state.on = _isOn(sts);
    if (sts['Dimmer'] is num) state.brightness = (sts['Dimmer'] as num).toInt();
    final rgb = _parseColor(sts['Color']);
    if (rgb != null) state.rgb = rgb;

    final energy = sns['ENERGY'];
    if (energy is Map) {
      state.hasEnergy = true;
      state.watts = _number(energy['Power']);
      state.todayKwh = _number(energy['Today']);
      state.yesterdayKwh = _number(energy['Yesterday']);
    }
  }

  /// Ask a new device what it is. Used by "Test connection" and the scanner.
  static Future<TasmotaInfo> identify(String ip, {String password = ''}) async {
    final status = await _sendTo(ip, password, 'Status 0');
    final info = _map(status['Status']);
    final sts = _map(status['StatusSTS']);
    final sns = _map(status['StatusSNS']);

    // Name: DeviceName (newer Tasmota) or the first FriendlyName.
    var name = info['DeviceName'] as String? ?? '';
    final friendly = info['FriendlyName'];
    if (name.isEmpty && friendly is List && friendly.isNotEmpty) name = '${friendly.first}';
    if (name.isEmpty) name = 'Tasmota $ip';

    return TasmotaInfo(
      // Bulbs report a "Dimmer" value; plugs don't.
      kind: sts.containsKey('Dimmer') ? DeviceKind.light : DeviceKind.plug,
      name: name,
      hasEnergy: sns['ENERGY'] is Map,
    );
  }

  // ---------------------------------------------------------------------------
  //  Controlling
  // ---------------------------------------------------------------------------

  static Future<void> setPower(Device device, bool on) async {
    await send(device, on ? 'Power On' : 'Power Off');
  }

  /// [percent] 1–100.
  static Future<void> setBrightness(Device device, int percent) async {
    await send(device, 'Dimmer ${percent.clamp(1, 100)}');
  }

  /// Sets an RGB colour (this also switches the bulb on).
  /// For white on RGBW/RGBCCT bulbs you could use 'White <0-100>' or 'CT 153'
  /// instead; see https://tasmota.github.io/docs/Lights/
  static Future<void> setColor(Device device, List<int> rgb) async {
    await send(device, 'Color ${rgb[0]},${rgb[1]},${rgb[2]}');
  }

  // ---------------------------------------------------------------------------
  //  Helpers
  // ---------------------------------------------------------------------------

  static Map<String, dynamic> _map(dynamic value) =>
      value is Map<String, dynamic> ? value : <String, dynamic>{};

  /// Single-relay devices report "POWER", multi-relay ones "POWER1", "POWER2"...
  /// Homesky treats relay 1 as the device's main switch.
  static bool _isOn(Map<String, dynamic> sts) {
    final value = sts['POWER'] ?? sts['POWER1'];
    return value == 'ON' || value == 1 || value == true;
  }

  /// Energy values are numbers, or lists of numbers on multi-channel meters
  /// (then we add them up).
  static double? _number(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is List) {
      var sum = 0.0;
      for (final v in value) {
        if (v is num) sum += v;
      }
      return sum;
    }
    return null;
  }

  /// Tasmota reports colour as hex ("FF8800" or "FF8800FF") or as "255,136,0".
  static List<int>? _parseColor(dynamic value) {
    if (value is! String || value.isEmpty) return null;
    if (value.contains(',')) {
      final parts = value.split(',').map((p) => int.tryParse(p.trim()) ?? 0).toList();
      return parts.length >= 3 ? parts.sublist(0, 3) : null;
    }
    final hex = value.replaceAll('#', '');
    if (hex.length < 6) return null;
    final r = int.tryParse(hex.substring(0, 2), radix: 16);
    final g = int.tryParse(hex.substring(2, 4), radix: 16);
    final b = int.tryParse(hex.substring(4, 6), radix: 16);
    if (r == null || g == null || b == null) return null;
    return [r, g, b];
  }
}
