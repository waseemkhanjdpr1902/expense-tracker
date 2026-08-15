import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'theme.dart';

/// The glass material — translucent chrome for the navigation layer.
///
/// **Scope, and why it is narrow.** Apple's guidance is explicit: *"Don't use
/// Liquid Glass in the content layer… including it in the content layer can
/// result in unnecessary complexity and a confusing visual hierarchy"*, and
/// *"Limit these effects to the most important functional elements in your
/// app."* So this belongs to app bars, the nav bar and sheets — never to a
/// record row, a balance figure, or any card holding a number.
///
/// **Regular, never clear.** Apple ships two variants: `regular`, which blurs
/// *and adjusts luminosity* to protect legibility and is prescribed for
/// anything text-heavy; and `clear`, which is *"only"* for components over
/// visually rich backgrounds like photo and video. A ledger is the former. The
/// see-through look people associate with iOS 26 is the media special case.
///
/// **Contrast stays assertable.** A purely translucent surface inherits
/// whatever is behind it, so its contrast is a property of the scroll position
/// — independently audited Liquid Glass surfaces measured around 1.5:1 where AA
/// wants 4.5:1. This app already learned that lesson once, when translucent
/// `accentSoft` produced unreadable 2.11:1 text and had to be blended opaque.
/// The fix here is [fillFor]: the tint carries enough alpha that the effective
/// background is dominated by the fill rather than the backdrop, which makes it
/// testable against the two extremes (see `glass_contrast_test.dart`).
enum GlassProminence {
  /// App bars. Content scrolls beneath, so legibility matters most and the
  /// blur has to survive fast-moving lists.
  appBar,

  /// The floating nav bar. Small, bright, and the one surface users touch most.
  bar,

  /// Sheets. *"Bigger surfaces should read as thicker: stronger blur and a
  /// deeper shadow than small chips"* — and Apple likewise makes larger
  /// elements more opaque "to preserve legibility over complex backgrounds".
  sheet,
}

/// Tunable material constants. As with `DarkTuning`, retune here and nowhere
/// else.
abstract final class GlassTuning {
  /// Backdrop blur, in Skia sigma. CSS `blur(20px)` ≈ sigma 10.
  static const double sigmaAppBar = 24;
  static const double sigmaBar = 28;
  static const double sigmaSheet = 32;

  /// Blur averages colour toward grey, which is what makes a plain blur look
  /// dead rather than like glass. Pushing saturation back up is most of the
  /// difference between "frosted" and "blurred". Reverse-engineering write-ups
  /// cite 10–20%; their own CSS says `saturate(180%)`, which is garish over a
  /// near-black ramp.
  static const double saturation = 1.18;

  /// Opacity of the tint fill over the blurred backdrop. High enough that
  /// contrast is governed by the fill — see the class doc.
  ///
  /// The two themes have different floors because their labels do. Dark's
  /// label is `#EBEBF5`, which washes out over a bright backdrop, so the fill
  /// has to stay thick enough to bound the spread — 0.70 is where that guard
  /// breaks, and 0.76 sits just above it. Light's label is pure black, which
  /// survives even a dark backdrop (5.3:1 at alpha 0.50), so the same
  /// guarantee costs far less opacity there. At 0.88 only 12% of the blurred
  /// backdrop showed and the bar read as flat white; 0.72 more than doubles
  /// that while leaving the label at 10.5:1 over the darkest possible
  /// backdrop.
  static const double fillAlphaDark = 0.76;
  static const double fillAlphaLight = 0.72;

  /// Sheets sit over frozen content and cover more area, so they can afford to
  /// be — and per Apple should be — more opaque still.
  static const double sheetAlphaBoost = 0.06;

  /// The rim. A bright top edge fading to a dim bottom edge is what reads as
  /// "lit from above"; it is the cheapest part of the effect and does the most
  /// work. Alphas are of the rim colour, not absolute.
  static const double rimTop = 0.40;
  static const double rimSide = 0.20;
  static const double rimBottom = 0.10;
  static const double rimWidth = 1.2;

  /// Dither. Skia's blur bands visibly on large gradients; a couple of percent
  /// of noise hides it.
  static const double noiseAlpha = 0.025;
  static const int noiseTile = 64;

  /// ── Refraction ─────────────────────────────────────────────────────────
  ///
  /// How wide the refracting band is, inward from the edge, in logical pixels.
  /// This is the apparent *thickness* of the pane: a wide band reads as a slab,
  /// a narrow one as a sheet. It stays a band rather than the whole surface on
  /// purpose — full-surface warping is Apple's `clear` variant, prescribed for
  /// media backdrops, and over a list of numbers it fights the text.
  static const double edgeBand = 22;

