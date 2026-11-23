// =============================================================================
//  theme.dart – colours, font and text style. Change the look of the whole
//  app here.
//
//  Palette: near-black background, muted BMW-M-style blues for the main
//  colour, Vice City pink + cyan for "special" buttons, red ONLY for warnings
//  and delete.
// =============================================================================

import 'package:flutter/material.dart';

class HS {
  HS._();

  // ---- Font ----
  // Michroma ships with the app (assets/fonts). It has one weight; bold text is
  // drawn thicker by Flutter automatically.
  static const String font = 'Michroma';

  // ---- Backgrounds ----
  static const Color bg = Color(0xFF050609); //       page background
  static const Color header = Color(0xFF090B11); //   top bar, inputs, inner boxes
  static const Color surface = Color(0xFF0D1019); //  panels and cards
  static const Color track = Color(0xFF1E2438); //    empty part of sliders

  // ---- Lines ----
  static const Color border = Color(0xFF1C2133);
  static const Color borderStrong = Color(0xFF252B40);

  // ---- Text ----
  static const Color text = Color(0xFFEEF1F8);
  static const Color muted = Color(0xFF9AA3BD); // labels, secondary text
  static const Color faint = Color(0xFF7D869F); // placeholders, disabled

  // ---- Accents ----
  static const Color mLight = Color(0xFF6E9FC9); // muted M light blue (default)
  static const Color mDark = Color(0xFF44528F); //  muted M dark blue
  static const Color cyan = Color(0xFF46C9D8);
  static const Color pink = Color(0xFFEE5F9C);
  static const Color purple = Color(0xFFB86BC4); // logo sunset only

  // ---- Warnings / delete (the only place red is used) ----
  static const Color red = Color(0xFFC4544D);
  static const Color redText = Color(0xFFE8807A);
  static const Color redBg = Color(0xFF1A0C0D);
  static const Color redBody = Color(0xFFC9B4B3);

  /// Choices for the main colour in Settings. Add a Color here to offer more.
  static const List<Color> accentOptions = [mLight, cyan, mDark];
  static const List<String> accentNames = ['M light blue', 'Cyan', 'M dark blue'];

  /// Black or white text on top of [accent], whichever is easier to read.
  static Color onAccent(Color accent) {
    final l = accent.computeLuminance();
    final contrastWithDark = (l + 0.05) / (bg.computeLuminance() + 0.05);
    final contrastWithWhite = 1.05 / (l + 0.05);
    return contrastWithDark >= contrastWithWhite ? bg : Colors.white;
  }

  /// Text style used everywhere. [spacing] is letter spacing as a fraction of size.
  static TextStyle style({
    double size = 12,
    Color color = text,
    FontWeight weight = FontWeight.w700,
    double spacing = 0.06,
    double height = 1.3,
  }) =>
      TextStyle(
        fontFamily: font,
        fontSize: size,
        color: color,
        fontWeight: weight,
        letterSpacing: size * spacing,
        height: height,
      );

  /// The Flutter theme (used by dialogs, text fields, scroll bars...).
  static ThemeData theme(Color accent) {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme.dark(
        primary: accent,
        onPrimary: onAccent(accent),
        secondary: pink,
        surface: surface,
        onSurface: text,
        error: red,
      ),
      textTheme: base.textTheme.apply(fontFamily: font, bodyColor: text, displayColor: text),
      dialogTheme: const DialogThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          side: BorderSide(color: borderStrong),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: header,
        hintStyle: style(size: 12, color: faint, weight: FontWeight.w400),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: borderStrong),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: borderStrong),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: accent, width: 1.5),
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(cursorColor: accent, selectionColor: accent.withValues(alpha: 0.35)),
    );
  }
}

/// Text in the Homesky style. ALL CAPS by default; pass caps: false for
/// sentences (help text, warnings).
class Caps extends StatelessWidget {
  const Caps(
    this.text, {
    super.key,
    this.size = 12,
    this.color = HS.text,
    this.weight = FontWeight.w700,
    this.spacing = 0.06,
    this.caps = true,
    this.maxLines,
    this.align,
    this.height = 1.3,
  });

  final String text;
  final double size;
  final Color color;
  final FontWeight weight;
  final double spacing;
  final bool caps;
  final int? maxLines;
  final TextAlign? align;
  final double height;

  @override
  Widget build(BuildContext context) => Text(
        caps ? text.toUpperCase() : text,
        maxLines: maxLines,
        overflow: maxLines == null ? null : TextOverflow.ellipsis,
        textAlign: align,
        style: HS.style(size: size, color: color, weight: weight, spacing: caps ? spacing : 0.01, height: height),
      );
}
