import 'dart:ui';

Color hexToColor(String hexString) {
  final buffer = StringBuffer();
  if (hexString.length == 6 || hexString.length == 7) {
    buffer.write('ff');
  }
  buffer.write(hexString.replaceFirst('#', ''));
  return Color(int.parse(buffer.toString(), radix: 16));
}

enum Neutral {
  c0(Color(0xFFFFFFFF)),
  c100(Color(0xFFF8F8F9)),
  c200(Color(0xFFEFEFF1)),
  c300(Color(0xFFE1E2E5)),
  c400(Color(0xFFD1D3D7)),
  c500(Color(0xFFB3B7BE)),
  c600(Color(0xFF9095A0)),
  c700(Color(0xFF6A6F7B)),
  c800(Color(0xFF555962)),
  c900(Color(0xFF464951)),
  c1000(Color(0xFF2F3136));

  const Neutral(this.color);

  final Color color;
}

enum Warning {
  c100(Color(0xFFFFF7EB)),
  c200(Color(0xFFFFEDD1)),
  c300(Color(0xFFFDDEAA)),
  c400(Color(0xFFF7CD7D)),
  c500(Color(0xFFDFB04A)),
  c600(Color(0xFFB68F3E)),
  c700(Color(0xFF886B31)),
  c800(Color(0xFF6C5629)),
  c900(Color(0xFF594623)),
  c1000(Color(0xFF3B2F1A));

  const Warning(this.color);

  final Color color;
}

enum Danger {
  c100(Color(0xFFFFF6F5)),
  c200(Color(0xFFFFEAE7)),
  c300(Color(0xFFFFD8D4)),
  c400(Color(0xFFFFC5BE)),
  c500(Color(0xFFFF9C94)),
  c600(Color(0xFFF46864)),
  c700(Color(0xFFBF4746)),
  c800(Color(0xFF973B39)),
  c900(Color(0xFF7B322F)),
  c1000(Color(0xFF502421));

  const Danger(this.color);

  final Color color;
}

enum Success {
  c100(Color(0xFFF4FAF4)),
  c200(Color(0xFFE5F3E5)),
  c300(Color(0xFFCEE9CF)),
  c400(Color(0xFFB4DDB6)),
  c500(Color(0xFF84C78B)),
  c600(Color(0xFF38A952)),
  c700(Color(0xFF2A7F3D)),
  c800(Color(0xFF266532)),
  c900(Color(0xFF21532A)),
  c1000(Color(0xFF1A371E));

  const Success(this.color);

  final Color color;
}

enum Info {
  c100(Color(0xFFF5F9FD)),
  c200(Color(0xFFE9F0FB)),
  c300(Color(0xFFD5E3F7)),
  c400(Color(0xFFBED5F3)),
  c500(Color(0xFF92BAEA)),
  c600(Color(0xFF4B9AE0)),
  c700(Color(0xFF2E73AC)),
  c800(Color(0xFF2A5C88)),
  c900(Color(0xFF264C6E)),
  c1000(Color(0xFF1E3248));

  const Info(this.color);

  final Color color;
}

class Primary {
  Primary(Map<String, String?> colors)
      : c100 = hexToColor(colors['primary_100']!),
        c200 = hexToColor(colors['primary_200']!),
        c300 = hexToColor(colors['primary_300']!),
        c400 = hexToColor(colors['primary_400']!),
        c500 = hexToColor(colors['primary_500']!),
        c600 = hexToColor(colors['primary_600']!),
        c700 = hexToColor(colors['primary_700']!),
        c800 = hexToColor(colors['primary_800']!),
        c900 = hexToColor(colors['primary_900']!),
        c1000 = hexToColor(colors['primary_1000']!);

  final Color c100;
  final Color c200;
  final Color c300;
  final Color c400;
  final Color c500;
  final Color c600;
  final Color c700;
  final Color c800;
  final Color c900;
  final Color c1000;
}

class Accent {
  Accent(Map<String, String?> colors)
      : c100 = hexToColor(colors['accent_100']!),
        c200 = hexToColor(colors['accent_200']!),
        c300 = hexToColor(colors['accent_300']!),
        c400 = hexToColor(colors['accent_400']!),
        c500 = hexToColor(colors['accent_500']!),
        c600 = hexToColor(colors['accent_600']!),
        c700 = hexToColor(colors['accent_700']!),
        c800 = hexToColor(colors['accent_800']!),
        c900 = hexToColor(colors['accent_900']!),
        c1000 = hexToColor(colors['accent_1000']!),
        c800t08 = colors['800-t08'] != null
            ? hexToColor(colors['800-t08']!)
            : const Color(0x00000000),
        c800t12 = colors['800-t12'] != null
            ? hexToColor(colors['c800-t12']!)
            : const Color(0x00000000);

