// =============================================================================
//  wled_screen.dart – "All options" for a WLED strip:
//  power, brightness, custom colour, effects, speed/intensity, palettes,
//  presets. Effect, palette and preset names are read from your strip.
// =============================================================================

import 'package:flutter/material.dart';

import '../../models/device.dart';
import '../../services/wled.dart';
import '../../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/top_bar.dart';

class WledScreen extends StatefulWidget {
  const WledScreen({super.key, required this.device});
  final Device device;

  @override
  State<WledScreen> createState() => _WledScreenState();
}

class _WledScreenState extends State<WledScreen> {
  List<String> _effects = [];
  List<String> _palettes = [];
  List<WledPreset> _presets = [];
  bool _loading = true;
  bool _showAllEffects = false;
  String _search = '';

  /// Hue (0–359) of the custom colour picker.
  double _hue = 330;

  @override
  void initState() {
    super.initState();
    _loadLists();
  }

  /// Effect, palette and preset names come from the strip itself.
  Future<void> _loadLists() async {
    try {
      final results = await Future.wait([
        WledClient.effects(widget.device),
        WledClient.palettes(widget.device),
      ]);
      final presets = await WledClient.presets(widget.device).catchError((_) => <WledPreset>[]);
      if (!mounted) return;
      setState(() {
        _effects = results[0];
        _palettes = results[1];
        _presets = presets;
      });
    } catch (_) {
      // Strip unreachable: the lists stay empty and a message is shown.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final device = widget.device;
    final s = app.stateOf(device);
    final accent = accentOf(context);

    return Scaffold(
      body: Column(children: [
        BackHeader(backLabel: 'Devices', title: device.name, subtitle: 'WLED · ${s.reachable ? 'Online' : 'Not responding'}'),
        Expanded(
          child: ListView(padding: const EdgeInsets.all(16), children: [
            MaxWidth(
              child: Gapped(children: [
                // ---- Power + brightness ----
                Panel(children: [
                  Semantics(
                    toggled: s.on,
                    child: Tap(
                      onTap: () => app.toggle(device),
                      minHeight: 56,
                      padding: const EdgeInsets.only(left: 16, right: 12),
                      child: Row(children: [
                        Expanded(child: Caps('Power · ${s.on ? 'On' : 'Off'}', size: 13, spacing: 0.1)),
                        PillSwitch(on: s.on),
                      ]),
                    ),
                  ),
                  LabeledSlider(
                    label: 'Brightness',
                    value: s.brightness,
                    onChanged: (v) => app.previewBrightness(device, v),
                    onChangeEnd: (v) => app.setBrightness(device, v),
                  ),
                ]),

                // ---- Segments ----
                // Pick which part of the strip the controls below change.
                if (s.segments.length > 1)
                  Panel(children: [
                    SectionLabel('Segments', trailing: Caps('${s.segments.length}', size: 11, color: HS.muted)),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      _chip('All segments', s.wledTarget == null, accent, () => app.setWledTarget(device, null)),
                      for (final g in s.segments)
                        _chip('${g.label} · ${g.ledRange}', s.wledTarget == g.id, accent, () => app.setWledTarget(device, g.id)),
                    ]),
                    Caps(
                      s.wledTarget == null
                          ? 'Colour, effect and palette changes go to every segment.'
                          : 'Colour, effect and palette changes go to this segment only.',
                      size: 10,
                      color: HS.muted,
                      caps: false,
                      weight: FontWeight.w400,
                      height: 1.5,
                    ),
                  ]),

                // ---- Colour ----
                Panel(children: [
                  SectionLabel('Colour',
                      trailing: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: _rgbColor(s.rgb ?? device.lastColor),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: HS.borderStrong),
                        ),
                      )),
                  _HueSlider(
                    hue: _hue,
                    onChanged: (h) => setState(() => _hue = h),
                    onChangeEnd: (h) => app.setCustomColor(device, _hueToRgb(h)),
                  ),
                  Row(children: [
                    for (final h in const [0.0, 30.0, 50.0, 140.0, 210.0, 300.0]) ...[
                      if (h != 0) const SizedBox(width: 8),
                      Expanded(
                        child: Tap(
                          onTap: () {
                            setState(() => _hue = h);
                            app.setCustomColor(device, _hueToRgb(h));
                          },
                          color: _rgbColor(_hueToRgb(h)),
                          radius: 10,
                          minHeight: 44,
                          semanticLabel: 'Colour hue ${h.round()}',
                          child: const SizedBox.shrink(),
                        ),
                      ),
                    ],
                  ]),
                ]),

                // ---- Effects ----
                Panel(children: [
                  SectionLabel('Effect',
                      trailing: Caps(_effects.isEmpty ? '' : _effectName(s.effect), size: 11, maxLines: 1)),
                  if (_loading)
                    const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
                  else if (_effects.isEmpty)
                    const Caps('Could not load effects from the strip.', size: 10, color: HS.muted, caps: false)
                  else ...[
                    TextField(
                      onChanged: (v) => setState(() => _search = v.trim().toLowerCase()),
                      style: HS.style(size: 12),
                      decoration: const InputDecoration(hintText: 'Search effects', prefixIcon: Icon(Icons.search, color: HS.muted)),
                    ),
                    _effectGrid(app, s, accent),
                    if (_search.isEmpty)
                      GhostButton(
                        _showAllEffects ? 'Show fewer' : 'Show all ${_effects.length} effects',
                        onTap: () => setState(() => _showAllEffects = !_showAllEffects),
                      ),
                  ],
                  LabeledSlider(
                    label: 'Speed',
                    value: s.speed,
                    min: 0,
                    max: 255,
                    unit: '',
                    onChanged: (v) => app.previewSpeed(device, v),
                    onChangeEnd: (v) => app.setSpeed(device, v),
                  ),
                  LabeledSlider(
                    label: 'Intensity',
                    value: s.intensity,
                    min: 0,
                    max: 255,
                    unit: '',
                    onChanged: (v) => app.previewIntensity(device, v),
                    onChangeEnd: (v) => app.setIntensity(device, v),
                  ),
                ]),

                // ---- Palettes ----
                if (_palettes.isNotEmpty)
                  Panel(children: [
                    const SectionLabel('Palette'),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (var i = 0; i < _palettes.length; i++)
                        _chip(_palettes[i], i == s.palette, accent, () => app.setPalette(device, i)),
                    ]),
                  ]),

                // ---- Presets ----
                Panel(children: [
                  SectionLabel('Presets',
                      trailing: SpecialButton('+ Save current', minHeight: 44, onTap: () => _savePreset(app))),
                  if (_presets.isEmpty)
                    const Caps('No presets saved on this strip yet.', size: 10, color: HS.muted, caps: false)
                  else
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final p in _presets) _chip(p.name, false, accent, () => app.applyPreset(device, p.id)),
                    ]),
                ]),

                const Caps(
                  'To create, resize or rename segments, use WLED\'s own web page (Segments section). They show up here automatically.',
                  size: 9,
                  color: HS.faint,
                  caps: false,
                  weight: FontWeight.w400,
                  height: 1.5,
                ),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }

