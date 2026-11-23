// =============================================================================
//  device_widgets.dart – pieces of the Devices screen:
//    DeviceCard   – one tile in the grid (tap = on/off)
//    LightPanel   – power / brightness / colour for the selected light
//    EnergyStrip  – "NOW 94 W · TODAY £0.34" bar that opens the Energy page
// =============================================================================

import 'package:flutter/material.dart';

import '../../models/device.dart';
import '../../state/app_state.dart';
import '../screens/energy_screen.dart';
import '../screens/wled_screen.dart';
import '../theme.dart';
import 'common.dart';

IconData iconFor(DeviceKind kind) => switch (kind) {
      DeviceKind.plug => Icons.power_outlined,
      DeviceKind.light => Icons.lightbulb_outline,
      DeviceKind.strip => Icons.linear_scale,
    };

/// One device tile. Tap toggles it; a "not responding" tile retries instead.
/// The corner button opens light controls (lights) or energy (metering plugs).
class DeviceCard extends StatelessWidget {
  const DeviceCard({super.key, required this.device, this.height = 112});
  final Device device;
  final double height;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final s = app.stateOf(device);
    final accent = accentOf(context);
    final onAccent = HS.onAccent(accent);

    final noNetwork = !app.hasNetwork;
    final offline = !noNetwork && !s.waiting && !s.reachable;
    final unavailable = noNetwork || offline;
    final on = !unavailable && s.reachable && s.on;
    final selected = device.isLight && app.selectedLight?.id == device.id;

    // ---- Status line under the name ----
    String status;
    if (noNetwork) {
      status = 'No connection';
    } else if (s.waiting) {
      status = 'Connecting…';
    } else if (s.needsPassword) {
      status = 'Needs password';
    } else if (offline) {
      status = 'Not responding · tap to retry';
    } else if (!device.isLight) {
      final watts = s.hasEnergy && on && s.watts != null ? ' · ${s.watts!.round()} W' : '';
      status = on ? '${device.type.label}$watts' : '${device.type.label} · Off';
    } else {
      status = '${device.type.label} · ${on ? '${s.brightness}%' : 'Off'}';
    }

    final fg = on ? onAccent : (unavailable ? HS.faint : HS.text);
    final sub = on ? onAccent : (offline ? HS.redText : HS.muted);
    final border = on ? accent : (offline ? HS.red : HS.track);

    // ---- Corner button ----
    Widget? corner;
    if (!unavailable && device.isLight) {
      corner = _CornerButton(
        icon: Icons.tune,
        label: 'Adjust ${device.name}',
        selected: selected,
        cardOn: on,
        onTap: () => app.selectLight(device),
      );
    } else if (!unavailable && s.hasEnergy) {
      corner = _CornerButton(
        icon: Icons.bolt,
        label: 'Energy use, ${device.name}',
        selected: false,
        cardOn: on,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EnergyScreen())),
      );
    }

    return Stack(children: [
      Semantics(
        toggled: on,
        label: '${device.name}, $status',
        excludeSemantics: true,
        button: true,
        child: Material(
          color: on ? accent : (unavailable ? HS.header : HS.surface),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: border, width: unavailable ? 1 : 1.2),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: noNetwork
                ? null
                : offline
                    ? () => app.refreshDevice(device)
                    : () => app.toggle(device),
            child: SizedBox(
              height: height,
              width: double.infinity,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(iconFor(device.kind), color: fg, size: 24),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Caps(device.name, size: 12, color: fg, weight: FontWeight.w800, maxLines: 2),
                      const SizedBox(height: 4),
                      Caps(status, size: 9, color: sub, maxLines: 1),
                    ]),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      if (corner != null) Positioned(top: 6, right: 6, child: corner),
    ]);
  }
}

class _CornerButton extends StatelessWidget {
  const _CornerButton({required this.icon, required this.label, required this.selected, required this.cardOn, required this.onTap});
  final IconData icon;
  final String label;
  final bool selected;
  final bool cardOn;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = accentOf(context);
    final dark = HS.onAccent(accent);
    final bg = selected ? (cardOn ? dark : accent) : Colors.transparent;
    final fg = selected ? (cardOn ? accent : dark) : (cardOn ? dark : HS.muted);
    final border = selected ? bg : (cardOn ? dark : HS.track);
    return Semantics(
      label: label,
      button: true,
      selected: selected,
      excludeSemantics: true,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: border)),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(width: 44, height: 44, child: Icon(icon, size: 20, color: fg)),
        ),
      ),
    );
  }
}

/// Controls for the selected light: power, brightness, colour.
class LightPanel extends StatelessWidget {
  const LightPanel({super.key, required this.device});
  final Device device;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final s = app.stateOf(device);
    final accent = accentOf(context);

    return Panel(children: [
      // Name + "All options" (WLED only)
      Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Caps(device.name, size: 15, weight: FontWeight.w800, spacing: 0.1, maxLines: 1),
            const SizedBox(height: 3),
            Caps(device.type.label, size: 10, color: HS.muted),
          ]),
        ),
        if (device.type == DeviceType.wled)
          SpecialButton(
            'All options',
            icon: Icons.chevron_right,
            minHeight: 44,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => WledScreen(device: device))),
          ),
      ]),

      // Power
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

      // Brightness
      LabeledSlider(
        label: 'Brightness',
        value: s.brightness,
        onChanged: (v) => app.previewBrightness(device, v),
        onChangeEnd: (v) => app.setBrightness(device, v),
      ),

      // Colour: white / yellow / last
      const SectionLabel('Colour'),
      Row(children: [
        for (final choice in ColorChoice.values) ...[
          if (choice != ColorChoice.white) const SizedBox(width: 8),
          Expanded(
            child: Tap(
              onTap: () => app.setColorChoice(device, choice),
              selected: s.colorChoice == choice,
              borderColor: s.colorChoice == choice ? accent : HS.borderStrong,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(color: _swatch(device, choice), shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Flexible(child: Caps(choice.name, size: 9, spacing: 0.02, maxLines: 1)),
              ]),
            ),
          ),
        ],
      ]),
    ]);
  }

  static Color _swatch(Device device, ColorChoice choice) {
    final rgb = switch (choice) {
      ColorChoice.white => const [244, 241, 234], // shown slightly warm so it reads as "white light"
      ColorChoice.yellow => AppState.yellow,
      ColorChoice.last => device.lastColor,
    };
    return Color.fromARGB(255, rgb[0], rgb[1], rgb[2]);
  }
}

/// "NOW 94 W · TODAY £0.34" – opens the Energy page.
class EnergyStrip extends StatelessWidget {
  const EnergyStrip({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final accent = accentOf(context);
    final today = app.cost(app.kwhToday) ?? '${app.kwhToday.toStringAsFixed(2)} kWh';
    return Tap(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EnergyScreen())),
      color: HS.surface,
      borderColor: HS.border,
      semanticLabel: 'Energy',
      child: Row(children: [
        Icon(Icons.bolt, color: accent, size: 20),
        const SizedBox(width: 12),
        Caps('Now ${app.wattsNow.round()} W', size: 10),
        const SizedBox(width: 14),
        Expanded(child: Caps('Today $today', size: 10, color: HS.muted, maxLines: 1)),
        const Icon(Icons.chevron_right, color: HS.muted, size: 18),
      ]),
    );
  }
}
