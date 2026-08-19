import 'package:flutter/material.dart';

/// 1:1 map of `docs/theme/garage-minimal-dark.json`.
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

  static const garageMinimalDark = DcoTokens(
    background: DcoBackground(
      primary: Color(0xFF101B22),
      secondary: Color(0xFF1A2832),
      card: Color(0xFF1E2D38),
      input: Color(0xFF16242D),
      nav: Color(0xFF101B22),
      overlay: Color(0xB8101B22),
      skeleton: Color(0xFF243441),
    ),
    text: DcoTextColors(
      primary: Color(0xFFFFFFFF),
      secondary: Color(0xFFA8B6C1),
      tertiary: Color(0xFF6C7D8A),
      caption: Color(0xFF8A9BA8),
      accent: Color(0xFFEEB757),
      onAccent: Color(0xFF101B22),
      disabled: Color(0xFF6C7D8A),
      link: Color(0xFFEEB757),
      inverse: Color(0xFF101B22),
    ),
    button: DcoButtons(
      primary: DcoButtonColors(
        background: Color(0xFFEEB757),
        backgroundHover: Color(0xFFF2C36A),
        backgroundPressed: Color(0xFFD4A44A),
        backgroundDisabled: Color(0xFF5C5340),
        text: Color(0xFF101B22),
        textDisabled: Color(0xFFA8B6C1),
        border: Color(0x00000000),
      ),
      secondary: DcoButtonColors(
        background: Color(0xFF1E2D38),
        backgroundHover: Color(0xFF243441),
        backgroundPressed: Color(0xFF16242D),
        backgroundDisabled: Color(0xFF1A2832),
        text: Color(0xFFFFFFFF),
        textDisabled: Color(0xFF6C7D8A),
        border: Color(0xFF6C7D8A),
      ),
      tertiary: DcoButtonColors(
        background: Color(0x00000000),
        backgroundHover: Color(0xFF1A2832),
        backgroundPressed: Color(0xFF16242D),
        backgroundDisabled: Color(0x00000000),
        text: Color(0xFFEEB757),
        textDisabled: Color(0xFF6C7D8A),
        border: Color(0x00000000),
      ),
      destructive: DcoButtonColors(
        background: Color(0x00000000),
        backgroundHover: Color(0xFF3A2424),
        backgroundPressed: Color(0xFF3A2424),
        backgroundDisabled: Color(0x00000000),
        text: Color(0xFFE07A6C),
        textDisabled: Color(0xFF6C7D8A),
        border: Color(0xFFE07A6C),
      ),
    ),
    icon: DcoIconColors(
      active: Color(0xFFEEB757),
      inactive: Color(0xFF6C7D8A),
      onAccent: Color(0xFF101B22),
      inverse: Color(0xFFFFFFFF),
    ),
    border: DcoBorders(
      subtle: Color(0xFF1E2D38),
      defaultColor: Color(0xFF6C7D8A),
      divider: Color(0xFF2A3C48),
      highlight: Color(0xFFEEB757),
      focus: Color(0xFFEEB757),
    ),
    status: DcoStatus(
      successFg: Color(0xFF7CB89A),
      successBg: Color(0x227CB89A),
      warningFg: Color(0xFFE39A3C),
      warningBg: Color(0x22E39A3C),
      dangerFg: Color(0xFFE07A6C),
      dangerBg: Color(0x22E07A6C),
      infoFg: Color(0xFF7AA0B8),
      infoBg: Color(0x227AA0B8),
    ),
    feedback: DcoFeedback(
      overdue: Color(0xFFE07A6C),
      dueSoon: Color(0xFFE39A3C),
      healthy: Color(0xFF7CB89A),
      queuedSync: Color(0xFF7AA0B8),
    ),
    input: DcoInputColors(
      background: Color(0xFF16242D),
      border: Color(0xFF6C7D8A),
      borderFocus: Color(0xFFEEB757),
      placeholder: Color(0xFF6C7D8A),
      errorBorder: Color(0xFFE07A6C),
    ),
    chart: DcoChartColors(
      fuel: Color(0xFFE39A3C),
      maintenance: Color(0xFF7AA0B8),
      insurance: Color(0xFF8B9CCF),
      parking: Color(0xFF8A9BA8),
      tolls: Color(0xFFA8B6C1),
      parts: Color(0xFF7CB89A),
      other: Color(0xFF6C7D8A),
    ),
    radius: DcoRadius(sm: 4, md: 8, lg: 12, xl: 16, full: 999),
    space: DcoSpace(
      s1: 4,
      s2: 8,
      s3: 12,
      s4: 16,
      s5: 24,
      s6: 32,
      s7: 48,
    ),
    motion: DcoMotion(fast: 120, base: 180, slow: 280),
  );

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
    required this.overlay,
    required this.skeleton,
  });

  final Color primary;
  final Color secondary;
  final Color card;
  final Color input;
  final Color nav;
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
  const DcoMotion({
    required this.fast,
    required this.base,
    required this.slow,
  });

  final int fast;
  final int base;
  final int slow;
}

extension DcoTokensContext on BuildContext {
  DcoTokens get tokens => Theme.of(this).extension<DcoTokens>()!;
}
