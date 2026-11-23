// =============================================================================
//  app_state.dart – the brain of the app.
//
//  Holds the device list, their live status, scenes and settings, and has
//  one method per action (toggle, set brightness, run scene...). Screens
//  read from here and call these methods; they never talk to devices directly.
//
//  Live status is refreshed by polling: every [pollEvery] seconds each device
//  is asked for its status. Polling only touches your home network.
// =============================================================================

import 'dart:async';

import 'package:flutter/widgets.dart';

import '../models/device.dart';
import '../models/scene.dart';
import '../models/settings.dart';
import '../services/local_network.dart';
import '../services/storage.dart';
import '../services/tasmota.dart';
import '../services/wled.dart';

class AppState extends ChangeNotifier {
  AppState(this._storage);
  final Storage _storage;

  /// How often devices are checked. Lower = snappier status, more Wi-Fi chatter.
  static const Duration pollEvery = Duration(seconds: 5);

  /// The three fixed colour buttons. "last" uses each device's own last colour.
  static const List<int> white = [255, 255, 255];
  static const List<int> yellow = [255, 176, 40];

  // ---------------------------------------------------------------------------
  //  Data
  // ---------------------------------------------------------------------------

  final List<Device> devices = [];
  final List<Scene> scenes = [];
  AppSettings settings = AppSettings();
  EnergyHistory energy = {};

  final Map<String, DeviceState> _states = {};

  /// False when this phone/PC has no home-network address (Wi-Fi off).
  bool hasNetwork = true;

  /// Which light the bottom control panel is showing.
  String? _selectedLightId;

  Timer? _pollTimer;
  bool _polling = false;
  int _pollCount = 0;

  /// Devices with a command in flight. Their status isn't overwritten by
  /// polling until the command finishes, so switches don't flicker.
  final Set<String> _sending = {};

  // ---------------------------------------------------------------------------
  //  Start / stop
  // ---------------------------------------------------------------------------

