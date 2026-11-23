// =============================================================================
//  scenes_tab.dart – list of saved scenes. RUN to apply, pencil to edit.
// =============================================================================

import 'package:flutter/material.dart';

import '../../models/device.dart';
import '../../models/scene.dart';
import '../../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'scene_edit_screen.dart';

class ScenesTab extends StatefulWidget {
  const ScenesTab({super.key});

  @override
  State<ScenesTab> createState() => _ScenesTabState();
}

class _ScenesTabState extends State<ScenesTab> {
  /// The scene that was run last (highlighted as ACTIVE).
  String? _activeId;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final accent = accentOf(context);

    void openEditor([Scene? scene]) =>
        Navigator.push(context, MaterialPageRoute(builder: (_) => SceneEditScreen(scene: scene)));

    return ListView(padding: const EdgeInsets.all(16), children: [
      MaxWidth(
        width: 720,
        child: Gapped(gap: 12, children: [
          SectionLabel('Your scenes',
              trailing: Caps('${app.scenes.length} scene${app.scenes.length == 1 ? '' : 's'}', size: 11, color: HS.muted)),
          if (app.scenes.isEmpty)
            const Caps(
              'Scenes switch several devices at once – for example "Movie": TV plug on, LED strip dimmed, everything else off.',
              size: 11,
              color: HS.muted,
              caps: false,
              weight: FontWeight.w400,
              height: 1.6,
            ),
          for (final scene in app.scenes)
            _SceneRow(
              scene: scene,
              summary: _summary(app, scene),
              active: scene.id == _activeId,
              accent: accent,
              onRun: () {
                setState(() => _activeId = scene.id);
                app.runScene(scene);
              },
              onEdit: () => openEditor(scene),
            ),
          Tap(
            onTap: app.devices.isEmpty ? null : () => openEditor(),
            color: Colors.transparent,
            dashed: true,
            radius: 14,
            minHeight: 56,
            child: Center(
              child: Caps(app.devices.isEmpty ? 'Add a device first' : '+ New scene', size: 12, color: HS.muted, spacing: 0.12),
            ),
          ),
        ]),
      ),
    ]);
  }

  /// e.g. "TV plug on · LED strip 25% last · Desk lamp off"
  String _summary(AppState app, Scene scene) {
    final parts = <String>[];
    scene.actions.forEach((id, action) {
      final d = app.deviceById(id);
      if (d == null) return;
      if (!action.on) {
        parts.add('${d.name} off');
      } else if (d.isLight) {
        parts.add('${d.name} ${action.brightness}% ${action.color == ColorChoice.last ? 'last colour' : action.color.name}');
      } else {
        parts.add('${d.name} on');
      }
    });
    return parts.isEmpty ? 'No devices yet' : parts.join(' · ');
  }
}

class _SceneRow extends StatelessWidget {
  const _SceneRow({
    required this.scene,
    required this.summary,
    required this.active,
    required this.accent,
    required this.onRun,
    required this.onEdit,
  });

  final Scene scene;
  final String summary;
  final bool active;
  final Color accent;
  final VoidCallback onRun;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: HS.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: active ? accent : HS.border),
        ),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Caps(scene.name, size: 13, weight: FontWeight.w800, spacing: 0.08, maxLines: 1),
              const SizedBox(height: 6),
              Caps(summary, size: 10, color: HS.muted, caps: false, weight: FontWeight.w400, height: 1.5, maxLines: 3),
            ]),
          ),
          const SizedBox(width: 10),
          Semantics(
            label: 'Edit ${scene.name}',
            button: true,
            excludeSemantics: true,
            child: Tap(
              onTap: onEdit,
              color: Colors.transparent,
              radius: 10,
              minHeight: 44,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: const Icon(Icons.edit_outlined, color: HS.muted, size: 18),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 84,
            child: Tap(
              onTap: onRun,
              color: active ? accent : Colors.transparent,
              borderColor: active ? accent : HS.borderStrong,
              radius: 10,
              minHeight: 44,
              padding: EdgeInsets.zero,
              child: Center(child: Caps(active ? 'Active' : 'Run', size: 10, color: active ? HS.onAccent(accent) : HS.text, spacing: 0.1)),
            ),
          ),
        ]),
      );
}