  String _effectName(int id) => id >= 0 && id < _effects.length ? _effects[id] : 'Effect $id';

  Widget _effectGrid(AppState app, DeviceState s, Color accent) {
    // Effect ids are their position in the list. WLED marks hidden/reserved
    // entries with "RSVD" or "-", so those are skipped.
    final entries = <MapEntry<int, String>>[];
    for (var i = 0; i < _effects.length; i++) {
      final name = _effects[i];
      if (name == 'RSVD' || name == '-') continue;
      if (_search.isNotEmpty && !name.toLowerCase().contains(_search)) continue;
      entries.add(MapEntry(i, name));
    }
    final shown = (_search.isEmpty && !_showAllEffects) ? entries.take(12).toList() : entries;
    return Wrap(spacing: 8, runSpacing: 8, children: [
      for (final e in shown) _chip(e.value, e.key == s.effect, accent, () => app.setEffect(widget.device, e.key)),
    ]);
  }

  Widget _chip(String label, bool selected, Color accent, VoidCallback onTap) => Tap(
        onTap: onTap,
        selected: selected,
        color: selected ? accent : HS.header,
        borderColor: selected ? accent : HS.borderStrong,
        radius: 10,
        minHeight: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
          Caps(label, size: 9, color: selected ? HS.onAccent(accent) : HS.text, spacing: 0.04),
        ]),
      );

  Future<void> _savePreset(AppState app) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Caps('Save preset', size: 14),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: HS.style(size: 12),
          decoration: const InputDecoration(hintText: 'Name, e.g. Evening'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Caps('Cancel', size: 11)),
          TextButton(onPressed: () => Navigator.pop(c, controller.text.trim()), child: const Caps('Save', size: 11)),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    // Use the first free preset slot (WLED allows 1–250).
    final used = _presets.map((p) => p.id).toSet();
    var id = 1;
    while (used.contains(id) && id < 250) {
      id++;
    }
    try {
      await WledClient.savePreset(widget.device, id, name);
      final presets = await WledClient.presets(widget.device);
      if (mounted) setState(() => _presets = presets);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not save the preset.')));
      }
    }
  }

  static Color _rgbColor(List<int> rgb) => Color.fromARGB(255, rgb[0], rgb[1], rgb[2]);

  /// Hue (0–359) at full saturation → RGB.
  static List<int> _hueToRgb(double hue) {
    final c = HSVColor.fromAHSV(1, hue % 360, 1, 1).toColor();
    return [(c.r * 255).round(), (c.g * 255).round(), (c.b * 255).round()];
  }
}

/// A rainbow bar with a slider for picking a colour.
class _HueSlider extends StatelessWidget {
  const _HueSlider({required this.hue, required this.onChanged, required this.onChangeEnd});
  final double hue;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Expanded(child: Caps('Hue', size: 11, color: HS.muted, spacing: 0.12)),
          Caps('${hue.round()}°', size: 11),
        ]),
        const SizedBox(height: 6),
        Stack(alignment: Alignment.center, children: [
          Container(
            height: 12,
            margin: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              gradient: const LinearGradient(colors: [
                Color(0xFFFF0000),
                Color(0xFFFFFF00),
                Color(0xFF00FF00),
                Color(0xFF00FFFF),
                Color(0xFF0000FF),
                Color(0xFFFF00FF),
                Color(0xFFFF0000),
              ]),
            ),
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 12,
              activeTrackColor: Colors.transparent,
              inactiveTrackColor: Colors.transparent,
              thumbColor: HS.text,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 13),
            ),
            child: Slider(
              value: hue,
              min: 0,
              max: 359,
              semanticFormatterCallback: (v) => 'Hue ${v.round()} degrees',
              onChanged: onChanged,
              onChangeEnd: onChangeEnd,
            ),
          ),
        ]),
      ]);
}
