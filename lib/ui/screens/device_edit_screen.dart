// =============================================================================
//  device_edit_screen.dart – add a new device or edit/delete an existing one.
//
//  "Test connection" asks the device what it is, fills in its name and
//  whether it's a plug or a bulb. Only private home-network IP addresses are
//  accepted (see local_network.dart).
// =============================================================================

import 'package:flutter/material.dart';

import '../../models/device.dart';
import '../../services/local_network.dart';
import '../../services/tasmota.dart';
import '../../services/wled.dart';
import '../../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/top_bar.dart';

class DeviceEditScreen extends StatefulWidget {
  /// Pass [device] to edit it. Pass [prefill] (from the network scan) or
  /// nothing to add a new one.
  const DeviceEditScreen({super.key, this.device, this.prefill});
  final Device? device;
  final Device? prefill;

  @override
  State<DeviceEditScreen> createState() => _DeviceEditScreenState();
}

enum _TestStatus { idle, testing, ok, failed, needsPassword }

class _DeviceEditScreenState extends State<DeviceEditScreen> {
  late final TextEditingController _name;
  late final TextEditingController _ip;
  late final TextEditingController _password;
  late DeviceType _type;
  late DeviceKind _kind;
  _TestStatus _test = _TestStatus.idle;
  String _testMessage = '';

  bool get _isNew => widget.device == null;

  @override
  void initState() {
    super.initState();
    final d = widget.device ?? widget.prefill;
    _name = TextEditingController(text: d?.name ?? '');
    _ip = TextEditingController(text: d?.ip ?? '');
    _password = TextEditingController(text: d?.password ?? '');
    _type = d?.type ?? DeviceType.tasmota;
    _kind = d?.kind ?? DeviceKind.plug;
    // Saved devices and devices found by the scan have already answered once.
    _verified = d != null;
    _lastIp = _ip.text;
    // Changing the address means it needs testing again.
    _ip.addListener(_ipChanged);
  }

  /// True once a device has answered at the current address.
  bool _verified = false;
  String _lastIp = '';

  void _ipChanged() {
    if (_ip.text == _lastIp) return; // cursor moves also notify; ignore those
    _lastIp = _ip.text;
    setState(() {
      _verified = false;
      _test = _TestStatus.idle;
      _testMessage = '';
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _ip.dispose();
    _password.dispose();
    super.dispose();
  }

  bool get _ipValid => LocalNetwork.isPrivateIPv4(_ip.text.trim());

  /// Ask the device what it is.
  Future<void> _testConnection() async {
    if (!_ipValid) {
      setState(() {
        _test = _TestStatus.failed;
        _testMessage = 'Enter a home-network address like 192.168.1.21.';
      });
      return;
    }
    setState(() => _test = _TestStatus.testing);
    final ip = _ip.text.trim();
    try {
      if (_type == DeviceType.tasmota) {
        final info = await TasmotaClient.identify(ip, password: _password.text);
        _kind = info.kind;
        if (_name.text.trim().isEmpty) _name.text = info.name;
        _testMessage = 'Connected: Tasmota ${info.kind == DeviceKind.light ? 'bulb' : 'plug'}'
            '${info.hasEnergy ? ' with power meter' : ''}.';
      } else {
        final info = await WledClient.identify(ip);
        _kind = DeviceKind.strip;
        if (_name.text.trim().isEmpty) _name.text = info.name;
        _testMessage = 'Connected: WLED with ${info.ledCount} LEDs.';
      }
      _test = _TestStatus.ok;
      _verified = true;
    } on TasmotaPasswordException {
      _test = _TestStatus.needsPassword;
      _testMessage = 'This Tasmota device has a web password. Enter it below and test again.';
    } catch (e) {
      _test = _TestStatus.failed;
      _testMessage = '$e';
    }
    if (mounted) setState(() {});
  }

  Future<void> _save() async {
    // Saving an untested address is the most common cause of "not responding",
    // so ask first if the connection test hasn't passed.
    if (!_verified) {
      final saveAnyway = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Caps('Connection not confirmed', size: 14),
          content: const Caps(
            'Homesky hasn\'t reached a device at this address yet. Check the IP is the device\'s own address '
            '(not your router or DNS server), then tap TEST CONNECTION. Save anyway?',
            size: 11,
            color: HS.muted,
            caps: false,
            weight: FontWeight.w400,
            height: 1.5,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Caps('Go back', size: 11)),
            TextButton(onPressed: () => Navigator.pop(c, true), child: const Caps('Save anyway', size: 11)),
          ],
        ),
      );
      if (saveAnyway != true || !mounted) return;
    }
    final app = AppScope.read(context);
    final device = Device(
      id: widget.device?.id ?? AppState.newId(),
      name: _name.text.trim().isEmpty ? '${_type.label} ${_ip.text.trim()}' : _name.text.trim(),
      type: _type,
      kind: _type == DeviceType.wled ? DeviceKind.strip : _kind,
      ip: _ip.text.trim(),
      password: _type == DeviceType.tasmota ? _password.text : '',
      lastColor: widget.device?.lastColor,
    );
    await app.saveDevice(device);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final device = widget.device!;
    final ok = await confirmDelete(
      context,
      title: 'Delete ${device.name}?',
      body: 'It will be removed from the app and from any scenes. The device itself is not changed.',
    );
    if (!ok || !mounted) return;
    await AppScope.read(context).deleteDevice(device);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final accent = accentOf(context);

