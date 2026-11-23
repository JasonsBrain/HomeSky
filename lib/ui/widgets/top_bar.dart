// =============================================================================
//  top_bar.dart – the header on every screen.
//    TopBar      – main tabs (Devices / Scenes / Settings), logo, clock.
//    BackHeader  – sub-pages: back button, page title, clock.
//    ClockText   – the live clock.
// =============================================================================

import 'dart:async';

import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../theme.dart';
import 'common.dart';
import 'logo.dart';

/// Shows the time as "21:37", updating on its own.
class ClockText extends StatefulWidget {
  const ClockText({super.key, this.size = 18, this.showDate = false});
  final double size;
  final bool showDate;

  @override
  State<ClockText> createState() => _ClockTextState();
}

class _ClockTextState extends State<ClockText> {
  late Timer _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Check every few seconds; cheap, and the minute flips on time.
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => setState(() => _now = DateTime.now()));
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      Caps(formatTime(_now), size: widget.size, weight: FontWeight.w800, spacing: 0.06);
}

String _two(int n) => n.toString().padLeft(2, '0');
String formatTime(DateTime t) => '${_two(t.hour)}:${_two(t.minute)}';

const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
String formatDate(DateTime t) => '${_days[t.weekday - 1]} ${t.day} ${_months[t.month - 1]}';

/// Small dot: cyan when on the home network, red when not.
class NetworkDot extends StatelessWidget {
  const NetworkDot({super.key});

  @override
  Widget build(BuildContext context) {
    final ok = AppScope.of(context).hasNetwork;
    return Semantics(
      label: ok ? 'Connected to home network' : 'No home network',
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: ok ? HS.cyan : HS.redText, shape: BoxShape.circle),
      ),
    );
  }
}

/// Header with the main tabs.
class TopBar extends StatelessWidget {
  const TopBar({super.key, required this.tabs, required this.current, required this.onTab, this.wide = false});
  final List<String> tabs;
  final int current;
  final ValueChanged<int> onTab;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final accent = accentOf(context);

    final brand = Row(mainAxisSize: MainAxisSize.min, children: [
      HomeskyLogo(size: wide ? 34 : 30),
      const SizedBox(width: 12),
      Caps('Homesky', size: wide ? 20 : 18, weight: FontWeight.w800, spacing: 0.14),
    ]);

    final status = Row(mainAxisSize: MainAxisSize.min, children: [
      const NetworkDot(),
      const SizedBox(width: 10),
      ClockText(size: wide ? 22 : 18),
    ]);

    final tabRow = Row(
      mainAxisSize: wide ? MainAxisSize.min : MainAxisSize.max,
      children: [
        for (var i = 0; i < tabs.length; i++)
          _tabButton(tabs[i], i == current, () => onTab(i), accent, expand: !wide),
      ],
    );

    return Container(
      decoration: const BoxDecoration(
        color: HS.header,
        border: Border(bottom: BorderSide(color: HS.border)),
      ),
      child: SafeArea(
        bottom: false,
        child: wide
            ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Row(children: [brand, const Spacer(), tabRow, const Spacer(), status]),
              )
            : Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: Column(children: [
                  Row(children: [brand, const Spacer(), status]),
                  const SizedBox(height: 10),
                  tabRow,
                ]),
              ),
      ),
    );
  }

  Widget _tabButton(String label, bool active, VoidCallback onTap, Color accent, {required bool expand}) {
    final button = Semantics(
      selected: active,
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 50),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: active ? accent : Colors.transparent, width: 3)),
          ),
          child: Caps(label, size: 12, color: active ? HS.text : HS.muted, weight: active ? FontWeight.w800 : FontWeight.w700, spacing: 0.1),
        ),
      ),
    );
    return expand ? Expanded(child: button) : button;
  }
}

/// Header for sub-pages: "< BACK", title, subtitle, clock.
class BackHeader extends StatelessWidget {
  const BackHeader({super.key, required this.backLabel, required this.title, this.subtitle});
  final String backLabel;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          color: HS.header,
          border: Border(bottom: BorderSide(color: HS.border)),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  InkWell(
                    onTap: () => Navigator.maybePop(context),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.chevron_left, color: HS.muted),
                        Caps(backLabel, size: 11, color: HS.muted, spacing: 0.1),
                        const SizedBox(width: 12),
                      ]),
                    ),
                  ),
                  const Spacer(),
                  const ClockText(size: 16),
                ]),
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Row(children: [
                    const HomeskyLogo(size: 30),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Caps(title, size: 18, weight: FontWeight.w800, spacing: 0.12, maxLines: 1),
                        if (subtitle != null) ...[
                          const SizedBox(height: 4),
                          Caps(subtitle!, size: 10, color: HS.muted, maxLines: 1),
                        ],
                      ]),
                    ),
                  ]),
                ),
              ],
            ),
          ),
        ),
      );
}
