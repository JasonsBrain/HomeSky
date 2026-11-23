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
//  Segments: changes go to all segments, or to one segment picked on the
//  WLED screen. Create/resize segments in WLED's own web page.
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

    // Read every segment.
    final segments = <WledSegment>[];
    final list = s['seg'];
    if (list is List) {
      for (var index = 0; index < list.length; index++) {
        final raw = list[index];
        if (raw is! Map) continue;
        // WLED lists unused slots with "stop": 0 – skip them.
        final stop = _int(raw['stop']);
        if (stop == 0) continue;
        segments.add(WledSegment(
          // Older WLED versions have no "id": the position in the list is the id.
          id: _int(raw['id'], index),
          start: _int(raw['start']),
          stop: stop,
          name: raw['n'] is String ? raw['n'] as String : '',
          on: raw['on'] != false,
          rgb: _firstColour(raw['col']),
          effect: _int(raw['fx']),
          speed: _int(raw['sx'], 128),
          intensity: _int(raw['ix'], 128),
          palette: _int(raw['pal']),
        ));
      }
    }
    state.segments = segments;

    // Forget a chosen segment that no longer exists.
    if (state.wledTarget != null && !segments.any((g) => g.id == state.wledTarget)) {
      state.wledTarget = null;
    }

    // Show the values of the segment being edited (or the first one for "All").
    WledSegment? shown;
    for (final g in segments) {
      if (state.wledTarget == null || g.id == state.wledTarget) {
        shown = g;
        break;
      }
    }
    if (shown != null) {
      if (shown.rgb != null) state.rgb = shown.rgb;
      state.effect = shown.effect;
      state.speed = shown.speed;
      state.intensity = shown.intensity;
      state.palette = shown.palette;
    }
  }

  static int _int(dynamic v, [int fallback = 0]) => v is num ? v.toInt() : fallback;

  static List<int>? _firstColour(dynamic col) {
    if (col is! List || col.isEmpty || col.first is! List) return null;
    final c = (col.first as List).whereType<num>().map((n) => n.toInt()).toList();
    return c.length >= 3 ? c.sublist(0, 3) : null;
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

  /// Change segment settings.
  ///
  /// [segmentIds] lists the segments to change, e.g. [0, 1]. Each segment is
  /// addressed by its id, so it works however your segments are set up.
  /// An empty list sends the change as an object, which WLED applies to all
  /// currently selected segments.
  static Future<void> setSegments(Device device, List<int> segmentIds, Map<String, dynamic> change,
      {bool alsoOn = false}) {
    final Object seg = segmentIds.isEmpty ? change : [for (final id in segmentIds) {'id': id, ...change}];
    return setState(device, {
      // Colour/effect picks also switch the strip on and stop a running
      // playlist ("pl": -1), which would otherwise overwrite your choice.
      if (alsoOn) 'on': true,
      if (alsoOn) 'pl': -1,
      'seg': seg,
    });
  }

  static Future<void> setPower(Device device, bool on) => setState(device, {'on': on});

  static Future<void> setBrightness(Device device, int percent) =>
      setState(device, {'on': true, 'bri': _toWled(percent)});

  /// Sets the primary colour (and switches the strip on).
  /// Also switches each segment on, in case it was turned off in WLED.
  static Future<void> setColor(Device device, List<int> rgb, List<int> segmentIds) => setSegments(
        device,
        segmentIds,
        {
          'on': true,
          'frz': false, // un-freeze, or a frozen segment ignores the change
          'col': [
            [rgb[0], rgb[1], rgb[2]]
          ],
        },
        alsoOn: true,
      );

  static Future<void> setEffect(Device device, int id, List<int> segmentIds) =>
      setSegments(device, segmentIds, {'fx': id, 'frz': false}, alsoOn: true);
  static Future<void> setSpeed(Device device, int value, List<int> segmentIds) =>
      setSegments(device, segmentIds, {'sx': value.clamp(0, 255)});
  static Future<void> setIntensity(Device device, int value, List<int> segmentIds) =>
      setSegments(device, segmentIds, {'ix': value.clamp(0, 255)});
  static Future<void> setPalette(Device device, int id, List<int> segmentIds) =>
      setSegments(device, segmentIds, {'pal': id});

  static Future<void> applyPreset(Device device, int id) => setState(device, {'ps': id});

  /// Save what the strip is showing now as preset [id] called [name].
  static Future<void> savePreset(Device device, int id, String name) =>
      setState(device, {'psave': id, 'n': name});
}