  final Color c100;
  final Color c200;
  final Color c300;
  final Color c400;
  final Color c500;
  final Color c600;
  final Color c700;
  final Color c800;
  final Color c900;
  final Color c1000;
  final Color c800t08;
  final Color c800t12;
}

enum CellulaSpacing {
  x0_25(2),
  x0_5(4),
  x1(8),
  x1_5(12),
  x2(16),
  x2_5(20),
  x3(24),
  x4(32),
  x5(40),
  x6(48),
  x7(56),
  x8(64),
  x9(72);

  final double spacing;

  const CellulaSpacing(this.spacing);
}

enum CellulaBorderRadius {
  xSmall(4),
  small(8),
  medium(12),
  large(16),
  pill(999),
  circle(50);

  const CellulaBorderRadius(this.value);

  final double value;
}

enum CellulaElevation {
  skim(0, 1, 2, 20),
  lifted(0, 2, 6, 18),
  floating(0, 4, 14, 16),
  flying(0, 6, 22, 14);

  const CellulaElevation(this.x, this.y, this.blur, this.opacity);

  final double x;
  final double y;
  final int blur;
  final double opacity;
}

class CellulaFontVariant {
  const CellulaFontVariant(this.fontSize, this.fontWeight, this.lineHeight);

  final double fontSize;
  final FontWeight fontWeight;
  final double lineHeight;
}

enum CellulaFontDisplay {
  xLarge(CellulaFontVariant(60, FontWeight.bold, 75)),
  large(CellulaFontVariant(54, FontWeight.bold, 67)),
  medium(CellulaFontVariant(48, FontWeight.bold, 60)),
  small(CellulaFontVariant(42, FontWeight.bold, 52));

  const CellulaFontDisplay(this.fontVariant);

  final CellulaFontVariant fontVariant;
}

enum CellulaFontHeading {
  xLarge(CellulaFontVariant(36, FontWeight.w600, 45)),
  large(CellulaFontVariant(32, FontWeight.w600, 40)),
  medium(CellulaFontVariant(28, FontWeight.w600, 35)),
  small(CellulaFontVariant(24, FontWeight.w600, 30)),
  xSmall(CellulaFontVariant(20, FontWeight.w600, 25));

  const CellulaFontHeading(this.fontVariant);

  final CellulaFontVariant fontVariant;
}

enum CellulaFontBody {
  largeRegular(CellulaFontVariant(18, FontWeight.normal, 26)),
  largeSemiBold(CellulaFontVariant(18, FontWeight.w600, 26)),
  regular(CellulaFontVariant(16, FontWeight.normal, 24)),
  semiBold(CellulaFontVariant(16, FontWeight.w600, 24)),
  smallRegular(CellulaFontVariant(14, FontWeight.normal, 24)),
  smallSemiBold(CellulaFontVariant(14, FontWeight.w600, 20));

  const CellulaFontBody(this.fontVariant);

  final CellulaFontVariant fontVariant;
}

enum CellulaFontLabel {
  xLargeRegular(CellulaFontVariant(20, FontWeight.normal, 25)),
  xLargeSemiBold(CellulaFontVariant(20, FontWeight.w600, 25)),
  largeRegular(CellulaFontVariant(18, FontWeight.normal, 22)),
  largeSemiBold(CellulaFontVariant(18, FontWeight.w600, 22)),
  regular(CellulaFontVariant(16, FontWeight.normal, 20)),
  semiBold(CellulaFontVariant(16, FontWeight.w600, 20)),
  smallRegular(CellulaFontVariant(14, FontWeight.normal, 18)),
  smallSemiBold(CellulaFontVariant(14, FontWeight.w600, 18)),
  xSmallRegular(CellulaFontVariant(12, FontWeight.normal, 15)),
  xSmallSemiBold(CellulaFontVariant(12, FontWeight.w600, 15));

  const CellulaFontLabel(this.fontVariant);

  final CellulaFontVariant fontVariant;
}
