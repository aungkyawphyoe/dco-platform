/// Semantic layout aliases over the generated spacing tokens.
///
/// Values stay on the 4/8 grid and compose from `DcoTokens.space`
/// (`space.1` = 4 … `space.7` = 48). Widgets use these names instead of
/// raw numbers so the grid stays enforceable in review.
abstract final class DcoLayout {
  DcoLayout._();

  /// Screen gutter. Matches `space.4`.
  static const double screenPadding = 16;

  /// Default card padding. Matches `space.4`.
  static const double cardPadding = 16;

  /// Priority card / hero padding. Matches `space.5`.
  static const double cardPaddingLoose = 24;

  /// Gap between unrelated blocks. Matches `space.5`.
  static const double sectionGap = 24;

  /// Gap between major regions. Matches `space.6`.
  static const double blockGap = 32;

  /// Gap inside a cluster (label to value). Matches `space.2`.
  static const double rowGap = 8;

  /// Minimum tap target.
  static const double minTapTarget = 48;

  /// Clearance for a pinned bottom bar on a full-screen route.
  static const double bottomBarInset = 96;
}
