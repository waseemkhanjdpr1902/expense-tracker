import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Corner-radius scale — hero cards roundest, chips tightest. One scale so
/// roundness reads as intentional across the app.
class AppRadii {
  static const double hero = 28;
  static const double card = 20;
  static const double inner = 14;
  static const double chip = 12;
  static const double pill = 100;
}

/// 8pt spacing scale. Use these instead of ad-hoc gaps so vertical rhythm is
/// consistent everywhere.
class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
}

/// Tabular figures — makes digits equal-width so animated money doesn't jitter
/// and columns of numbers align. Applied to every text style below.
const List<FontFeature> _kTabular = [FontFeature.tabularFigures()];

// ═══════════════════════════════════════════════════════════════════════════
//  BRAND — the only hand-picked hexes in the app.
// ═══════════════════════════════════════════════════════════════════════════

class AppBrand {
  /// The lime. Every accent in both themes is derived from this one value.
  static const green = Color(0xFFA4F133);

  /// Destructive red. Deliberately darker than the old `#E53935`: white text on
  /// that scored 4.23:1, below the 4.5 AA threshold. This scores 4.80:1 and is
  /// visually near-identical.
  static const danger = Color(0xFFDF211D);
}

// ═══════════════════════════════════════════════════════════════════════════
//  THE DIAL
//
//  The entire dark theme is derived from this block. To re-tune dark mode,
//  edit here and nowhere else — every surface, label, separator and accent
//  in the app follows automatically.
// ═══════════════════════════════════════════════════════════════════════════

class DarkTuning {
  /// The one line. Everything else is computed relative to it.
  /// `#1C1C1E` is iOS `secondarySystemBackground` — Apple's elevated base.
  static const Color base = Color(0xFF1C1C1E);

  /// Elevation ramp: how far each level is lerped toward white.
  /// These stops reproduce Apple's #2C2C2E / #3A3A3C / #48484A exactly.
  static const List<double> ramp = [0.0, 0.0705, 0.132, 0.194];

  /// The "white". NOT pure #FFFFFF — that against [base] is 19.7:1, which is
  /// what makes a dark theme hurt to look at for any length of time.
  static const Color labelBase = Color(0xFFEBEBF5);
  static const double lSecondary = 0.60;
  static const double lTertiary = 0.30;
  static const double lQuaternary = 0.18;

  /// Placeholder/hint text. Deliberately above Apple's tertiary (0.30): this
  /// app routes real hint text through it, and 0.30 would be 2.48:1.
  static const double lPlaceholder = 0.45;

  static const Color separatorBase = Color(0xFF545458);
  static const double separatorAlpha = 0.60;
  static const Color opaqueSeparator = Color(0xFF38383A);

  /// Accent adaptation. A fully saturated lime on a dark ground glares;
  /// iOS desaturates system colours in dark mode for the same reason.
  static const double accentSatFactor = 0.70;
  static const double accentLightDelta = -0.05;

  /// Strength of the soft accent wash, blended opaque (see [AppPalette]).
  static const double accentSoftMix = 0.11;

  /// The mascot is a large SOLID shape. At full label brightness it becomes the
  /// single brightest area on the screen, which reads as a glowing blob rather
  /// than a character. Text can be bright because it is thin; fills cannot.
  static const double mascotAlpha = 0.62;

  /// Danger as *content* (red text/icons) needs lifting to stay legible on a
  /// dark ground; danger as a *fill* stays at brand strength.
  static const double dangerContentLightDelta = 0.22;

  static const double scrimAlpha = 0.62;
  static const Color shadow = Color(0x66000000);
}

class LightTuning {
  static const Color base = Color(0xFFFFFFFF);

  /// Flat: in light mode cards are the same white as the page, distinguished
  /// by hairline and shadow rather than by tone. `ramp[1] == 0` is what
  /// guarantees light mode does not move.
  static const List<double> ramp = [0.0, 0.0, 0.0, 0.02];

  static const Color labelBase = Color(0xFF000000);
  static const double lSecondary = 0.60;
  static const double lTertiary = 0.30;
  static const double lQuaternary = 0.24;
  static const double lPlaceholder = 0.38;

  static const Color separatorBase = Color(0xFF000000);
  static const double separatorAlpha = 0.08;
  static const Color opaqueSeparator = Color(0xFFE5E5EA);

  /// Light mode keeps the brand exactly.
  static const double accentSatFactor = 1.0;
  static const double accentLightDelta = 0.0;
  static const double accentSoftMix = 0.12;
  static const double dangerContentLightDelta = 0.0;

