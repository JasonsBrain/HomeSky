// =============================================================================
//  devices_tab.dart – the first screen: all devices, scenes, light controls.
//
//  Phone layout:  warnings → scene buttons → device grid → energy → light panel
//  Wide layout:   device side on the left, light panel on the right.
// =============================================================================

import 'package:flutter/material.dart';

import '../../models/scene.dart';
import '../../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/device_widgets.dart';
import 'device_edit_screen.dart';

class DevicesTab extends StatelessWidget {
  const DevicesTab({super.key, required this.wide, required this.onOpenSettings});
  final bool wide;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);

    // ---- First start: nothing added yet ----
    if (app.devices.isEmpty) return const _EmptyState();

    final light = app.selectedLight;
    final hasEnergy = app.energyDevices.isNotEmpty;

    final mainColumn = Gapped(children: [
      ..._warnings(app),
      Row(children: [
        Expanded(child: Caps('All devices', size: wide ? 13 : 11, color: HS.muted, spacing: 0.14)),
        Caps(app.hasNetwork ? '${app.onCount} / ${app.devices.length} on' : 'Offline', size: wide ? 13 : 11, color: HS.muted),
      ]),
      _SceneChips(maxScenes: wide ? 4 : 2),
      LayoutBuilder(builder: (context, box) {
        // As many columns as fit, at least 2.
        final columns = (box.maxWidth / (wide ? 210 : 170)).floor().clamp(2, 6);
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: (box.maxWidth / columns) / (wide ? 150 : 112),
          children: [for (final d in app.devices) DeviceCard(device: d, height: wide ? 150 : 112)],
        );
      }),
      if (hasEnergy) const EnergyStrip(),
      if (!wide && light != null) LightPanel(device: light),
    ]);

    if (!wide) {
      return RefreshIndicator(
        onRefresh: app.refreshAll, // pull down to refresh
        child: ListView(padding: const EdgeInsets.all(16), children: [mainColumn]),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1400),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: mainColumn),
            if (light != null) ...[
              const SizedBox(width: 24),
              SizedBox(width: 400, child: LightPanel(device: light)),
            ],
          ]),
        ),
      ),
    );
  }

  List<Widget> _warnings(AppState app) {
    if (!app.hasNetwork) {
      return const [
        WarningBanner(
          icon: Icons.wifi_off,
          title: 'No Wi-Fi · Reconnecting…',
          body: "Devices can't be controlled until this device is back on your home network.",
        ),
      ];
    }
    final down = app.unreachable;
    if (down.isEmpty) return const [];
    final names = down.map((d) => d.name).join(', ');
    // Technical reason for each device, e.g. "Device did not answer within 3 s."
    final details = down
        .where((d) => app.stateOf(d).lastError != null)
        .map((d) => '${d.name} (${d.ip}): ${app.stateOf(d).lastError}')
        .join('\n');
    return [
      WarningBanner(
        title: down.length == 1 ? '1 device not responding' : '${down.length} devices not responding',
        body: '$names may be switched off at the wall, out of Wi-Fi range, or on a new IP address.'
            '${details.isEmpty ? '' : '\n\nDetails:\n$details'}',
      ),
    ];
  }
}

/// ALL OFF + the first few saved scenes.
class _SceneChips extends StatelessWidget {
  const _SceneChips({required this.maxScenes});
  final int maxScenes;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final scenes = app.scenes.take(maxScenes).toList();

    Future<void> allOff() async {
      if (app.settings.confirmAllOff) {
        final ok = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Caps('Turn everything off?', size: 14),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c, false), child: const Caps('Cancel', size: 11)),
              TextButton(onPressed: () => Navigator.pop(c, true), child: const Caps('All off', size: 11)),
            ],
          ),
        );
        if (ok != true) return;
      }
      await app.allOff();
    }

    Widget chip(String label, VoidCallback onTap, {bool special = false}) => Expanded(
          child: Tap(
            onTap: onTap,
            color: HS.surface,
            borderColor: special ? HS.pink : HS.borderStrong,
            radius: 10,
            minHeight: 44,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Center(child: Caps(label, size: 10, color: special ? HS.cyan : HS.text, maxLines: 1)),
          ),
        );

    return Row(children: [
      chip('All off', allOff),
      for (final Scene scene in scenes) ...[
        const SizedBox(width: 8),
        chip(scene.name, () => app.runScene(scene), special: scene == scenes.first),
      ],
    ]);
  }
}

/// Shown before any device has been added.
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: MaxWidth(
            width: 480,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
              decoration: BoxDecoration(
                color: HS.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: HS.borderStrong),
              ),
              child: Column(children: [
                const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.power_outlined, color: HS.faint),
                  SizedBox(width: 10),
                  Icon(Icons.lightbulb_outline, color: HS.faint),
                  SizedBox(width: 10),
                  Icon(Icons.linear_scale, color: HS.faint),
                ]),
                const SizedBox(height: 18),
                const Caps('No devices yet', size: 16, weight: FontWeight.w800, spacing: 0.12),
                const SizedBox(height: 12),
                const Caps(
                  'Add your first plug, bulb or LED strip to control it from here.',
                  size: 11,
                  color: HS.muted,
                  caps: false,
                  weight: FontWeight.w400,
                  align: TextAlign.center,
                  height: 1.6,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: 240,
                  child: PrimaryButton(
                    '+ Add device',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DeviceEditScreen())),
                  ),
                ),
              ]),
            ),
          ),
        ),
      );
}
