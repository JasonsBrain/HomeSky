// =============================================================================
//  storage.dart – saves and loads everything Homesky remembers.
//
//  Where data lives: in the app's private storage on THIS device only
//  (Android: app-private SharedPreferences; Windows: the app's local folder).
//  Nothing is synced anywhere. On Android it is also excluded from Google
//  backups and phone-to-phone transfers (see tool/patch_android.py).
//
//  What is stored:
//    devices  – names, IP addresses, types, optional Tasmota passwords
//    scenes   – your saved scenes
//    settings – colour, energy price, switches
//    energy   – daily kWh per plug, so we can show weekly/monthly totals
// =============================================================================

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/device.dart';
import '../models/scene.dart';
import '../models/settings.dart';

/// Daily energy history: device id → (date "2026-11-22" → kWh used that day).
typedef EnergyHistory = Map<String, Map<String, double>>;

class Storage {
  Storage._(this._prefs);
  final SharedPreferences _prefs;

  // Keys. Changing one makes the app "forget" that data, so leave them be.
  static const _devicesKey = 'homesky.devices';
  static const _scenesKey = 'homesky.scenes';
  static const _settingsKey = 'homesky.settings';
  static const _energyKey = 'homesky.energy';

  static Future<Storage> open() async => Storage._(await SharedPreferences.getInstance());

  // ---- Devices ----
  List<Device> loadDevices() => _loadList(_devicesKey).map(Device.fromJson).toList();
  Future<void> saveDevices(List<Device> devices) =>
      _prefs.setString(_devicesKey, jsonEncode(devices.map((d) => d.toJson()).toList()));

  // ---- Scenes ----
  List<Scene> loadScenes() => _loadList(_scenesKey).map(Scene.fromJson).toList();
  Future<void> saveScenes(List<Scene> scenes) =>
      _prefs.setString(_scenesKey, jsonEncode(scenes.map((s) => s.toJson()).toList()));

  // ---- Settings ----
  AppSettings loadSettings() {
    final raw = _prefs.getString(_settingsKey);
    if (raw == null) return AppSettings();
    try {
      return AppSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return AppSettings(); // Damaged data: start with defaults rather than crash.
    }
  }

  Future<void> saveSettings(AppSettings settings) => _prefs.setString(_settingsKey, jsonEncode(settings.toJson()));

  // ---- Energy history ----
  EnergyHistory loadEnergy() {
    final raw = _prefs.getString(_energyKey);
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((id, days) => MapEntry(
            id,
            (days as Map<String, dynamic>).map((day, kwh) => MapEntry(day, (kwh as num).toDouble())),
          ));
    } catch (_) {
      return {};
    }
  }

  Future<void> saveEnergy(EnergyHistory history) => _prefs.setString(_energyKey, jsonEncode(history));

  // ---- Helpers ----
  List<Map<String, dynamic>> _loadList(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List).whereType<Map<String, dynamic>>().toList();
    } catch (_) {
      return [];
    }
  }
}