  /// Light mode: the cat is a black silhouette, which reads correctly as-is.
  static const double mascotAlpha = 1.0;

  static const double scrimAlpha = 0.38;
  static const Color shadow = Color(0x0D000000);
}

// ═══════════════════════════════════════════════════════════════════════════
//  PALETTE
// ═══════════════════════════════════════════════════════════════════════════

/// Every colour in the app, derived from [DarkTuning] / [LightTuning].
///
/// A [ThemeExtension] rather than a plain class so the whole palette gets
/// `lerp()` — without it the custom colours snap at the midpoint of a
/// light/dark switch while Material's own colours cross-fade.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.brightness,
    required this.bgBase,
    required this.bgCard,
    required this.bgRaised,
    required this.bgOverlay,
    required this.label,
    required this.labelSecondary,
    required this.labelTertiary,
    required this.labelQuaternary,
    required this.placeholder,
    required this.separator,
    required this.opaqueSeparator,
    required this.fill,
    required this.fillSecondary,
    required this.accent,
    required this.onAccent,
    required this.accentSoft,
    required this.onAccentSoft,
    required this.danger,
    required this.onDanger,
    required this.dangerContent,
    required this.barFill,
    required this.barBorder,
    required this.scrim,
    required this.heroSurface,
    required this.onHero,
    required this.mascotBody,
    required this.shadow,
  });

  final Brightness brightness;

  /// Elevation ramp: page → card → raised (nav bar, chips on cards) → overlay
  /// (menus, tooltips).
  final Color bgBase, bgCard, bgRaised, bgOverlay;

  /// Text hierarchy, mirroring iOS label / secondaryLabel / tertiaryLabel /
  /// quaternaryLabel, plus placeholder for hint text.
  final Color label, labelSecondary, labelTertiary, labelQuaternary, placeholder;

  final Color separator, opaqueSeparator;

  /// Neutral fills for selected/inactive chrome (segments, chips).
  final Color fill, fillSecondary;

  /// [accentSoft] is OPAQUE. It used to be `green @12%`, whose appearance
  /// depended entirely on whatever sat behind it — the direct cause of several
  /// unreadable-text bugs in dark mode.
  final Color accent, onAccent, accentSoft, onAccentSoft;

  /// [danger] is the fill (white text on it); [dangerContent] is the red used
  /// for text and icons directly on a surface.
  final Color danger, onDanger, dangerContent;

  final Color barFill, barBorder, scrim;

  /// The inverted hero card on Home (and the About repo card).
  final Color heroSurface, onHero;

  /// Fill for the pixel-cat mascot — dimmer than [label] because it is a large
  /// solid area rather than thin glyphs.
  final Color mascotBody;

  final Color shadow;

  bool get isDark => brightness == Brightness.dark;

  List<BoxShadow> get softShadow =>
      [BoxShadow(color: shadow, blurRadius: 24, offset: const Offset(0, 8))];

  /// Status/navigation bar styling for this palette.
  SystemUiOverlayStyle get overlayStyle => SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness:
            isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarContrastEnforced: false,
      );

  /// The soft accent wash blended over an arbitrary background, for the few
  /// places that don't sit on [bgCard] (the hero card, the blurred nav bar).
  Color accentSoftOn(Color background) => Color.alphaBlend(
        accent.withValues(
            alpha: isDark ? DarkTuning.accentSoftMix : LightTuning.accentSoftMix),
        background,
      );

  // ── The single derivation both themes run through ────────────────────────
  factory AppPalette.of(Brightness b) {
    final dark = b == Brightness.dark;

    final base = dark ? DarkTuning.base : LightTuning.base;
    final ramp = dark ? DarkTuning.ramp : LightTuning.ramp;
    final lbl = dark ? DarkTuning.labelBase : LightTuning.labelBase;
    final sepBase = dark ? DarkTuning.separatorBase : LightTuning.separatorBase;
    final sepAlpha =
        dark ? DarkTuning.separatorAlpha : LightTuning.separatorAlpha;
    final softMix =
        dark ? DarkTuning.accentSoftMix : LightTuning.accentSoftMix;

    Color lift(int i) => Color.lerp(base, Colors.white, ramp[i])!;
    final bgBase = lift(0);
    final bgCard = lift(1);
    final bgRaised = lift(2);
    final bgOverlay = lift(3);

    final accent = _shift(
      AppBrand.green,
      dark ? DarkTuning.accentSatFactor : LightTuning.accentSatFactor,
      dark ? DarkTuning.accentLightDelta : LightTuning.accentLightDelta,
    );

    final dangerContent = _shift(
      AppBrand.danger,
      1.0,
      dark
          ? DarkTuning.dangerContentLightDelta
          : LightTuning.dangerContentLightDelta,
    );

    return AppPalette(
      brightness: b,
      bgBase: bgBase,
      bgCard: bgCard,
      bgRaised: bgRaised,
      bgOverlay: bgOverlay,
      label: lbl,
      labelSecondary: lbl.withValues(
          alpha: dark ? DarkTuning.lSecondary : LightTuning.lSecondary),
      labelTertiary: lbl.withValues(
          alpha: dark ? DarkTuning.lTertiary : LightTuning.lTertiary),
      labelQuaternary: lbl.withValues(
          alpha: dark ? DarkTuning.lQuaternary : LightTuning.lQuaternary),
      placeholder: lbl.withValues(
          alpha: dark ? DarkTuning.lPlaceholder : LightTuning.lPlaceholder),
      separator: sepBase.withValues(alpha: sepAlpha),
      opaqueSeparator:
          dark ? DarkTuning.opaqueSeparator : LightTuning.opaqueSeparator,
      fill: lbl.withValues(alpha: dark ? 0.12 : 0.05),
      fillSecondary: lbl.withValues(alpha: dark ? 0.08 : 0.03),
      accent: accent,
      // A near-black tint of the accent's own hue: correct on the lime in both
      // themes, and visually indistinguishable from black in light mode.
      onAccent: _shift(accent, 0.63, 0, absoluteLightness: 0.08),
      accentSoft:
          Color.alphaBlend(accent.withValues(alpha: softMix), bgCard),
      onAccentSoft: lbl,
      danger: AppBrand.danger,
      onDanger: Colors.white,
      dangerContent: dangerContent,
      barFill: dark
          ? bgRaised.withValues(alpha: 0.72)
          : Colors.white.withValues(alpha: 0.88),
      barBorder: dark
          ? sepBase.withValues(alpha: 0.50)
          : Colors.black.withValues(alpha: 0.07),
      scrim: Colors.black.withValues(
          alpha: dark ? DarkTuning.scrimAlpha : LightTuning.scrimAlpha),
      // In dark the hero card sits on the ramp; in light it inverts to black.
      // One step above cards in dark so the hero reads as the top-level
      // element rather than just another card; inverted black in light.
      heroSurface: dark ? bgRaised : const Color(0xFF000000),
      // OPAQUE, deliberately. The mascot painter fills one rect per pixel; a
      // translucent colour double-blends where cell edges meet and paints a
      // visible grid over the character. Flatten once, here.
      mascotBody: Color.alphaBlend(
        lbl.withValues(
            alpha: dark ? DarkTuning.mascotAlpha : LightTuning.mascotAlpha),
        bgCard,
      ),
      onHero: dark ? lbl : Colors.white,
      shadow: dark ? DarkTuning.shadow : LightTuning.shadow,
    );
  }

  /// HSL shift — every derived brand colour goes through this, so re-tuning
  /// [AppBrand] re-derives the whole app rather than needing new hexes.
  static Color _shift(
    Color c,
    double satFactor,
    double lightDelta, {
    double? absoluteLightness,
  }) {
    final hsl = HSLColor.fromColor(c);
    return hsl
        .withSaturation((hsl.saturation * satFactor).clamp(0.0, 1.0))
        .withLightness(
            (absoluteLightness ?? (hsl.lightness + lightDelta)).clamp(0.0, 1.0))
        .toColor();
  }

  @override
  AppPalette copyWith({
    Brightness? brightness,
    Color? bgBase,
    Color? bgCard,
    Color? bgRaised,
    Color? bgOverlay,
    Color? label,
    Color? labelSecondary,
    Color? labelTertiary,
    Color? labelQuaternary,
    Color? placeholder,
    Color? separator,
    Color? opaqueSeparator,
    Color? fill,
    Color? fillSecondary,
    Color? accent,
    Color? onAccent,
    Color? accentSoft,
    Color? onAccentSoft,
    Color? danger,
    Color? onDanger,
    Color? dangerContent,
    Color? barFill,
    Color? barBorder,
    Color? scrim,
    Color? heroSurface,
    Color? onHero,
    Color? mascotBody,
    Color? shadow,
  }) =>
      AppPalette(
        brightness: brightness ?? this.brightness,
        bgBase: bgBase ?? this.bgBase,
        bgCard: bgCard ?? this.bgCard,
        bgRaised: bgRaised ?? this.bgRaised,
        bgOverlay: bgOverlay ?? this.bgOverlay,
        label: label ?? this.label,
        labelSecondary: labelSecondary ?? this.labelSecondary,
        labelTertiary: labelTertiary ?? this.labelTertiary,
        labelQuaternary: labelQuaternary ?? this.labelQuaternary,
        placeholder: placeholder ?? this.placeholder,
        separator: separator ?? this.separator,
        opaqueSeparator: opaqueSeparator ?? this.opaqueSeparator,
        fill: fill ?? this.fill,
        fillSecondary: fillSecondary ?? this.fillSecondary,
        accent: accent ?? this.accent,
        onAccent: onAccent ?? this.onAccent,
        accentSoft: accentSoft ?? this.accentSoft,
        onAccentSoft: onAccentSoft ?? this.onAccentSoft,
        danger: danger ?? this.danger,
        onDanger: onDanger ?? this.onDanger,
        dangerContent: dangerContent ?? this.dangerContent,
        barFill: barFill ?? this.barFill,
        barBorder: barBorder ?? this.barBorder,
        scrim: scrim ?? this.scrim,
        heroSurface: heroSurface ?? this.heroSurface,
        onHero: onHero ?? this.onHero,
        mascotBody: mascotBody ?? this.mascotBody,
        shadow: shadow ?? this.shadow,
      );

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppPalette(
      brightness: t < 0.5 ? brightness : other.brightness,
      bgBase: c(bgBase, other.bgBase),
      bgCard: c(bgCard, other.bgCard),
      bgRaised: c(bgRaised, other.bgRaised),
      bgOverlay: c(bgOverlay, other.bgOverlay),
      label: c(label, other.label),
      labelSecondary: c(labelSecondary, other.labelSecondary),
      labelTertiary: c(labelTertiary, other.labelTertiary),
      labelQuaternary: c(labelQuaternary, other.labelQuaternary),
      placeholder: c(placeholder, other.placeholder),
      separator: c(separator, other.separator),
      opaqueSeparator: c(opaqueSeparator, other.opaqueSeparator),
      fill: c(fill, other.fill),
      fillSecondary: c(fillSecondary, other.fillSecondary),
      accent: c(accent, other.accent),
      onAccent: c(onAccent, other.onAccent),
      accentSoft: c(accentSoft, other.accentSoft),
      onAccentSoft: c(onAccentSoft, other.onAccentSoft),
      danger: c(danger, other.danger),
      onDanger: c(onDanger, other.onDanger),
      dangerContent: c(dangerContent, other.dangerContent),
      barFill: c(barFill, other.barFill),
      barBorder: c(barBorder, other.barBorder),
      scrim: c(scrim, other.scrim),
      heroSurface: c(heroSurface, other.heroSurface),
      onHero: c(onHero, other.onHero),
      mascotBody: c(mascotBody, other.mascotBody),
      shadow: c(shadow, other.shadow),
    );
  }
}

