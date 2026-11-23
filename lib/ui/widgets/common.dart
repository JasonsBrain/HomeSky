// =============================================================================
//  common.dart – small building blocks used on many screens:
//  panels, labels, buttons, switches, sliders and warning banners.
// =============================================================================

import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../theme.dart';

/// The current main colour, from settings.
Color accentOf(BuildContext context) => Color(AppScope.of(context).settings.accent);

/// A rounded dark box that groups related controls.
class Panel extends StatelessWidget {
  const Panel({super.key, required this.children, this.gap = 14, this.padding = 16});
  final List<Widget> children;
  final double gap;
  final double padding;

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(
          color: HS.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: HS.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: _withGaps(children, gap),
        ),
      );
}

/// Inserts vertical space between widgets.
List<Widget> _withGaps(List<Widget> items, double gap) => [
      for (var i = 0; i < items.length; i++) ...[if (i > 0) SizedBox(height: gap), items[i]],
    ];

/// Column with even gaps between children.
class Gapped extends StatelessWidget {
  const Gapped({super.key, required this.children, this.gap = 14});
  final List<Widget> children;
  final double gap;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: _withGaps(children, gap),
      );
}

/// Small grey heading, e.g. "BRIGHTNESS".
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(child: Caps(text, size: 11, color: HS.muted, spacing: 0.14)),
          if (trailing != null) trailing!,
        ],
      );
}

/// A tappable rounded box. Base for most buttons below.
class Tap extends StatelessWidget {
  const Tap({
    super.key,
    required this.child,
    required this.onTap,
    this.onLongPress,
    this.color = HS.header,
    this.borderColor = HS.borderStrong,
    this.radius = 12,
    this.minHeight = 48,
    this.padding = const EdgeInsets.symmetric(horizontal: 14),
    this.dashed = false,
    this.semanticLabel,
    this.selected,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color color;
  final Color borderColor;
  final double radius;
  final double minHeight;
  final EdgeInsets padding;
  final bool dashed; // drawn as a thinner, fainter border (Flutter has no dashed borders built in)
  final String? semanticLabel;
  final bool? selected;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: BorderSide(color: borderColor, width: dashed ? 1 : 1.2),
    );
    return Semantics(
      button: true,
      label: semanticLabel,
      selected: selected,
      child: Material(
        color: color,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}

/// Filled button in the main colour (Save, Add device...).
class PrimaryButton extends StatelessWidget {
  const PrimaryButton(this.label, {super.key, required this.onTap});
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final accent = accentOf(context);
    return Tap(
      onTap: onTap,
      color: onTap == null ? HS.track : accent,
      borderColor: onTap == null ? HS.track : accent,
      radius: 14,
      minHeight: 56,
      child: Center(child: Caps(label, size: 13, color: onTap == null ? HS.faint : HS.onAccent(accent), spacing: 0.14)),
    );
  }
}

/// Pink outline + cyan text: the "special" button style (All options, Movie...).
class SpecialButton extends StatelessWidget {
  const SpecialButton(this.label, {super.key, required this.onTap, this.icon, this.minHeight = 48});
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final double minHeight;

  @override
  Widget build(BuildContext context) => Tap(
        onTap: onTap,
        borderColor: HS.pink,
        color: Colors.transparent,
        minHeight: minHeight,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Caps(label, size: 11, color: HS.cyan, spacing: 0.1, maxLines: 1),
            if (icon != null) ...[const SizedBox(width: 6), Icon(icon, size: 18, color: HS.cyan)],
          ],
        ),
      );
}

/// Plain outline button (secondary actions).
class GhostButton extends StatelessWidget {
  const GhostButton(this.label, {super.key, required this.onTap, this.icon, this.color = HS.muted});
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Tap(
        onTap: onTap,
        color: Colors.transparent,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[Icon(icon, size: 18, color: color), const SizedBox(width: 6)],
            Caps(label, size: 11, color: color, spacing: 0.1, maxLines: 1),
          ],
        ),
      );
}

