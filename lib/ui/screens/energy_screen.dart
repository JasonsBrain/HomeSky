// =============================================================================
//  energy_screen.dart – power use and cost from Tasmota plugs with a meter.
//
//  "Now" and "Today" come straight from the plugs. Earlier days are saved by
//  Homesky each day (see _recordEnergy in app_state.dart), so the 7-day chart
//  and month total fill up over time while the app is running.
// =============================================================================

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/top_bar.dart';

class EnergyScreen extends StatefulWidget {
  const EnergyScreen({super.key});

  @override
  State<EnergyScreen> createState() => _EnergyScreenState();
}

class _EnergyScreenState extends State<EnergyScreen> {
  /// Chart shows pounds (true) or kWh (false).
  bool _showCost = true;

  static const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final accent = accentOf(context);
    final hasPrice = app.settings.pricePerKwh > 0;
    final showCost = _showCost && hasPrice;
    final plugs = app.energyDevices;

    // Last 7 days, oldest first.
    final today = DateTime.now();
    final days = [for (var i = 6; i >= 0; i--) today.subtract(Duration(days: i))];
    final dayKwh = [for (final d in days) app.kwhOn(d)];
    final maxKwh = dayKwh.fold<double>(0, math.max);

    String money(double kwh) => app.cost(kwh) ?? '–';

    Widget stat(String label, double kwh) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: HS.header,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: HS.border),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Caps(label, size: 9, color: HS.muted, spacing: 0.12),
              const SizedBox(height: 6),
              Caps(hasPrice ? money(kwh) : '${kwh.toStringAsFixed(2)} kWh', size: 18, weight: FontWeight.w800),
              if (hasPrice) ...[
                const SizedBox(height: 6),
                Caps('${kwh.toStringAsFixed(2)} kWh', size: 10, color: HS.muted),
              ],
            ]),
          ),
        );

    return Scaffold(
      body: Column(children: [
        const BackHeader(backLabel: 'Devices', title: 'Energy', subtitle: 'Tasmota plugs'),
        Expanded(
          child: ListView(padding: const EdgeInsets.all(16), children: [
            MaxWidth(
              child: Gapped(children: [
                if (plugs.isEmpty)
                  const WarningBanner(
                    icon: Icons.info_outline,
                    title: 'No power meters found',
                    body: 'Energy works with Tasmota plugs that measure power (they report an ENERGY reading).',
                  ),

                // ---- Right now ----
                Panel(children: [
                  const SectionLabel('Right now'),
                  Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Caps('${app.wattsNow.round()}', size: 40, weight: FontWeight.w800, spacing: 0.02, height: 1),
                    const SizedBox(width: 10),
                    const Caps('W', size: 16, color: HS.muted),
                  ]),
                  if (hasPrice)
                    Caps('About ${money(app.wattsNow / 1000)} per hour at this rate', size: 10, color: HS.muted),
                ]),

                // ---- Today / this month ----
                Row(children: [
                  stat('Today', app.kwhToday),
                  const SizedBox(width: 10),
                  stat('This month', app.kwhThisMonth),
                ]),

                // ---- Last 7 days chart ----
                Panel(children: [
                  SectionLabel('Last 7 days',
                      trailing: hasPrice
                          ? Row(mainAxisSize: MainAxisSize.min, children: [
                              _unitButton('£', showCost, accent, () => setState(() => _showCost = true)),
                              const SizedBox(width: 6),
                              _unitButton('kWh', !showCost, accent, () => setState(() => _showCost = false)),
                            ])
                          : null),
                  Semantics(
                    label: 'Energy use for the last 7 days',
                    child: SizedBox(
                      height: 160,
                      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        for (var i = 0; i < 7; i++) ...[
                          if (i > 0) const SizedBox(width: 8),
                          Expanded(
                            child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                              Caps(
                                showCost
                                    ? '${(dayKwh[i] * app.settings.pricePerKwh).round()}p'
                                    : dayKwh[i].toStringAsFixed(1),
                                size: 7,
                                color: HS.muted,
                                spacing: 0,
                              ),
                              const SizedBox(height: 6),
                              Container(
                                // Bars are scaled to the biggest day (min 2 px so empty days still show).
                                height: maxKwh == 0 ? 2 : math.max(2, dayKwh[i] / maxKwh * 100),
                                decoration: BoxDecoration(
                                  color: i == 6 ? accent : HS.mDark,
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4), bottom: Radius.circular(2)),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Caps(_dayNames[days[i].weekday - 1], size: 8, color: HS.muted, spacing: 0),
                            ]),
                          ),
                        ],
                      ]),
                    ),
                  ),
                ]),

                // ---- Per plug ----
                if (plugs.isNotEmpty)
                  Panel(children: [
                    const SectionLabel('By device · today'),
                    for (final d in plugs) _plugRow(app, d.name, app.stateOf(d).watts ?? 0, app.stateOf(d).todayKwh ?? 0, accent),
                  ]),

                // ---- Price ----
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: HS.borderStrong)),
                  child: Caps(
                    hasPrice
                        ? 'Price: ${app.settings.pricePerKwh}p per kWh. Change it in Settings → Energy.'
                        : 'Set your price per kWh in Settings → Energy to see costs.',
                    size: 10,
                    color: HS.muted,
                    caps: false,
                    weight: FontWeight.w400,
                    height: 1.5,
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _plugRow(AppState app, String name, double watts, double kwh, Color accent) {
    final total = app.kwhToday;
    final share = total <= 0 ? 0.0 : (kwh / total).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: HS.header, borderRadius: BorderRadius.circular(12), border: Border.all(color: HS.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Caps(name, size: 12, maxLines: 1)),
          Caps(app.cost(kwh) ?? '${kwh.toStringAsFixed(2)} kWh', size: 12),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: Caps('Now ${watts.round()} W', size: 9, color: HS.muted)),
          Caps('${kwh.toStringAsFixed(2)} kWh', size: 9, color: HS.muted),
        ]),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(value: share, minHeight: 6, color: accent, backgroundColor: HS.track),
        ),
      ]),
    );
  }

  Widget _unitButton(String label, bool active, Color accent, VoidCallback onTap) => Tap(
        onTap: onTap,
        selected: active,
        color: Colors.transparent,
        borderColor: active ? accent : HS.borderStrong,
        radius: 8,
        minHeight: 36,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Column(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
          Caps(label, size: 10, caps: false),
        ]),
      );
}