final AppPalette _lightFallback = AppPalette.of(Brightness.light);
final AppPalette _darkFallback = AppPalette.of(Brightness.dark);

/// Theme-aware colour tokens read from `BuildContext`.
///
/// The legacy getters below are a facade over [AppPalette] so the ~326 existing
/// call sites keep working unchanged. Prefer `context.palette` in new code.
extension AppColorsX on BuildContext {
  AppPalette get palette {
    final theme = Theme.of(this);
    return theme.extension<AppPalette>() ??
        (theme.brightness == Brightness.dark ? _darkFallback : _lightFallback);
  }

  Color get surface => palette.bgBase;
  Color get cardSurface => palette.bgCard;
  Color get ink => palette.label;
  Color get inkMuted => palette.labelSecondary;
  Color get inkSubtle => palette.placeholder;
  Color get hairline => palette.separator;
  List<BoxShadow> get softShadow => palette.softShadow;
}

/// Legacy constants. Prefer `context.palette` — these cannot adapt to theme.
///
/// `ink` is correct for light mode only; on dark surfaces it is pure black and
/// will be unreadable. Retained so the migration can proceed file by file.
class AppColors {
  static const green = AppBrand.green;
  static const danger = AppBrand.danger;
  static const ink = Color(0xFF000000);
  static const surface = Color(0xFFFFFFFF);

