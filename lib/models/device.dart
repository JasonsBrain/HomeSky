// =============================================================================
//  device.dart – what Homesky knows about each device.
//
//  Device       = the saved settings (name, IP address, type...). Stored on
//                 this phone/PC only.
//  DeviceState  = the live status (on/off, brightness, watts...). Never
//                 stored; it's refreshed from the device every few seconds.
// =============================================================================

/// Which firmware/protocol the device speaks.
/// To add a new kind of device later (e.g. Tuya), add it here and write a
/// matching client in lib/services/.
enum DeviceType {
  tasmota('Tasmota'),
  wled('WLED');

  const DeviceType(this.label);
  final String label;
}

/// What the device is, which decides the controls shown for it.
enum DeviceKind {
  plug, //  on/off only (may also measure power)
  light, // on/off, brightness, colour
  strip, // like a light, plus WLED effects
}

/// The three colour buttons on the light panel.
enum ColorChoice { white, yellow, last }

/// A saved device.
class Device {
  Device({
    required this.id,
    required this.name,
    required this.type,
    required this.kind,
    required this.ip,
    this.password = '',
    List<int>? lastColor,
  }) : lastColor = lastColor ?? [238, 95, 156]; // default "last colour": Vice pink

  /// Unique id, created when the device is added. Never shown.
  final String id;

  String name;
  DeviceType type;
  DeviceKind kind;

  /// The device's address on the home network, e.g. 192.168.1.21.
  /// Tip: give your devices fixed addresses in your router so these never change.
  String ip;

  /// Optional Tasmota web password (Tasmota → Configuration → Other).
  /// Stored only in this app's private storage, which is excluded from backups.
  String password;

  /// The last custom colour used (red, green, blue 0–255). Shown as "LAST".
  List<int> lastColor;

  bool get isLight => kind == DeviceKind.light || kind == DeviceKind.strip;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.name,
        'kind': kind.name,
        'ip': ip,
        'password': password,
        'lastColor': lastColor,
      };

  factory Device.fromJson(Map<String, dynamic> json) => Device(
        id: json['id'] as String,
        name: json['name'] as String? ?? 'Device',
        type: DeviceType.values.firstWhere((t) => t.name == json['type'], orElse: () => DeviceType.tasmota),
        kind: DeviceKind.values.firstWhere((k) => k.name == json['kind'], orElse: () => DeviceKind.plug),
        ip: json['ip'] as String? ?? '',
        password: json['password'] as String? ?? '',
        lastColor: (json['lastColor'] as List?)?.map((e) => (e as num).toInt()).toList(),
      );
}

/// Live status of one device. Filled in by the polling in app_state.dart.
class DeviceState {
  /// False when the device didn't answer the last check.
  bool reachable = false;

  /// True until the first answer arrives (so we can show "connecting").
  bool waiting = true;

  /// Tasmota asked for a password we don't have (or have wrong).
  bool needsPassword = false;

  /// Why the last check or command failed, in plain words (null = it worked).
  /// Shown in the "not responding" warning to help track down problems.
  String? lastError;

  bool on = false;

  /// 0–100 %.
  int brightness = 100;

  /// Current colour (red, green, blue 0–255), if the device reports one.
  List<int>? rgb;

  /// Which of the three colour buttons is active, if any.
  ColorChoice? colorChoice;

  // ---- Energy (Tasmota plugs with a power meter) ----
  bool hasEnergy = false;
  double? watts; //       right now
  double? todayKwh; //    since midnight
  double? yesterdayKwh;

  // ---- WLED extras ----
  int effect = 0;
  int speed = 128; //     0–255
  int intensity = 128; // 0–255
  int palette = 0;
}
