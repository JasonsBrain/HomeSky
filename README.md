# Homesky

**Your home. Your sky. No cloud.**

Homesky controls Tasmota plugs/bulbs and WLED LED strips from one app, on Android and Windows. Everything stays on your home network.

## What it does (version 1)

- **Devices:** tap a tile to switch it on or off. Lights get power, brightness and white / yellow / last-colour buttons.
- **WLED all options:** custom colour, every effect on your strip (with search), speed and intensity, palettes and presets.
- **Energy:** live watts, today and this month in kWh and £ from Tasmota plugs with a power meter, plus a 7-day chart.
- **Scenes:** set several devices at once ("Movie", "Night"...).
- **Scan network:** finds Tasmota and WLED devices on your Wi-Fi automatically.
- **Status warnings** for devices that aren't responding and for lost Wi-Fi.
- **Wall panel mode:** a big clock and big buttons, upright or sideways, with the screen kept on and night dimming.
- **Wide layout** for Windows and tablets.

Coming later: Tuya bulbs (v2) and Xiaomi plugs (v3).

## Privacy

| What | How |
|---|---|
| No cloud, accounts or tracking | There are no analytics, ads or crash reporters, and no servers. |
| Local network only | Every request goes through `lib/services/local_network.dart`, which refuses anything that isn't a private home IP (10.x, 172.16–31.x, 192.168.x, 169.254.x). Domain names are refused too. |
| No sneaky redirects or proxies | Redirects are never followed and system proxies are ignored. |
| Data stays on the device | Devices, scenes, settings and energy history are saved in the app's private storage only. |
| No cloud backups | Android backup and phone-to-phone transfer are switched off for the app (`tool/patch_android.py`). |
| Minimal permissions | Android: only `INTERNET`, which Android needs even for the local network. |
| Minimal dependencies | Just `shared_preferences` (storage) and `wakelock_plus` (keeps the wall panel awake). The font is bundled, so nothing is downloaded at runtime. |

One honest limit: Tasmota and WLED only speak plain HTTP, so commands on your Wi-Fi are not encrypted. That's how those devices work. If you set a Tasmota web password, it's sent with each command, but only to the device's home IP.

## Getting the app (no PC tools needed)

1. Create an empty repository on GitHub called `homesky`. Private is fine.
2. Upload **everything in this folder**, including the hidden `.github` folder. In the GitHub web page: *Add file → Upload files*, then drag the contents in.
3. Open the **Actions** tab. A build starts automatically and takes about 5–10 minutes.
4. When it's green, open the run and scroll to **Artifacts**:
   - `homesky-android`: unzip it and install `app-release.apk` on your phone. Allow "install unknown apps" for your browser or file manager when asked.
   - `homesky-windows`: unzip it anywhere and run `homesky.exe`. Windows SmartScreen may warn about an unknown publisher; choose *More info → Run anyway*.

If a build fails, open the red step, copy the error and paste it to Claude.

## Setting up your devices

- **Fixed IPs:** in your router, give each plug, bulb and strip a fixed address (often called "DHCP reservation"). Then Homesky always finds them.
- **Tasmota energy:** plugs with a power meter show watts automatically.
- **Price:** enter your price per kWh (in pence) in Settings → Energy to see costs.
- **Passwords:** recommended. Set a Tasmota web password (Configuration → Other) and type it in Homesky when adding the device.

## Changing things

Every file starts with a comment explaining what it does. Good places to start:

| I want to... | Look in |
|---|---|
| Change colours or the font | `lib/ui/theme.dart` |
| Change how often devices are checked | `pollEvery` in `lib/state/app_state.dart` |
| Change the white / yellow colours | `white` / `yellow` in `lib/state/app_state.dart` |
| Change the night-dim hours | top of `lib/ui/screens/wall_panel_screen.dart` |
| Change the device timeout | `defaultTimeout` in `lib/services/local_network.dart` |
| Add a new device type | `lib/models/device.dart` + a new client in `lib/services/` |

Run the privacy tests with `flutter test`.

## Licence notes

The Michroma font is © its authors, under the SIL Open Font Licence (`assets/fonts/OFL.txt`).
