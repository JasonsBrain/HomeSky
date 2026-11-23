// =============================================================================
//  settings_tab.dart – devices list, scan, display, wall panel, energy price,
//  privacy note, version.
// =============================================================================

import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/device_widgets.dart';
import 'device_edit_screen.dart';
import 'scan_screen.dart';
import 'wall_panel_screen.dart';

/// Shown under About. Keep in sync with `version:` in pubspec.yaml.
const String appVersion = '1.0.0';

class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  late final TextEditingController _price;

  @override
  void initState() {
    super.initState();
    _price = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Fill the price box once settings are loaded.
    final price = AppScope.read(context).settings.pricePerKwh;
    if (_price.text.isEmpty && price > 0) _price.text = _formatPrice(price);
  }

  @override
  void dispose() {
    _price.dispose();
    super.dispose();
  }

  static String _formatPrice(double p) => p == p.roundToDouble() ? p.toStringAsFixed(0) : p.toString();

  void _open(Widget page) => Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final accent = accentOf(context);

    return ListView(padding: const EdgeInsets.all(16), children: [
      MaxWidth(
        width: 720,
        child: Gapped(children: [
          // ---- Devices ----
          Panel(children: [
            SectionLabel('Devices', trailing: GhostButton('Scan network', icon: Icons.search, onTap: () => _open(const ScanScreen()))),
            for (final d in app.devices)
              Tap(
                onTap: () => _open(DeviceEditScreen(device: d)),
                minHeight: 60,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                semanticLabel: 'Edit ${d.name}',
                child: Row(children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: app.stateOf(d).reachable ? HS.cyan : (app.stateOf(d).waiting ? HS.faint : HS.redText),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(iconFor(d.kind), size: 18, color: HS.muted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Caps(d.name, size: 12, maxLines: 1),
                      const SizedBox(height: 4),
                      Caps('${d.type.label} · ${d.ip}', size: 9, color: HS.muted, maxLines: 1),
                    ]),
                  ),
                  const Icon(Icons.chevron_right, color: HS.muted),
                ]),
              ),
            PrimaryButton('+ Add device', onTap: () => _open(const DeviceEditScreen())),
          ]),

          // ---- Display ----
          Panel(children: [
            const SectionLabel('Main colour'),
            Row(children: [
              for (var i = 0; i < HS.accentOptions.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: Tap(
                    onTap: () => app.updateSettings((s) => s.accent = HS.accentOptions[i].toARGB32()),
                    selected: app.settings.accent == HS.accentOptions[i].toARGB32(),
                    borderColor: app.settings.accent == HS.accentOptions[i].toARGB32() ? accent : HS.borderStrong,
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                    child: Column(children: [
                      Container(width: 28, height: 28, decoration: BoxDecoration(color: HS.accentOptions[i], shape: BoxShape.circle)),
                      const SizedBox(height: 8),
                      Caps(HS.accentNames[i], size: 8, spacing: 0.02, maxLines: 1),
                    ]),
                  ),
                ),
              ],
            ]),
            ToggleRow(
              title: 'Confirm before all off',
              subtitle: 'Ask before ALL OFF switches everything off.',
              value: app.settings.confirmAllOff,
              onChanged: (v) => app.updateSettings((s) => s.confirmAllOff = v),
            ),
          ]),

          // ---- Wall panel ----
          Panel(children: [
            const SectionLabel('Wall panel'),
            ToggleRow(
              title: 'Dim at night',
              subtitle: 'Dims the wall panel between 23:00 and 07:00.',
              value: app.settings.nightDim,
              onChanged: (v) => app.updateSettings((s) => s.nightDim = v),
            ),
            SpecialButton('Open wall panel', icon: Icons.chevron_right, minHeight: 52, onTap: () => _open(const WallPanelScreen())),
            const Caps(
              'Full screen, keeps the screen on, works upright or sideways. Long-press anywhere to exit.',
              size: 10,
              color: HS.muted,
              caps: false,
              weight: FontWeight.w400,
              height: 1.5,
            ),
          ]),

          // ---- Energy ----
          Panel(children: [
            const SectionLabel('Energy'),
            TextField(
              controller: _price,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: HS.style(size: 13),
              decoration: const InputDecoration(labelText: 'Price per kWh (pence)', hintText: 'e.g. 24.50'),
              onChanged: (v) {
                final price = double.tryParse(v.replaceAll(',', '.')) ?? 0;
                app.updateSettings((s) => s.pricePerKwh = price);
              },
            ),
            const Caps(
              "Used to work out cost from what your Tasmota plugs measure. Find it on your electricity bill.",
              size: 10,
              color: HS.muted,
              caps: false,
              weight: FontWeight.w400,
              height: 1.5,
            ),
          ]),

          // ---- Privacy ----
          Panel(children: [
            const SectionLabel('Privacy'),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: HS.header, borderRadius: BorderRadius.circular(12), border: Border.all(color: HS.border)),
              child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.verified_user_outlined, color: HS.cyan, size: 22),
                SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Caps('Local only', size: 12),
                    SizedBox(height: 4),
                    Caps(
                      'Homesky only talks to devices on your home network and refuses any other address. '
                      'No accounts, no cloud, no tracking or analytics. Your data stays on this device and is '
                      'excluded from cloud backups.',
                      size: 10,
                      color: HS.muted,
                      caps: false,
                      weight: FontWeight.w400,
                      height: 1.5,
                    ),
                  ]),
                ),
              ]),
            ),
          ]),

          // ---- About ----
          Panel(children: [
            const SectionLabel('About'),
            Row(children: const [
              Expanded(child: Caps('Version', size: 10, color: HS.muted)),
              Caps(appVersion, size: 10),
            ]),
          ]),
        ]),
      ),
    ]);
  }
}
