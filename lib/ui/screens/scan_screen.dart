// =============================================================================
//  scan_screen.dart – searches the home network for Tasmota and WLED devices
//  and lets you add them with one tap. See services/scanner.dart.
// =============================================================================

import 'package:flutter/material.dart';

import '../../models/device.dart';
import '../../services/scanner.dart';
import '../../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/device_widgets.dart';
import '../widgets/top_bar.dart';
import 'device_edit_screen.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final List<FoundDevice> _found = [];
  double _progress = 0;
  bool _running = false;
  bool _noNetwork = false;
  bool _cancelled = false;

  @override
  void initState() {
    super.initState();
    // Start scanning as soon as the page is on screen.
    WidgetsBinding.instance.addPostFrameCallback((_) => _scan());
  }

  @override
  void dispose() {
    _cancelled = true; // Stop scanning when leaving the page.
    super.dispose();
  }

  Future<void> _scan() async {
    setState(() {
      _found.clear();
      _progress = 0;
      _running = true;
      _noNetwork = false;
    });
    final ok = await NetworkScanner.scan(
      onProgress: (p) {
        if (mounted) setState(() => _progress = p);
      },
      onFound: (d) {
        if (mounted) setState(() => _found.add(d));
      },
      isCancelled: () => _cancelled,
    );
    if (!mounted) return;
    setState(() {
      _running = false;
      _noNetwork = !ok;
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final known = app.devices.map((d) => d.ip).toSet();

    return Scaffold(
      body: Column(children: [
        const BackHeader(backLabel: 'Settings', title: 'Scan network', subtitle: 'Tasmota and WLED'),
        Expanded(
          child: ListView(padding: const EdgeInsets.all(16), children: [
            MaxWidth(
              child: Gapped(children: [
                if (_noNetwork)
                  const WarningBanner(
                    icon: Icons.wifi_off,
                    title: 'No home network',
                    body: 'Connect this device to your Wi-Fi and try again.',
                  )
                else
                  Panel(children: [
                    SectionLabel(_running ? 'Searching…' : 'Done', trailing: Caps('${_found.length} found', size: 10, color: HS.muted)),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(value: _progress, minHeight: 6, color: accentOf(context), backgroundColor: HS.track),
                    ),
                  ]),
                for (final f in _found)
                  Tap(
                    onTap: known.contains(f.ip)
                        ? null
                        : () => Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => DeviceEditScreen(
                                  prefill: Device(id: '', name: f.name, type: f.type, kind: f.kind, ip: f.ip),
                                ),
                              ),
                            ),
                    minHeight: 60,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(children: [
                      Icon(iconFor(f.kind), color: HS.muted, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Caps(f.name, size: 12, maxLines: 1),
                          const SizedBox(height: 4),
                          Caps(
                            '${f.type.label} · ${f.ip}${f.needsPassword ? ' · needs password' : ''}',
                            size: 9,
                            color: HS.muted,
                            maxLines: 1,
                          ),
                        ]),
                      ),
                      Caps(known.contains(f.ip) ? 'Added' : '+ Add', size: 10, color: known.contains(f.ip) ? HS.faint : HS.cyan),
                    ]),
                  ),
                if (!_running)
                  GhostButton('Scan again', icon: Icons.refresh, onTap: _scan),
                const Caps(
                  "Not found? Make sure it's powered on and on the same Wi-Fi, or add it by IP address.",
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
}