    Widget option(String title, String note, bool selected, VoidCallback? onTap) => Tap(
          onTap: onTap,
          selected: selected,
          color: selected ? accent : HS.header,
          borderColor: selected ? accent : HS.borderStrong,
          radius: 10,
          minHeight: 56,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
            Caps(title, size: 11, color: onTap == null ? HS.faint : (selected ? HS.onAccent(accent) : HS.text)),
            const SizedBox(height: 4),
            Caps(note, size: 8, color: selected ? HS.onAccent(accent) : HS.muted),
          ]),
        );

    final testColour = switch (_test) {
      _TestStatus.ok => HS.cyan,
      _TestStatus.failed || _TestStatus.needsPassword => HS.redText,
      _ => HS.faint,
    };

    return Scaffold(
      body: Column(children: [
        BackHeader(
          backLabel: 'Back',
          title: _isNew ? 'Add device' : 'Edit device',
          subtitle: widget.device?.name,
        ),
        Expanded(
          child: ListView(padding: const EdgeInsets.all(16), children: [
            MaxWidth(
              child: Gapped(children: [
                // ---- Type ----
                Panel(children: [
                  const SectionLabel('Type'),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 2.6,
                    children: [
                      option('Tasmota', 'Plugs, switches, bulbs', _type == DeviceType.tasmota,
                          () => setState(() => _type = DeviceType.tasmota)),
                      option('WLED', 'LED strips', _type == DeviceType.wled, () => setState(() => _type = DeviceType.wled)),
                      // Planned for later versions – shown so you know they're coming.
                      option('Tuya', 'Coming in v2', false, null),
                      option('Xiaomi', 'Coming in v3', false, null),
                    ],
                  ),
                  if (_type == DeviceType.tasmota) ...[
                    const SectionLabel('This device is a'),
                    Row(children: [
                      Expanded(child: option('Plug', 'On / off', _kind == DeviceKind.plug, () => setState(() => _kind = DeviceKind.plug))),
                      const SizedBox(width: 8),
                      Expanded(
                          child: option('Bulb', 'Brightness, colour', _kind == DeviceKind.light,
                              () => setState(() => _kind = DeviceKind.light))),
                    ]),
                  ],
                ]),

                // ---- Details ----
                Panel(children: [
                  TextField(
                    controller: _name,
                    style: HS.style(size: 13),
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Name', hintText: 'e.g. Desk lamp'),
                  ),
                  TextField(
                    controller: _ip,
                    style: HS.style(size: 13),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'IP address',
                      hintText: 'e.g. 192.168.1.21',
                      errorText: _ip.text.isNotEmpty && !_ipValid ? 'Must be a home-network address' : null,
                    ),
                  ),
                  if (_type == DeviceType.tasmota)
                    TextField(
                      controller: _password,
                      obscureText: true,
                      autocorrect: false,
                      enableSuggestions: false,
                      style: HS.style(size: 13),
                      decoration: const InputDecoration(
                        labelText: 'Tasmota web password (optional)',
                        hintText: 'Only if you set one in Tasmota',
                      ),
                    ),
                  SpecialButton(
                    _test == _TestStatus.testing ? 'Testing…' : (_test == _TestStatus.ok ? 'Connected' : 'Test connection'),
                    minHeight: 52,
                    onTap: _test == _TestStatus.testing ? null : _testConnection,
                  ),
                  if (_testMessage.isNotEmpty && _test != _TestStatus.testing)
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Container(width: 10, height: 10, decoration: BoxDecoration(color: testColour, shape: BoxShape.circle)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Caps(_testMessage, size: 10, color: HS.muted, caps: false, weight: FontWeight.w400, height: 1.5)),
                    ]),
                ]),

                PrimaryButton(_isNew ? 'Add device' : 'Save', onTap: _ipValid ? _save : null),
                if (!_isNew) DangerButton('Delete device', onTap: _delete),

                const Caps(
                  'Tip: give each device a fixed IP address in your router settings (often called "DHCP reservation"), '
                  'so Homesky can always find it.',
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