  /// Translucent accent wash. Superseded by `context.palette.accentSoft`,
  /// which is opaque and therefore predictable on any background.
  static Color greenSoft = AppBrand.green.withValues(alpha: 0.12);
}

ThemeData buildAppTheme() => _buildTheme(Brightness.light);
ThemeData buildDarkAppTheme() => _buildTheme(Brightness.dark);

ThemeData _buildTheme(Brightness b) {
  final p = AppPalette.of(b);
  final base = b == Brightness.dark
      ? ThemeData.dark(useMaterial3: true)
      : ThemeData.light(useMaterial3: true);

  final textTheme = GoogleFonts.plusJakartaSansTextTheme(base.textTheme)
      .apply(bodyColor: p.label, displayColor: p.label);

  // Material's own surfaces (dialogs, menus, snackbars) are pinned to the
  // palette; otherwise the seed-generated roles drift away from the ramp and
  // there are two sources of truth again.
  final scheme = ColorScheme.fromSeed(
    seedColor: AppBrand.green,
    brightness: b,
    surface: p.bgBase,
    surfaceContainer: p.bgCard,
    surfaceContainerHigh: p.bgRaised,
    surfaceContainerHighest: p.bgOverlay,
    onSurface: p.label,
    onSurfaceVariant: p.labelSecondary,
    outlineVariant: p.separator,
    primary: p.label,
    onPrimary: p.bgBase,
    secondary: p.accent,
    onSecondary: p.onAccent,
    error: p.danger,
    onError: p.onDanger,
  );

  return base.copyWith(
    extensions: [p],
    scaffoldBackgroundColor: p.bgBase,
    colorScheme: scheme,
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: p.bgBase,
      surfaceTintColor: p.bgBase,
      foregroundColor: p.label,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      systemOverlayStyle: p.overlayStyle,
      titleTextStyle: textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        fontSize: 22,
        letterSpacing: -0.3,
        color: p.label,
      ),
    ),
    dividerTheme: DividerThemeData(color: p.separator, thickness: 1, space: 1),
    cardTheme: CardThemeData(
      color: p.bgCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: p.separator),
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      margin: EdgeInsets.zero,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: p.label,
        foregroundColor: p.bgBase,
        minimumSize: const Size.fromHeight(52),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: p.label,
        side: BorderSide(color: p.separator),
        minimumSize: const Size.fromHeight(52),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: p.label),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: p.label,
      foregroundColor: p.bgBase,
      elevation: 4,
      shape: const CircleBorder(),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: false,
      hintStyle: textTheme.bodyMedium?.copyWith(color: p.placeholder),
      labelStyle: textTheme.bodyMedium?.copyWith(color: p.labelSecondary),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: p.separator),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: p.label, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: p.dangerContent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: p.dangerContent, width: 1.5),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.bgCard,
      surfaceTintColor: p.bgCard,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadii.hero)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.bgOverlay,
      surfaceTintColor: p.bgOverlay,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: p.bgOverlay,
      surfaceTintColor: p.bgOverlay,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: p.label,
      contentTextStyle: textTheme.bodyMedium?.copyWith(color: p.bgBase),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    splashFactory: NoSplash.splashFactory,
    // One transition on every platform, so this is one app rather than
    // "Material here, iOS there". Brings the interactive left-edge back-swipe
    // with it — disabled on the first route, so HomeShell's double-back-to-exit
    // is unaffected. See lib/core/routes.dart for the PopScope caveat.
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: CupertinoPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.fuchsia: CupertinoPageTransitionsBuilder(),
      TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
      TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
    }),
  );
}

/// Static styles — left without `color` so DefaultTextStyle / Theme provides it.
/// All carry tabular figures so numbers align and animate without jitter.
class AppTextStyles {
  static TextStyle display = GoogleFonts.plusJakartaSans(
    fontSize: 40,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.2,
    height: 1.0,
    fontFeatures: _kTabular,
  );
  static TextStyle headline = GoogleFonts.plusJakartaSans(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    fontFeatures: _kTabular,
  );
  static TextStyle title = GoogleFonts.plusJakartaSans(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    fontFeatures: _kTabular,
  );
  static TextStyle body = GoogleFonts.plusJakartaSans(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    fontFeatures: _kTabular,
  );
  static TextStyle caption = GoogleFonts.plusJakartaSans(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.3,
    fontFeatures: _kTabular,
  );

  /// Overline — small uppercase section label with wide tracking. Editorial
  /// hierarchy device used for "RECENT ACTIVITY", "OVERVIEW", day headers, etc.
  static TextStyle overline = GoogleFonts.plusJakartaSans(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.2,
    fontFeatures: _kTabular,
  );
}
