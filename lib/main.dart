// =============================================================================
//  HOMESKY – local-only smart home control.
//
//  Your home. Your sky. No cloud.
//
//  Map of the code (start here):
//
//    lib/main.dart                  ← you are here: starts the app
//    lib/models/                    what a device, scene and the settings are
//    lib/services/local_network.dart  THE privacy gate: blocks any non-home address
//    lib/services/tasmota.dart      talks to Tasmota plugs/bulbs
//    lib/services/wled.dart         talks to WLED LED strips
//    lib/services/scanner.dart      finds devices on your Wi-Fi
//    lib/services/storage.dart      saves data on this device only
//    lib/state/app_state.dart       the brain: device status, actions, energy
//    lib/ui/theme.dart              colours and font
//    lib/ui/widgets/                reusable pieces (buttons, cards, logo...)
//    lib/ui/screens/                one file per screen
//
//  Privacy in one paragraph: there are no accounts, analytics, ads, crash
//  reporters or cloud services in this app. Every network request goes
//  through local_network.dart, which refuses anything that isn't a private
//  home-network IP address. Data is stored only on the device and excluded
//  from cloud backups.
// =============================================================================

import 'package:flutter/material.dart';

import 'services/storage.dart';
import 'state/app_state.dart';
import 'ui/screens/home_shell.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load saved devices/scenes/settings, then start checking devices.
  final storage = await Storage.open();
  final state = AppState(storage);
  await state.load();

  runApp(HomeskyApp(state: state));
}

// Themes are cached per main colour, so the many status updates don't rebuild
// the theme each time.
final Map<int, ThemeData> _themes = {};
ThemeData _themeFor(int accent) => _themes.putIfAbsent(accent, () => HS.theme(Color(accent)));

class HomeskyApp extends StatelessWidget {
  const HomeskyApp({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      // ListenableBuilder rebuilds the theme when the main colour changes.
      child: ListenableBuilder(
        listenable: state,
        builder: (context, _) => MaterialApp(
          title: 'Homesky',
          debugShowCheckedModeBanner: false,
          theme: _themeFor(state.settings.accent),
          home: const HomeShell(),
        ),
      ),
    );
  }
}