  /// How far the rim displaces its backdrop lookup at full strength, in logical
  /// pixels. This is the single dial for "how much glass". Past ~14 the edge
  /// starts to smear rather than bend.
  static const double refraction = 9;

  /// Specular rim intensity. The shader draws this instead of [_GlassPainter]'s
  /// gradient stroke when refraction is active, because it can place the
  /// highlight against the true surface normal rather than a vertical ramp.
  static const double specular = 0.16;
}

/// The compiled refraction program, or null if it could not be loaded.
///
/// Loaded once from `main()`. Everything degrades to the plain blur if this
/// stays null: `ImageFilter.shader` needs Impeller, and an app that cannot
/// compile the program must still render its chrome.
abstract final class LiquidGlassProgram {
  static ui.FragmentProgram? _program;
  static bool _tried = false;

  static ui.FragmentProgram? get program => _program;

  /// Safe to call more than once; only the first call does work.
  static Future<void> ensureLoaded() async {
    if (_tried) return;
    _tried = true;
    try {
      _program = await ui.FragmentProgram.fromAsset('shaders/liquid_glass.frag');
    } catch (e) {
      // Non-fatal by design — the blur path is a complete fallback.
      debugPrint('liquid glass shader unavailable, using plain blur: $e');
      _program = null;
    }
  }
}

extension GlassProminenceX on GlassProminence {
  double get sigma => switch (this) {
        GlassProminence.appBar => GlassTuning.sigmaAppBar,
        GlassProminence.bar => GlassTuning.sigmaBar,
        GlassProminence.sheet => GlassTuning.sigmaSheet,
      };
}

/// The tint fill for [prominence], derived from the palette.
///
/// Exposed so tests can assert foreground contrast against it without building
/// a widget tree.
Color glassFill(AppPalette p, GlassProminence prominence) {
  final dark = p.brightness == Brightness.dark;
  var alpha = dark ? GlassTuning.fillAlphaDark : GlassTuning.fillAlphaLight;
  if (prominence == GlassProminence.sheet) {
    alpha = math.min(1.0, alpha + GlassTuning.sheetAlphaBoost);
  }
  // Dark glass lifts off bgRaised so the bar reads as *above* the page rather
  // than a hole punched in it; light glass stays white, as it did before.
  final base = dark ? p.bgRaised : const Color(0xFFFFFFFF);
  return base.withValues(alpha: alpha);
}

/// The worst-case opaque colour a glass surface can resolve to, for contrast
/// assertions: the fill composited over the darkest and lightest possible
/// backdrops.
({Color overBlack, Color overWhite}) glassExtremes(
    AppPalette p, GlassProminence prominence) {
  final fill = glassFill(p, prominence);
  return (
    overBlack: Color.alphaBlend(fill, const Color(0xFF000000)),
    overWhite: Color.alphaBlend(fill, const Color(0xFFFFFFFF)),
  );
}

/// Whether translucency should be suppressed for this frame.
///
/// Apple shipped exactly this control in iOS 26.1 after walking the effect back
/// across four betas — and put it in **Display & Brightness, not
/// Accessibility**, having concluded it is a mainstream preference rather than
/// an accommodation. [reduceTransparencyProvider] mirrors that; this function
/// additionally honours the OS-level accessibility flags.
bool glassDisabled(BuildContext context, {bool userPreference = false}) {
  final mq = MediaQuery.maybeOf(context);
  return userPreference ||
      (mq?.highContrast ?? false) ||
      (mq?.accessibleNavigation ?? false);
}

