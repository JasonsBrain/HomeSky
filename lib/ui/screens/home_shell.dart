// =============================================================================
//  home_shell.dart – the main frame: top bar with tabs + the current tab.
//  On wide windows (Windows app, tablets) the top bar becomes one wide row.
// =============================================================================

import 'package:flutter/material.dart';

import '../widgets/top_bar.dart';
import 'devices_tab.dart';
import 'scenes_tab.dart';
import 'settings_tab.dart';

/// Width (in logical pixels) from which the wide layout is used.
const double wideBreakpoint = 900;

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  static const _tabs = ['Devices', 'Scenes', 'Settings'];

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= wideBreakpoint;
    return Scaffold(
      body: Column(children: [
        TopBar(tabs: _tabs, current: _tab, onTab: (i) => setState(() => _tab = i), wide: wide),
        Expanded(
          // IndexedStack keeps each tab's scroll position when switching.
          child: IndexedStack(
            index: _tab,
            children: [
              DevicesTab(wide: wide, onOpenSettings: () => setState(() => _tab = 2)),
              const ScenesTab(),
              const SettingsTab(),
            ],
          ),
        ),
      ]),
    );
  }
}
