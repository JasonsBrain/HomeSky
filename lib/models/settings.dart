// =============================================================================
//  settings.dart – app preferences. Stored on this device only.
// =============================================================================

class AppSettings {
  AppSettings({
    this.accent = 0xFF6E9FC9,
    this.pricePerKwh = 0,
    this.confirmAllOff = false,
    this.nightDim = true,
  });

  /// Main colour (ARGB). Options are listed in lib/ui/theme.dart.
  int accent;

  /// Electricity price in pence per kWh. 0 = not set (costs are hidden).
  double pricePerKwh;

  /// Ask before a scene switches everything off.
  bool confirmAllOff;

  /// Wall panel dims itself between 23:00 and 07:00.
  bool nightDim;

  Map<String, dynamic> toJson() => {
        'accent': accent,
        'pricePerKwh': pricePerKwh,
        'confirmAllOff': confirmAllOff,
        'nightDim': nightDim,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        accent: (json['accent'] as num?)?.toInt() ?? 0xFF6E9FC9,
        pricePerKwh: (json['pricePerKwh'] as num?)?.toDouble() ?? 0,
        confirmAllOff: json['confirmAllOff'] as bool? ?? false,
        nightDim: json['nightDim'] as bool? ?? true,
      );
}
