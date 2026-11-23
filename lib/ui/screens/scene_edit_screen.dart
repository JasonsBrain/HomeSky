// =============================================================================
//  scene_edit_screen.dart – create or edit a scene.
//  Tick the devices to include, then choose what each one does.
//  Unticked devices are left alone when the scene runs.
// =============================================================================

import 'package:flutter/material.dart';

import '../../models/device.dart';
import '../../models/scene.dart';
import '../../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/top_bar.dart';

class SceneEditScreen extends StatefulWidget {
  /// Pass an existing scene to edit it, or nothing to create a new one.
  const SceneEditScreen({super.key, this.scene});
  final Scene? scene;

  @override
  State<SceneEditScreen> createState() => _SceneEditScreenState();
}

class _SceneEditScreenState extends State<SceneEditScreen> {
  late final TextEditingController _name;

  /// Working copy: edits only take effect when SAVE is pressed.
  late final Map<String, SceneAction> _actions;

  bool get _isNew => widget.scene == null;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.scene?.name ?? '');
    _actions = {
      for (final e in (widget.scene?.actions ?? {}).entries)
        e.key: SceneAction(on: e.value.on, brightness: e.value.brightness, color: e.value.color),
    };
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Scene _build() => Scene(
        id: widget.scene?.id ?? AppState.newId(),
        name: _name.text.trim().isEmpty ? 'Scene' : _name.text.trim(),
        actions: Map.of(_actions),
      );

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final included = _actions.keys.where((id) => app.deviceById(id) != null).length;

    return Scaffold(
      body: Column(children: [
        BackHeader(backLabel: 'Scenes', title: _isNew ? 'New scene' : 'Edit scene', subtitle: widget.scene?.name),
        Expanded(
          child: ListView(padding: const EdgeInsets.all(16), children: [
            MaxWidth(
              child: Gapped(children: [
                Panel(children: [
                  const SectionLabel('Name'),
                  TextField(
                    controller: _name,
                    style: HS.style(size: 13),
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(hintText: 'e.g. Movie'),
                  ),
                ]),
                Panel(children: [
                  SectionLabel('Devices', trailing: Caps('$included of ${app.devices.length} included', size: 10, color: HS.muted)),
                  for (final device in app.devices) _deviceRow(device),
                ]),
                SpecialButton('Try it now', minHeight: 52, onTap: () => app.runScene(_build())),
                PrimaryButton('Save scene', onTap: () async {
                  await app.saveScene(_build());
                  if (context.mounted) Navigator.pop(context);
                }),
                if (!_isNew)
                  DangerButton('Delete scene', onTap: () async {
                    final ok = await confirmDelete(
                      context,
                      title: 'Delete ${widget.scene!.name}?',
                      body: 'The scene is removed. Your devices are not changed.',
                    );
                    if (!ok) return;
                    await app.deleteScene(widget.scene!);
                    if (context.mounted) Navigator.pop(context);
                  }),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _deviceRow(Device device) {
    final accent = accentOf(context);
    final action = _actions[device.id];
    final inScene = action != null;

    String summary;
    if (action == null) {
      summary = 'Not in this scene';
    } else if (!action.on) {
      summary = 'Turns off';
    } else if (device.isLight) {
      summary = 'On · ${action.brightness}% · ${action.color.name}';
    } else {
      summary = 'Turns on';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: HS.header,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: inScene ? HS.borderStrong : HS.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // ---- Include checkbox ----
        Semantics(
          checked: inScene,
          label: 'Include ${device.name}',
          child: InkWell(
            onTap: () => setState(() {
              if (inScene) {
                _actions.remove(device.id);
              } else {
                _actions[device.id] = SceneAction(on: true);
              }
            }),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Row(children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: inScene ? accent : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: inScene ? accent : HS.faint, width: 2),
                  ),
                  child: inScene ? Icon(Icons.check, size: 16, color: HS.onAccent(accent)) : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Caps(device.name, size: 12, maxLines: 1),
                    const SizedBox(height: 3),
                    Caps(summary, size: 9, color: HS.muted, maxLines: 1),
                  ]),
                ),
              ]),
            ),
          ),
        ),

        if (action != null) ...[
          const SizedBox(height: 12),
          // ---- On / Off ----
          Row(children: [
            Expanded(child: _segment('On', action.on, accent, () => setState(() => action.on = true))),
            const SizedBox(width: 6),
            Expanded(child: _segment('Off', !action.on, accent, () => setState(() => action.on = false))),
          ]),

          // ---- Brightness + colour (lights that are on) ----
          if (device.isLight && action.on) ...[
            const SizedBox(height: 10),
            LabeledSlider(
              label: 'Brightness',
              value: action.brightness,
              onChanged: (v) => setState(() => action.brightness = v),
              onChangeEnd: (_) {},
            ),
            Row(children: [
              for (final choice in ColorChoice.values) ...[
                if (choice != ColorChoice.white) const SizedBox(width: 6),
                Expanded(
                  child: _segment(
                    choice.name,
                    action.color == choice,
                    accent,
                    () => setState(() => action.color = choice),
                    swatch: switch (choice) {
                      ColorChoice.white => const Color(0xFFF4F1EA),
                      ColorChoice.yellow => const Color(0xFFFFB028),
                      ColorChoice.last => Color.fromARGB(255, device.lastColor[0], device.lastColor[1], device.lastColor[2]),
                    },
                  ),
                ),
              ],
            ]),
          ],
        ],
      ]),
    );
  }

  Widget _segment(String label, bool active, Color accent, VoidCallback onTap, {Color? swatch}) => Tap(
        onTap: onTap,
        selected: active,
        color: swatch != null ? HS.surface : (active ? accent : Colors.transparent),
        borderColor: active ? accent : HS.borderStrong,
        radius: 8,
        minHeight: 44,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (swatch != null) ...[
            Container(width: 16, height: 16, decoration: BoxDecoration(color: swatch, shape: BoxShape.circle)),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Caps(label, size: 9, maxLines: 1, color: swatch == null && active ? HS.onAccent(accent) : HS.text),
          ),
        ]),
      );
}