/// A translucent chrome surface.
///
/// Layer order matters and matches the material: blurred+saturated backdrop,
/// tint, dither, rim, child. The whole thing is clipped first — an unclipped
/// [BackdropFilter] samples the entire layer tree behind it.
class GlassSurface extends StatefulWidget {
  const GlassSurface({
    super.key,
    required this.child,
    required this.borderRadius,
    this.prominence = GlassProminence.bar,
    this.disabled = false,
    this.rim = true,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final GlassProminence prominence;

  /// Renders opaque with no blur. Costs nothing and is the honest fallback.
  final bool disabled;

  /// The lit edge. Suppressed where a surface has no free edges to catch light
  /// (a full-bleed app bar's sides run off-screen).
  final bool rim;

  @override
  State<GlassSurface> createState() => _GlassSurfaceState();
}

class _GlassSurfaceState extends State<GlassSurface> {
  /// Held for the life of the surface rather than rebuilt per frame.
  /// [ui.FragmentProgram.fragmentShader] allocates a native shader, and this
  /// widget rebuilds while the list behind it scrolls — minting one per frame
  /// and dropping it leaks GPU-side memory for as long as the app runs.
  ui.FragmentShader? _shader;

  ui.FragmentShader? get _refractionShader {
    if (_shader != null) return _shader;
    final program = LiquidGlassProgram.program;
    if (program == null) return null;
    return _shader = program.fragmentShader();
  }

  @override
  void dispose() {
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final fill = glassFill(p, widget.prominence);

    if (widget.disabled) {
      // Opaque, deterministic, and no save-layer.
      return DecoratedBox(
        decoration: BoxDecoration(
          color: Color.alphaBlend(fill, p.bgBase),
          borderRadius: widget.borderRadius,
          border: Border.all(color: p.barBorder, width: 1),
        ),
        child: widget.child,
      );
    }

    final dark = p.brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: Builder(
        builder: (context) {
          // The shader works in the filter input's pixels, so radius and band
          // widths have to be scaled out of logical units.
          final dpr = MediaQuery.devicePixelRatioOf(context);
          final refract = _refractionFilter(
            shader: _refractionShader,
            dpr: dpr,
            radius: widget.borderRadius.topLeft.x,
            // A full-bleed bar's side edges run off-screen; bending light at a
            // seam that isn't there reads as a floating card, not as chrome.
            specular: widget.rim ? GlassTuning.specular : 0,
            dark: dark,
          );

          // Composed into ONE filter. Nesting BackdropFilters would cost a
          // second full-screen save-layer for no visual gain.
          ui.ImageFilter filter = ui.ImageFilter.compose(
            outer: ColorFilter.matrix(_saturate(GlassTuning.saturation)),
            inner: ui.ImageFilter.blur(
              sigmaX: widget.prominence.sigma,
              sigmaY: widget.prominence.sigma,
            ),
          );
          if (refract != null) {
            // Blur first, then bend: refracting a sharp backdrop shows the
            // displacement as a visible seam rather than as thickness.
            filter = ui.ImageFilter.compose(outer: refract, inner: filter);
          }

          return BackdropFilter(
            filter: filter,
            child: CustomPaint(
              painter: _GlassPainter(
                fill: fill,
                dark: dark,
                radius: widget.borderRadius,
                // The shader already lit the rim against the true surface
                // normal; drawing the gradient stroke too would double it.
                drawRim: widget.rim && refract == null,
              ),
              child: widget.child,
            ),
          );
        },
      ),
    );
  }
}

/// The refraction filter, or null when the program is unavailable — in which
/// case [GlassSurface] keeps the plain blur and its painted rim.
ui.ImageFilter? _refractionFilter({
  required ui.FragmentShader? shader,
  required double dpr,
  required double radius,
  required double specular,
  required bool dark,
}) {
  if (shader == null) return null;
  try {
    // Slots 0–1 are the vec2 size; the engine overwrites them with the bound
    // texture's dimensions, but they must exist for the filter to validate.
    shader.setFloat(0, 0);
    shader.setFloat(1, 0);
    shader.setFloat(2, radius * dpr);
    shader.setFloat(3, GlassTuning.edgeBand * dpr);
    shader.setFloat(4, GlassTuning.refraction * dpr);
    shader.setFloat(5, specular);
    shader.setFloat(6, dark ? 1.0 : 0.0);
    return ui.ImageFilter.shader(shader);
  } catch (e) {
    // Impeller off, or a driver that rejected the program.
    debugPrint('liquid glass filter unavailable: $e');
    return null;
  }
}

/// Saturation matrix. Luminance-preserving, so only chroma moves.
List<double> _saturate(double s) {
  const lr = 0.213, lg = 0.715, lb = 0.072;
  final sr = (1 - s) * lr, sg = (1 - s) * lg, sb = (1 - s) * lb;
  return <double>[
    sr + s, sg, sb, 0, 0, //
    sr, sg + s, sb, 0, 0, //
    sr, sg, sb + s, 0, 0, //
    0, 0, 0, 1, 0, //
  ];
}

class _GlassPainter extends CustomPainter {
  _GlassPainter({
    required this.fill,
    required this.dark,
    required this.radius,
    required this.drawRim,
  });

  final Color fill;
  final bool dark;
  final BorderRadius radius;
  final bool drawRim;

  /// Built once for the whole app. A 64×64 tile of monochrome noise, shared by
  /// every glass surface via an ImageShader.
  static ui.Image? _noise;