/// Red outline button. Only for deleting things.
class DangerButton extends StatelessWidget {
  const DangerButton(this.label, {super.key, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tap(
        onTap: onTap,
        color: Colors.transparent,
        borderColor: HS.red,
        radius: 14,
        minHeight: 52,
        child: Center(child: Caps(label, size: 12, color: HS.redText, spacing: 0.12)),
      );
}

/// The pill-shaped on/off switch graphic.
class PillSwitch extends StatelessWidget {
  const PillSwitch({super.key, required this.on, this.width = 60, this.height = 32});
  final bool on;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final accent = accentOf(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: width,
      height: height,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: on ? accent : HS.borderStrong, borderRadius: BorderRadius.circular(height)),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 160),
        alignment: on ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: height - 8,
          height: height - 8,
          decoration: BoxDecoration(color: on ? HS.onAccent(accent) : HS.text, shape: BoxShape.circle),
        ),
      ),
    );
  }
}

/// A full-width row with a title, optional description and a switch.
class ToggleRow extends StatelessWidget {
  const ToggleRow({super.key, required this.title, this.subtitle, required this.value, required this.onChanged});
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Semantics(
        toggled: value,
        child: Tap(
          onTap: () => onChanged(!value),
          minHeight: 64,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Caps(title, size: 12),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Caps(subtitle!, size: 10, color: HS.muted, caps: false, weight: FontWeight.w400, height: 1.5),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              PillSwitch(on: value, width: 56, height: 30),
            ],
          ),
        ),
      );
}

/// Labelled slider with the value shown on the right.
/// [onChanged] fires while dragging (update the screen only);
/// [onChangeEnd] fires on release (send to the device).
class LabeledSlider extends StatelessWidget {
  const LabeledSlider({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    required this.onChangeEnd,
    this.min = 1,
    this.max = 100,
    this.unit = '%',
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final String unit;
  final ValueChanged<int> onChanged;
  final ValueChanged<int> onChangeEnd;

  @override
  Widget build(BuildContext context) {
    final accent = accentOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          Expanded(child: Caps(label, size: 11, color: HS.muted, spacing: 0.12)),
          Caps('$value$unit', size: 11),
        ]),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 12,
            activeTrackColor: accent,
            inactiveTrackColor: HS.track,
            thumbColor: HS.text,
            overlayColor: accent.withValues(alpha: 0.15),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 13),
            trackShape: const RoundedRectSliderTrackShape(),
            showValueIndicator: ShowValueIndicator.never,
          ),
          child: Slider(
            value: value.clamp(min, max).toDouble(),
            min: min.toDouble(),
            max: max.toDouble(),
            label: '$value$unit',
            semanticFormatterCallback: (v) => '$label ${v.round()}$unit',
            onChanged: (v) => onChanged(v.round()),
            onChangeEnd: (v) => onChangeEnd(v.round()),
          ),
        ),
      ],
    );
  }
}

/// Red warning box (device not responding, no Wi-Fi...).
class WarningBanner extends StatelessWidget {
  const WarningBanner({super.key, required this.title, required this.body, this.icon = Icons.warning_amber_rounded});
  final String title;
  final String body;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Semantics(
        liveRegion: true,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: HS.redBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: HS.red),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: HS.redText, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Caps(title, size: 12, color: HS.redText),
                    const SizedBox(height: 4),
                    Caps(body, size: 10, color: HS.redBody, caps: false, weight: FontWeight.w400, height: 1.5),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

/// Asks "are you sure?" before deleting. Returns true if confirmed.
Future<bool> confirmDelete(BuildContext context, {required String title, required String body}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.warning_amber_rounded, color: HS.redText),
      title: Caps(title, size: 14, color: HS.redText, align: TextAlign.center),
      content: Caps(body, size: 11, color: HS.redBody, caps: false, weight: FontWeight.w400, height: 1.5),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Caps('Cancel', size: 11)),
        TextButton(onPressed: () => Navigator.pop(context, true), child: const Caps('Delete', size: 11, color: HS.redText)),
      ],
    ),
  );
  return result ?? false;
}

/// Limits content width on big screens so phone-style pages don't stretch.
class MaxWidth extends StatelessWidget {
  const MaxWidth({super.key, required this.child, this.width = 640});
  final Widget child;
  final double width;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(constraints: BoxConstraints(maxWidth: width), child: child),
      );
}
