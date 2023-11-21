import 'dart:ui';

import 'package:shove/cellula/cellula_foundation/cellula_foundation.dart';

class CellulaTokens {
  final Primary primary;
  final Accent accent;
  final BorderTokens border;
  final ContentTokens content;
  final BgTokens bg;
  final WarningTokens warning;
  final DangerTokens danger;
  final SuccessTokens success;
  final InfoTokens info;

  CellulaTokens(this.primary, this.accent)
      : border = BorderTokens(primary),
        content = ContentTokens(primary),
        bg = BgTokens(primary, accent),
        warning = WarningTokens(),
        danger = DangerTokens(),
        success = SuccessTokens(),
        info = InfoTokens();

  CellulaTokens.none() : this(defaultPrimary(), defaultAccent());

  static Primary defaultPrimary() {
    return Primary({
      'primary_100': '#FEF7EF',
      'primary_200': '#F8EEE1',
      'primary_300': '#E9E0D4',
      'primary_400': '#DAD1C6',
      'primary_500': '#BDB6AC',
      'primary_600': '#9A948D',
      'primary_700': '#736E69',
      'primary_800': '#5C5854',
      'primary_900': '#4B4845',
      'primary_1000': '#32312F',
    });
  }

  static Accent defaultAccent() {
    return Accent({
      'accent_100': '#F9F7FE',
      'accent_200': '#F2EDFE',
      'accent_300': '#E5DCFC',
      'accent_400': '#D8CCFB',
      'accent_500': '#9985F3',
      'accent_600': '#9A948D',
      'accent_700': '#6459EC',
      'accent_800': '#313FE7',
      'accent_900': '#1C32C7',
      'accent_1000': '#23237E',
      '800-t08': '#32312F',
      'c800-t12': '#32312F',
    });
  }
}

class BorderTokens {
  BorderTokens(Primary primary)
      : brand = primary.c400,
        interactive = primary.c800,
        highlight = primary.c600,
        defaultColor = Neutral.c400.color,
        input = Neutral.c500.color;

// Branded
  final Color brand;
  final Color interactive;
  final Color highlight;

// Neutral
  final Color defaultColor;
  final Color input;
}

class ContentTokens {
  ContentTokens(Primary primary)
      : brand = primary.c1000,
        mutedBrand = primary.c800,
        interactive = primary.c800,
        onHighlight = primary.c900,
        defaultColor = Neutral.c1000.color,
        muted = Neutral.c800.color,
        onInteractive = Neutral.c0.color,
        onDark = Neutral.c0.color,
        placeholder = Neutral.c500.color,
        onAppNav = Neutral.c0.color;

// Branded
  final Color brand;
  final Color mutedBrand;
  final Color interactive;
  final Color onHighlight;

// Neutral
  final Color defaultColor;
  final Color muted;
  final Color onInteractive;
  final Color onDark;
  final Color placeholder;
  final Color onAppNav;
}

class BgTokens {
  BgTokens(Primary primary, Accent accent)
      : pageBrand = primary.c100,
        surfaceBrand = primary.c200,
        surfaceDarkBrand = primary.c700,
        highlight = accent.c200,
        interactive = primary.c800,
        interactiveActive = primary.c1000,
        interactiveMutedActive = primary.c800.withOpacity(0.16),
        onAppNav = primary.c900,
        page = Neutral.c100.color,
        surface = Neutral.c0.color,
        surfaceDark = Neutral.c800.color,
        deselected = Neutral.c400.color,
        readOnly = Neutral.c300.color;

  // Branded
  final Color pageBrand;
  final Color surfaceBrand;
  final Color surfaceDarkBrand;
  final Color highlight;
  final Color interactive;
  final Color interactiveActive;
  final Color interactiveMutedActive;
  final Color onAppNav;

  // Neutral
  final Color page;
  final Color surface;
  final Color surfaceDark;
  final Color deselected;
  final Color readOnly;
}

class HighlightTokens {
  HighlightTokens(Accent accent)
      : border = accent.c600,
        contentOn = accent.c900,
        content = accent.c800,
        bg = accent.c300;

  final Color border;
  final Color contentOn;
  final Color content;
  final Color bg;
}

class WarningTokens {
  WarningTokens()
      : border = Warning.c600.color,
        borderMuted = Warning.c500.color,
        contentMuted = Warning.c800.color,
        content = Warning.c1000.color,
        bg = Warning.c300.color,
        bgActive = Warning.c500.color;

  final Color border;
  final Color borderMuted;
  final Color contentMuted;
  final Color content;
  final Color bg;
  final Color bgActive;
}

class SuccessTokens {
  SuccessTokens()
      : border = Success.c600.color,
        borderMuted = Success.c500.color,
        contentMuted = Success.c800.color,
        content = Success.c1000.color,
        bg = Success.c300.color,
        bgActive = Success.c500.color;

  final Color border;
  final Color borderMuted;
  final Color contentMuted;
  final Color content;
  final Color bg;
  final Color bgActive;
}

class DangerTokens {
  DangerTokens()
      : border = Danger.c600.color,
        borderMuted = Danger.c500.color,
        contentMuted = Danger.c800.color,
        content = Danger.c1000.color,
        bg = Danger.c300.color,
        bgActive = Danger.c500.color;

  final Color border;
  final Color borderMuted;
  final Color contentMuted;
  final Color content;
  final Color bg;
  final Color bgActive;
}

class InfoTokens {
  InfoTokens()
      : border = Info.c600.color,
        borderMuted = Info.c500.color,
        contentMuted = Info.c800.color,
        content = Info.c1000.color,
        bg = Info.c300.color,
        bgActive = Info.c500.color;

  final Color border;
  final Color borderMuted;
  final Color contentMuted;
  final Color content;
  final Color bg;
  final Color bgActive;
}

extension CellulaColorExtensions on Color {
  Color getCellulaDisabledColorIfDisabled(bool enabled) {
    return enabled
        ? this
        : opacity == 0.0
            ? this
            : withOpacity(0.6);
  }
}
