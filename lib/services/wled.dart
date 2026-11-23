// =============================================================================
//  wled.dart – talks to WLED LED controllers.
//
//  WLED has a JSON API: https://kno.wled.ge/interfaces/json-api/
//
//  Endpoints used here:
//    GET  /json/state    → current state (works on all WLED versions)
//    GET  /json/info     → device name and LED count (used when adding)
//    POST /json/state    → change state (power, brightness, colour, effect...)
//    GET  /json/eff      → list of effect names (index = effect id)
//    GET  /json/pal      → list of palette names (index = palette id)
//    GET  /presets.json  → saved presets
//
//  Homesky controls segment 0 (the whole strip unless you've split it into
//  segments in WLED). Multi-segment control is a planned extra.
// =============================================================================

import '../models/device.dart';
import 'local_network.dart';

/// One saved WLED preset.
class WledPreset {
  WledPreset(this.id, this.name);
  final int id;
  final String name;
}

/// What we learn about a WLED device when adding it.
class WledInfo {
  WledInfo({required this.name, required this.ledCount});
  final String name;
  final int ledCount;
}

class WledClient {
  WledClient._();

  // WLED brightness is 0–255; Homesky shows 0–100 %.
  static int _toPercent(num bri) => (bri / 255 * 100).round().clamp(0, 100);
  static int _toWled(int percent) => (percent.clamp(1, 100) / 100 * 255).round();

  // ---------------------------------------------------------------------------
  //  Reading
  // ---------------------------------------------------------------------------

  /// Refresh [state] with the strip's current status.
  static Future<void> refresh(Device device, DeviceState state) async {
    // /json/state is supported by every WLED version (the newer /json/si
    // endpoint isn't available on older firmware).
    final s = await LocalNetwork.getJson(device.ip, '/json/state');
    if (s is! Map<String, dynamic> || !s.containsKey('on')) {
      throw DeviceUnreachableException('This address did not answer like a WLED device.');
    }

    state.on = s['on'] == true;
    if (s['bri'] is num) state.brightness = _toPercent(s['bri'] as num);

    final segments = s['seg'];
    if (segments is List && segments.isNotEmpty && segments.first is Map) {
      final seg = segments.first as Map;
      final colours = seg['col'];
      if (colours is List && colours.isNotEmpty && colours.first is List) {
        final c = (colours.first as List).whereType<num>().map((n) => n.toInt()).toList();
        if (c.length >= 3) state.rgb = c.sublist(0, 3);
      }
      if (seg['fx'] is num) state.effect = (seg['fx'] as num).toInt();
      if (seg['sx'] is num) state.speed = (seg['sx'] as num).toInt();
      if (seg['ix'] is num) state.intensity = (seg['ix'] as num).toInt();
      if (seg['pal'] is num) state.palette = (seg['pal'] as num).toInt();
    }
  }

  /// Ask a new device what it is. Used by "Test connection" and the scanner.
  static Future<WledInfo> identify(String ip) async {
    final info = await LocalNetwork.getJson(ip, '/json/info');
    if (info is! Map<String, dynamic> || !info.containsKey('ver')) {
      throw DeviceUnreachableException('This does not look like a WLED device.');
    }
    final leds = info['leds'];
    return WledInfo(
      name: info['name'] as String? ?? 'WLED',
      ledCount: leds is Map && leds['count'] is num ? (leds['count'] as num).toInt() : 0,
    );
  }

  static Future<List<String>> effects(Device device) => _names(device, '/json/eff');
  static Future<List<String>> palettes(Device device) => _names(device, '/json/pal');

  static Future<List<String>> _names(Device device, String path) async {
    final answer = await LocalNetwork.getJson(device.ip, path);
    return answer is List ? answer.map((e) => '$e').toList() : <String>[];
  }

  /// Saved presets, sorted by id. Preset 0 is WLED's internal placeholder.
  static Future<List<WledPreset>> presets(Device device) async {
    final answer = await LocalNetwork.getJson(device.ip, '/presets.json');
    if (answer is! Map<String, dynamic>) return [];
    final list = <WledPreset>[];
    answer.forEach((key, value) {
      final id = int.tryParse(key);
      if (id == null || id == 0 || value is! Map) return;
      final name = value['n'] as String?;
      list.add(WledPreset(id, (name == null || name.isEmpty) ? 'Preset $id' : name));
    });
    list.sort((a, b) => a.id.compareTo(b.id));
    return list;
  }

  // ---------------------------------------------------------------------------
  //  Controlling
  // ---------------------------------------------------------------------------

  /// Send any WLED state change, e.g. {'on': true}.
  static Future<void> setState(Device device, Map<String, dynamic> change) async {
    await LocalNetwork.postJson(device.ip, '/json/state', change);
  }

  /// Change settings of segment 0 only.
  static Future<void> setSegment(Device device, Map<String, dynamic> change) =>
      setState(device, {
        'seg': [
          {'id': 0, ...change}
        ]
      });

  static Future<void> setPower(Device device, bool on) => setState(device, {'on': on});

  static Future<void> setBrightness(Device device, int percent) =>
      setState(device, {'on': true, 'bri': _toWled(percent)});

  /// Sets the primary colour (and switches the strip on).
  static Future<void> setColor(Device device, List<int> rgb) => setState(device, {
        'on': true,
        'seg': [
          {
            'id': 0,
            'col': [
              [rgb[0], rgb[1], rgb[2]]
            ]
          }
        ],
      });

  static Future<void> setEffect(Device device, int id) => setSegment(device, {'fx': id});
  static Future<void> setSpeed(Device device, int value) => setSegment(device, {'sx': value.clamp(0, 255)});
  static Future<void> setIntensity(Device device, int value) => setSegment(device, {'ix': value.clamp(0, 255)});
  static Future<void> setPalette(Device device, int id) => setSegment(device, {'pal': id});

  static Future<void> applyPreset(Device device, int id) => setState(device, {'ps': id});

  /// Save what the strip is showing now as preset [id] called [name].
  static Future<void> savePreset(Device device, int id, String name) =>
      setState(device, {'psave': id, 'n': name});
}