  Future<void> load() async {
    devices
      ..clear()
      ..addAll(_storage.loadDevices());
    scenes
      ..clear()
      ..addAll(_storage.loadScenes());
    settings = _storage.loadSettings();
    energy = _storage.loadEnergy();
    notifyListeners();

    unawaited(refreshAll());
    _pollTimer = Timer.periodic(pollEvery, (_) => refreshAll());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  //  Reading
  // ---------------------------------------------------------------------------

  DeviceState stateOf(Device device) => _states.putIfAbsent(device.id, () => DeviceState());

  Device? deviceById(String id) {
    for (final d in devices) {
      if (d.id == id) return d;
    }
    return null;
  }

  List<Device> get lights => devices.where((d) => d.isLight).toList();

  /// The light shown in the control panel (first light if none picked yet).
  Device? get selectedLight {
    final all = lights;
    if (all.isEmpty) return null;
    for (final d in all) {
      if (d.id == _selectedLightId) return d;
    }
    return all.first;
  }

  void selectLight(Device device) {
    _selectedLightId = device.id;
    notifyListeners();
  }

  /// Devices that didn't answer the last check (ignoring the no-Wi-Fi case).
  List<Device> get unreachable =>
      devices.where((d) => !stateOf(d).waiting && !stateOf(d).reachable).toList();

  int get onCount => devices.where((d) => stateOf(d).reachable && stateOf(d).on).length;

  // ---------------------------------------------------------------------------
  //  Polling
  // ---------------------------------------------------------------------------

  /// Ask every device for its status. Safe to call any time.
  Future<void> refreshAll() async {
    if (_polling) return; // Previous round still running.
    _polling = true;
    try {
      hasNetwork = await LocalNetwork.ownAddress() != null;
      if (hasNetwork) {
        await Future.wait(devices.map(_refresh));
        _recordEnergy();
      }
    } finally {
      _polling = false;
      notifyListeners();
    }
  }

  /// Refresh one device now (e.g. "tap to retry").
  Future<void> refreshDevice(Device device) async {
    stateOf(device).waiting = true;
    notifyListeners();
    await _refresh(device);
    notifyListeners();
  }

  Future<void> _refresh(Device device) async {
    if (_sending.contains(device.id)) return;
    final state = stateOf(device);
    try {
      if (device.type == DeviceType.tasmota) {
        await TasmotaClient.refresh(device, state);
      } else {
        await WledClient.refresh(device, state);
      }
      state.reachable = true;
      state.needsPassword = false;
    } on TasmotaPasswordException {
      state.reachable = false;
      state.needsPassword = true;
    } catch (_) {
      state.reachable = false;
    }
    state.waiting = false;
  }

  // ---------------------------------------------------------------------------
  //  Controlling devices
  //  Each change is shown straight away (optimistic), then sent to the device.
  //  If sending fails the device is marked "not responding".
  // ---------------------------------------------------------------------------

  Future<void> _command(Device device, Future<void> Function() send) async {
    _sending.add(device.id);
    notifyListeners();
    final state = stateOf(device);
    try {
      await send();
      state.reachable = true;
    } on TasmotaPasswordException {
      state.reachable = false;
      state.needsPassword = true;
    } catch (_) {
      state.reachable = false;
    } finally {
      state.waiting = false;
      _sending.remove(device.id);
      notifyListeners();
    }
  }

  Future<void> setPower(Device device, bool on) {
    stateOf(device).on = on;
    return _command(device, () {
      return device.type == DeviceType.tasmota
          ? TasmotaClient.setPower(device, on)
          : WledClient.setPower(device, on);
    });
  }

  Future<void> toggle(Device device) => setPower(device, !stateOf(device).on);

  /// Updates the slider position while dragging, without sending anything.
  void previewBrightness(Device device, int percent) {
    stateOf(device).brightness = percent;
    notifyListeners();
  }

  /// Sends brightness (call when the slider is released).
  Future<void> setBrightness(Device device, int percent) {
    stateOf(device)
      ..brightness = percent
      ..on = true;
    return _command(device, () async {
      if (device.type == DeviceType.tasmota) {
        await TasmotaClient.setBrightness(device, percent);
      } else {
        await WledClient.setBrightness(device, percent);
      }
    });
  }

  /// One of the WHITE / YELLOW / LAST buttons.
  Future<void> setColorChoice(Device device, ColorChoice choice) {
    final rgb = switch (choice) {
      ColorChoice.white => white,
      ColorChoice.yellow => yellow,
      ColorChoice.last => device.lastColor,
    };
    stateOf(device)
      ..colorChoice = choice
      ..rgb = rgb
      ..on = true;
    return _sendColor(device, rgb);
  }

  /// A custom colour (from the WLED hue slider). Becomes the device's "LAST".
  Future<void> setCustomColor(Device device, List<int> rgb) {
    device.lastColor = rgb;
    unawaited(_storage.saveDevices(devices));
    return setColorChoice(device, ColorChoice.last);
  }

  Future<void> _sendColor(Device device, List<int> rgb) => _command(device, () async {
        if (device.type == DeviceType.tasmota) {
          await TasmotaClient.setColor(device, rgb);
        } else {
          await WledClient.setColor(device, rgb);
        }
      });

  // ---- WLED extras ----
  Future<void> setEffect(Device device, int id) {
    stateOf(device).effect = id;
    return _command(device, () => WledClient.setEffect(device, id));
  }

  Future<void> setPalette(Device device, int id) {
    stateOf(device).palette = id;
    return _command(device, () => WledClient.setPalette(device, id));
  }

  void previewSpeed(Device device, int value) {
    stateOf(device).speed = value;
    notifyListeners();
  }

  Future<void> setSpeed(Device device, int value) {
    stateOf(device).speed = value;
    return _command(device, () => WledClient.setSpeed(device, value));
  }

  void previewIntensity(Device device, int value) {
    stateOf(device).intensity = value;
    notifyListeners();
  }

  Future<void> setIntensity(Device device, int value) {
    stateOf(device).intensity = value;
    return _command(device, () => WledClient.setIntensity(device, value));
  }

  Future<void> applyPreset(Device device, int id) async {
    await _command(device, () => WledClient.applyPreset(device, id));
    await refreshDevice(device); // Show what the preset changed.
  }

  // ---- Everything at once ----
  Future<void> allOff() => Future.wait(devices.map((d) => setPower(d, false)));

  Future<void> runScene(Scene scene) async {
    final jobs = <Future<void>>[];
    scene.actions.forEach((deviceId, action) {
      final device = deviceById(deviceId);
      if (device == null) return; // Device was deleted.
      if (!action.on) {
        jobs.add(setPower(device, false));
      } else if (device.isLight) {
        jobs.add(() async {
          await setBrightness(device, action.brightness);
          await setColorChoice(device, action.color);
        }());
      } else {
        jobs.add(setPower(device, true));
      }
    });
    await Future.wait(jobs);
  }

  // ---------------------------------------------------------------------------
  //  Editing devices, scenes and settings
  // ---------------------------------------------------------------------------

  static String newId() => DateTime.now().microsecondsSinceEpoch.toRadixString(36);

  Future<void> saveDevice(Device device) async {
    final index = devices.indexWhere((d) => d.id == device.id);
    if (index == -1) {
      devices.add(device);
    } else {
      devices[index] = device;
    }
    await _storage.saveDevices(devices);
    notifyListeners();
    unawaited(refreshDevice(device));
  }

  Future<void> deleteDevice(Device device) async {
    devices.removeWhere((d) => d.id == device.id);
    _states.remove(device.id);
    energy.remove(device.id);
    for (final scene in scenes) {
      scene.actions.remove(device.id);
    }
    await Future.wait([
      _storage.saveDevices(devices),
      _storage.saveScenes(scenes),
      _storage.saveEnergy(energy),
    ]);
    notifyListeners();
  }

  Future<void> saveScene(Scene scene) async {
    final index = scenes.indexWhere((s) => s.id == scene.id);
    if (index == -1) {
      scenes.add(scene);
    } else {
      scenes[index] = scene;
    }
    await _storage.saveScenes(scenes);
    notifyListeners();
  }

  Future<void> deleteScene(Scene scene) async {
    scenes.removeWhere((s) => s.id == scene.id);
    await _storage.saveScenes(scenes);
    notifyListeners();
  }

  Future<void> updateSettings(void Function(AppSettings s) change) async {
    change(settings);
    await _storage.saveSettings(settings);
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  //  Energy
  //  Tasmota plugs report "today" and "yesterday" kWh. We save those per day,
  //  which gives weekly and monthly totals without any cloud service.
  //  History only grows while Homesky is running (fine for an always-on hub).
  // ---------------------------------------------------------------------------

  static String dayKey(DateTime day) =>
      '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

  void _recordEnergy() {
    final now = DateTime.now();
    final today = dayKey(now);
    final yesterday = dayKey(now.subtract(const Duration(days: 1)));
    for (final device in devices) {
      final s = stateOf(device);
      if (!s.reachable || !s.hasEnergy) continue;
      final days = energy.putIfAbsent(device.id, () => {});
      if (s.todayKwh != null) days[today] = s.todayKwh!;
      if (s.yesterdayKwh != null) days[yesterday] = s.yesterdayKwh!;
      // Keep about 13 months of history.
      if (days.length > 400) {
        final keys = days.keys.toList()..sort();
        for (final k in keys.take(days.length - 400)) {
          days.remove(k);
        }
      }
    }
    // Save once a minute rather than on every poll (less storage wear).
    _pollCount++;
    if (_pollCount % 12 == 1) unawaited(_storage.saveEnergy(energy));
  }

  List<Device> get energyDevices => devices.where((d) => stateOf(d).hasEnergy).toList();

  double get wattsNow => energyDevices.fold(0.0, (sum, d) {
        final s = stateOf(d);
        return sum + (s.reachable && s.watts != null ? s.watts! : 0);
      });

  /// kWh for one day across all plugs (or one plug if [deviceId] is given).
  double kwhOn(DateTime day, {String? deviceId}) {
    final key = dayKey(day);
    var total = 0.0;
    energy.forEach((id, days) {
      if (deviceId != null && id != deviceId) return;
      total += days[key] ?? 0;
    });
    return total;
  }

  double get kwhToday => kwhOn(DateTime.now());

  double get kwhThisMonth {
    final now = DateTime.now();
    final prefix = '${now.year}-${now.month.toString().padLeft(2, '0')}-';
    var total = 0.0;
    for (final days in energy.values) {
      days.forEach((day, kwh) {
        if (day.startsWith(prefix)) total += kwh;
      });
    }
    return total;
  }

  /// "£0.34" for [kwh] at the saved price, or null when no price is set.
  String? cost(double kwh) {
    if (settings.pricePerKwh <= 0) return null;
    return '£${(kwh * settings.pricePerKwh / 100).toStringAsFixed(2)}';
  }
}

/// Makes [AppState] available to every screen:  final app = AppScope.of(context);
/// Screens that call this rebuild automatically whenever the state changes.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child}) : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  /// Same, without rebuilding when the state changes (for button handlers).
  static AppState read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
