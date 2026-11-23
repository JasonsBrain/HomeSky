// =============================================================================
//  scene.dart – a saved set of device states, run with one tap.
//  Example: "Movie" = TV plug on, LED strip 25 % in the last colour, rest off.
// =============================================================================

import 'device.dart';

/// What one device should do when the scene runs.
class SceneAction {
  SceneAction({required this.on, this.brightness = 100, this.color = ColorChoice.white});

  bool on;
  int brightness; //    0–100, lights only
  ColorChoice color; // lights only

  Map<String, dynamic> toJson() => {'on': on, 'brightness': brightness, 'color': color.name};

  factory SceneAction.fromJson(Map<String, dynamic> json) => SceneAction(
        on: json['on'] as bool? ?? false,
        brightness: (json['brightness'] as num?)?.toInt() ?? 100,
        color: ColorChoice.values.firstWhere((c) => c.name == json['color'], orElse: () => ColorChoice.white),
      );
}

class Scene {
  Scene({required this.id, required this.name, Map<String, SceneAction>? actions})
      : actions = actions ?? {};

  final String id;
  String name;

  /// Device id → what that device does. Devices not listed are left alone.
  final Map<String, SceneAction> actions;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'actions': actions.map((k, v) => MapEntry(k, v.toJson())),
      };

  factory Scene.fromJson(Map<String, dynamic> json) => Scene(
        id: json['id'] as String,
        name: json['name'] as String? ?? 'Scene',
        actions: (json['actions'] as Map<String, dynamic>? ?? {}).map(
          (k, v) => MapEntry(k, SceneAction.fromJson(v as Map<String, dynamic>)),
        ),
      );
}
