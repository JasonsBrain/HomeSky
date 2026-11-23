// =============================================================================
//  wall_panel_screen.dart – full-screen mode for an old phone on the wall.
//
//  - Big clock and date, big tap-to-toggle tiles, scene buttons.
//  - Upright (portrait) and sideways (landscape) layouts.
//  - Keeps the screen on and hides the system bars while open.
//  - Dims itself at night if "Dim at night" is on in Settings.
//  - LONG-PRESS anywhere on the background to exit.
// =============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../models/device.dart';
import '../../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/logo.dart';
import '../widgets/top_bar.dart';

/// Night dimming hours (24 h clock). Change these to suit you.
const int nightStartHour = 23;
const int nightEndHour = 7;

/// How dim the panel gets at night (1.0 = normal, 0.0 = black).
const double nightOpacity = 0.45;

class WallPanelScreen extends StatefulWidget {
  const WallPanelScreen({super.key});

  @override
  State<WallPanelScreen> createState() => _WallPanelScreenState();
}

class _WallPanelScreenState extends State<WallPanelScreen> {
  late Timer _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable(); // keep the screen on
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky); // hide status/navigation bars
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => setState(() => _now = DateTime.now()));
  }

  @override
  void dispose() {
    _timer.cancel();
    WakelockPlus.disable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  bool get _isNight => _now.hour >= nightStartHour || _now.hour < nightEndHour;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final dim = app.settings.nightDim && _isNight;

    return Scaffold(
      backgroundColor: HS.bg,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onLongPress: () => Navigator.pop(context),
        child: AnimatedOpacity(
          duration: const Duration(seconds: 2),
          opacity: dim ? nightOpacity : 1,
          child: SafeArea(
            child: OrientationBuilder(
              builder: (context, orientation) =>
                  orientation == Orientation.landscape ? _landscape(app) : _portrait(app),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  //  Layouts
  // ---------------------------------------------------------------------------

  Widget _portrait(AppState app) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _brandRow(),
          const SizedBox(height: 28),
          _clock(center: true, size: 88),
          const SizedBox(height: 28),
          Expanded(child: _tiles(app, columns: 2)),
          const SizedBox(height: 14),
          _scenes(app),
          const SizedBox(height: 10),
          const Center(child: Caps('Long-press to exit', size: 9, color: HS.faint, spacing: 0.12)),
        ]),
      );

  Widget _landscape(AppState app) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(
            width: 290,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _brandRow(),
              const Spacer(),
              _clock(center: false, size: 80),
              const Spacer(),
              const Caps('Long-press to exit', size: 9, color: HS.faint, spacing: 0.12),
            ]),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(children: [
              Expanded(child: _tiles(app, columns: app.devices.length > 4 ? 3 : 2)),
              const SizedBox(height: 12),
              _scenes(app),
            ]),
          ),
        ]),
      );

  // ---------------------------------------------------------------------------
  //  Pieces
  // ---------------------------------------------------------------------------

  Widget _brandRow() => const Row(children: [
        HomeskyLogo(size: 28, background: HS.bg),
        SizedBox(width: 12),
        Caps('Homesky', size: 13, weight: FontWeight.w800, spacing: 0.16),
        Spacer(),
        NetworkDot(),
      ]);

  Widget _clock({required bool center, required double size}) {
    final app = AppScope.of(context);
    final watts = app.energyDevices.isEmpty ? '' : ' · ${app.wattsNow.round()} W now';
    return Column(
      crossAxisAlignment: center ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        FittedBox(child: Caps(formatTime(_now), size: size, weight: FontWeight.w800, spacing: 0.02, height: 1)),
        const SizedBox(height: 10),
        Caps(formatDate(_now), size: 14, color: HS.muted, spacing: 0.16),
        const SizedBox(height: 8),
        Caps('${app.onCount} of ${app.devices.length} on$watts', size: 10, color: HS.muted),
      ],
    );
  }

  Widget _tiles(AppState app, {required int columns}) {
    if (app.devices.isEmpty) {
      return const Center(child: Caps('No devices yet', size: 14, color: HS.muted));
    }
    return LayoutBuilder(builder: (context, box) {
      final rows = (app.devices.length / columns).ceil();
      // Fill the available space; scroll if there are many devices.
      final tileHeight = ((box.maxHeight - (rows - 1) * 12) / rows).clamp(110.0, 220.0);
      return GridView.count(
        crossAxisCount: columns,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: (box.maxWidth / columns) / tileHeight,
        children: [for (final d in app.devices) _tile(app, d)],
      );
    });
  }

  Widget _tile(AppState app, Device device) {
    final accent = accentOf(context);
    final s = app.stateOf(device);
    final on = app.hasNetwork && s.reachable && s.on;
    final offline = !s.waiting && !s.reachable;
    final fg = on ? HS.onAccent(accent) : (offline ? HS.faint : HS.text);
    final detail = offline
        ? 'Not responding'
        : (device.isLight && on)
            ? '${s.brightness}%'
            : (s.hasEnergy && on && s.watts != null)
                ? '${s.watts!.round()} W'
                : device.type.label;

    return Semantics(
      button: true,
      toggled: on,
      label: '${device.name}, ${on ? 'on' : 'off'}',
      excludeSemantics: true,
      child: Material(
        color: on ? accent : HS.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: on ? accent : (offline ? HS.red : HS.track)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: offline ? () => app.refreshDevice(device) : () => app.toggle(device),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Caps(on ? 'On' : 'Off', size: 24, weight: FontWeight.w800, color: fg, spacing: 0.04),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Caps(device.name, size: 13, color: fg, maxLines: 2),
                const SizedBox(height: 4),
                Caps(detail, size: 9, color: on ? fg : (offline ? HS.redText : HS.muted), maxLines: 1),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _scenes(AppState app) {
    Widget button(String label, VoidCallback onTap, {bool special = false}) => Expanded(
          child: Tap(
            onTap: onTap,
            color: HS.surface,
            borderColor: special ? HS.pink : HS.borderStrong,
            radius: 14,
            minHeight: 60,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Center(child: Caps(label, size: 11, color: special ? HS.cyan : HS.text, maxLines: 1)),
          ),
        );
    final scenes = app.scenes.take(2).toList();
    return Row(children: [
      button('All off', app.allOff),
      for (var i = 0; i < scenes.length; i++) ...[
        const SizedBox(width: 10),
        button(scenes[i].name, () => app.runScene(scenes[i]), special: i == 0),
      ],
    ]);
  }
}
