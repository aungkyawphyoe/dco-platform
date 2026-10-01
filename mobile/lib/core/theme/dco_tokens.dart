import 'package:flutter/material.dart';

part 'dco_tokens.g.dart';

/// 1:1 map of `docs/theme/garage-minimal-{dark,light}.json` (generated values in
/// `dco_tokens.g.dart`; run `node tools/generate-theme.mjs` after editing them).
/// If a screen needs a new color, add it there first — no one-off hex in widgets.
@immutable
class DcoTokens extends ThemeExtension<DcoTokens> {
  const DcoTokens({
    required this.background,
    required this.text,
    required this.button,
    required this.icon,
    required this.border,
    required this.status,
    required this.feedback,
    required this.input,
    required this.chart,
    required this.radius,
    required this.space,
    required this.motion,
    required this.shadows,
  });

  final DcoBackground background;
  final DcoTextColors text;
  final DcoButtons button;
  final DcoIconColors icon;
  final DcoBorders border;
  final DcoStatus status;
  final DcoFeedback feedback;
  final DcoInputColors input;
  final DcoChartColors chart;
  final DcoRadius radius;
  final DcoSpace space;
  final DcoMotion motion;
  final DcoShadows shadows;

  /// Values generated from `docs/theme/garage-minimal-dark.json`.
  static const garageMinimalDark = DcoTokenValues.garageMinimalDark;

  /// Values generated from `docs/theme/garage-minimal-light.json`.
  static const garageMinimalLight = DcoTokenValues.garageMinimalLight;

  @override
  DcoTokens copyWith({
    DcoBackground? background,
    DcoTextColors? text,
    DcoButtons? button,
    DcoIconColors? icon,
    DcoBorders? border,
    DcoStatus? status,
    DcoFeedback? feedback,
    DcoInputColors? input,
    DcoChartColors? chart,
    DcoRadius? radius,
    DcoSpace? space,
    DcoMotion? motion,
    DcoShadows? shadows,
  }) {
    return DcoTokens(
      background: background ?? this.background,
      text: text ?? this.text,
      button: button ?? this.button,
      icon: icon ?? this.icon,
      border: border ?? this.border,
      status: status ?? this.status,
      feedback: feedback ?? this.feedback,
      input: input ?? this.input,
      chart: chart ?? this.chart,
      radius: radius ?? this.radius,
      space: space ?? this.space,
      motion: motion ?? this.motion,
      shadows: shadows ?? this.shadows,
    );
  }

  @override
  DcoTokens lerp(ThemeExtension<DcoTokens>? other, double t) {
    if (other is! DcoTokens) return this;
    return t < 0.5 ? this : other;
  }
}

@immutable
class DcoBackground {
  const DcoBackground({
    required this.primary,
    required this.secondary,
    required this.card,
    required this.input,
    required this.nav,
    required this.navActive,
    required this.overlay,
    required this.skeleton,
  });

  final Color primary;
  final Color secondary;
  final Color card;
  final Color input;
  final Color nav;

  /// Selected pill fill inside the floating nav bar (gold-tinted dark /
  /// parchment light).
  final Color navActive;
  final Color overlay;
  final Color skeleton;
}

@immutable
class DcoTextColors {
  const DcoTextColors({
    required this.primary,
    required this.secondary,
    required this.tertiary,
    required this.caption,
    required this.accent,
    required this.onAccent,
    required this.disabled,
    required this.link,
    required this.inverse,
  });

  final Color primary;
  final Color secondary;
  final Color tertiary;
  final Color caption;
  final Color accent;
  final Color onAccent;
  final Color disabled;
  final Color link;
  final Color inverse;
}

@immutable
class DcoButtonColors {
  const DcoButtonColors({
    required this.background,
    required this.backgroundHover,
    required this.backgroundPressed,
    required this.backgroundDisabled,
    required this.text,
    required this.textDisabled,
    required this.border,
  });

  final Color background;
  final Color backgroundHover;
  final Color backgroundPressed;
  final Color backgroundDisabled;
  final Color text;
  final Color textDisabled;
  final Color border;
}

@immutable
class DcoButtons {
  const DcoButtons({
    required this.primary,
    required this.secondary,
    required this.tertiary,
    required this.destructive,
  });

  final DcoButtonColors primary;
  final DcoButtonColors secondary;
  final DcoButtonColors tertiary;
  final DcoButtonColors destructive;
}

@immutable
class DcoIconColors {
  const DcoIconColors({
    required this.active,
    required this.inactive,
    required this.onAccent,
    required this.inverse,
  });

  final Color active;
  final Color inactive;
  final Color onAccent;
  final Color inverse;
}

@immutable
class DcoBorders {
  const DcoBorders({
    required this.subtle,
    required this.defaultColor,
    required this.divider,
    required this.highlight,
    required this.focus,
  });

  final Color subtle;
  final Color defaultColor;
  final Color divider;
  final Color highlight;
  final Color focus;
}

@immutable
class DcoStatus {
  const DcoStatus({
    required this.successFg,
    required this.successBg,
    required this.warningFg,
    required this.warningBg,
    required this.dangerFg,
    required this.dangerBg,
    required this.infoFg,
    required this.infoBg,
  });

  final Color successFg;
  final Color successBg;
  final Color warningFg;
  final Color warningBg;
  final Color dangerFg;
  final Color dangerBg;
  final Color infoFg;
  final Color infoBg;
}

@immutable
class DcoFeedback {
  const DcoFeedback({
    required this.overdue,
    required this.dueSoon,
    required this.healthy,
    required this.queuedSync,
  });

  final Color overdue;
  final Color dueSoon;
  final Color healthy;
  final Color queuedSync;
}

@immutable
class DcoInputColors {
  const DcoInputColors({
    required this.background,
    required this.border,
    required this.borderFocus,
    required this.placeholder,
    required this.errorBorder,
  });

  final Color background;
  final Color border;
  final Color borderFocus;
  final Color placeholder;
  final Color errorBorder;
}

@immutable
class DcoChartColors {
  const DcoChartColors({
    required this.fuel,
    required this.maintenance,
    required this.insurance,
    required this.parking,
    required this.tolls,
    required this.parts,
    required this.other,
  });

  final Color fuel;
  final Color maintenance;
  final Color insurance;
  final Color parking;
  final Color tolls;
  final Color parts;
  final Color other;
}

@immutable
class DcoRadius {
  const DcoRadius({
    required this.sm,
    required this.md,
    required this.lg,
    required this.xl,
    required this.full,
  });

  final double sm;
  final double md;
  final double lg;
  final double xl;
  final double full;
}

@immutable
class DcoSpace {
  const DcoSpace({
    required this.s1,
    required this.s2,
    required this.s3,
    required this.s4,
    required this.s5,
    required this.s6,
    required this.s7,
  });

  final double s1;
  final double s2;
  final double s3;
  final double s4;
  final double s5;
  final double s6;
  final double s7;
}

@immutable
class DcoMotion {
  const DcoMotion({required this.fast, required this.base, required this.slow});

  final int fast;
  final int base;
  final int slow;
}

@immutable
class DcoShadows {
  const DcoShadows({required this.card, required this.elevated});

  final List<BoxShadow> card;
  final List<BoxShadow> elevated;
}

extension DcoTokensContext on BuildContext {
  DcoTokens get tokens => Theme.of(this).extension<DcoTokens>()!;
}