  static ui.Image _noiseTile() {
    if (_noise != null) return _noise!;
    const n = GlassTuning.noiseTile;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    // Fixed seed: the dither must not shimmer between frames or rebuilds.
    final rng = math.Random(0x5EED);
    final paint = Paint();
    for (var i = 0; i < n * n ~/ 3; i++) {
      final v = rng.nextDouble();
      paint.color = Color.fromRGBO(255, 255, 255, v);
      canvas.drawRect(
        Rect.fromLTWH(
            rng.nextInt(n).toDouble(), rng.nextInt(n).toDouble(), 1, 1),
        paint,
      );
    }
    return _noise = recorder.endRecording().toImageSync(n, n);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = radius.toRRect(rect);

    canvas.drawRRect(rrect, Paint()..color = fill);

    canvas.save();
    canvas.clipRRect(rrect);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.ImageShader(
          _noiseTile(),
          TileMode.repeated,
          TileMode.repeated,
          Matrix4.identity().storage,
        )
        ..color = Colors.white.withValues(alpha: GlassTuning.noiseAlpha)
        ..blendMode = BlendMode.overlay,
    );
    canvas.restore();

    if (!drawRim) return;

    // The lit edge. In dark, a white rim bright at the top fading down — light
    // catching the upper surface of a solid. In light, a white rim would be
    // invisible against a near-white fill, so the edge inverts: a black rim,
    // faintest at the top and strongest along the bottom, which is the shadow
    // the same lighting would cast. Both read as "lit from above".
    final rimColor = dark ? const Color(0xFFFFFFFF) : const Color(0xFF000000);
    final alphas = dark
        ? const [GlassTuning.rimTop, GlassTuning.rimSide, GlassTuning.rimBottom]
        : const [0.05, 0.07, 0.12];

    final inset = rrect.deflate(GlassTuning.rimWidth / 2);
    canvas.drawRRect(
      inset,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = GlassTuning.rimWidth
        ..shader = ui.Gradient.linear(
          Offset(rect.center.dx, rect.top),
          Offset(rect.center.dx, rect.bottom),
          [
            rimColor.withValues(alpha: alphas[0]),
            rimColor.withValues(alpha: alphas[1]),
            rimColor.withValues(alpha: alphas[2]),
          ],
          const [0.0, 0.5, 1.0],
        ),
    );
  }

  @override
  bool shouldRepaint(covariant _GlassPainter old) =>
      old.fill != fill ||
      old.dark != dark ||
      old.radius != radius ||
      old.drawRim != drawRim;
}

/// An app bar with a glass background, for screens whose content scrolls
/// beneath it.
///
/// Only worth using with `Scaffold(extendBodyBehindAppBar: true)` and a body
/// that extends to the top of the screen — otherwise there is nothing behind
/// the bar to blur and this is an expensive way to paint a flat colour.
///
/// **This is where the scroll edge effect lives.** Apple's *"scroll edge
/// effects, not hard dividers"* is a legibility mechanism, and the regular
/// variant already implements it: *"blurs and adjusts the luminosity of
/// background content to maintain legibility"*. A separate gradient scrim under
/// the bar would be a second solution to the same problem, so there isn't one.
///
/// No rim: a full-bleed bar's left and right edges run off-screen, and a lit
/// ring drawn around seams that don't exist reads as a floating card rather
/// than as chrome fused to the top of the display.
class GlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  const GlassAppBar({
    super.key,
    required this.appBar,
    required this.disabled,
  });

  /// The bar itself. Its own `backgroundColor` is overridden to transparent so
  /// the glass shows through.
  final AppBar appBar;
  final bool disabled;

  @override
  Size get preferredSize => appBar.preferredSize;

  @override
  Widget build(BuildContext context) {
    // flexibleSpace fills the whole bar including the status-bar inset and any
    // `bottom` widget, so a TabBar in `bottom:` sits on the same pane of glass
    // rather than on a second one stacked below it — "avoid overcrowding or
    // layering Liquid Glass elements on top of each other".
    return AppBar(
      key: appBar.key,
      title: appBar.title,
      actions: appBar.actions,
      leading: appBar.leading,
      automaticallyImplyLeading: appBar.automaticallyImplyLeading,
      bottom: appBar.bottom,
      titleSpacing: appBar.titleSpacing,
      centerTitle: appBar.centerTitle,
      systemOverlayStyle: appBar.systemOverlayStyle,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      flexibleSpace: GlassSurface(
        borderRadius: BorderRadius.zero,
        prominence: GlassProminence.appBar,
        disabled: disabled,
        rim: false,
        child: const SizedBox.expand(),
      ),
    );
  }
}
