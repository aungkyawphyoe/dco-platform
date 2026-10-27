import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/dco_tokens.dart';

/// Keeps the OS status/navigation bars in sync with the active theme.
/// Lives inside `MaterialApp.router`'s builder so it reacts to live
/// `platformBrightness` changes while the theme mode is "system".
class DcoSystemUi extends StatelessWidget {
  const DcoSystemUi({super.key, required this.themeMode, required this.child});

  final ThemeMode themeMode;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final platformDark =
        MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final isDark = switch (themeMode) {
      ThemeMode.system => platformDark,
      ThemeMode.dark => true,
      ThemeMode.light => false,
    };
    final tokens = isDark
        ? DcoTokens.garageMinimalDark
        : DcoTokens.garageMinimalLight;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarIconBrightness: isDark
            ? Brightness.light
            : Brightness.dark,
      ),
      // Paint behind system bars in Flutter. SafeArea consumes side/bottom
      // padding once; AppBar and full-screen auth layouts handle the top.
      child: ColoredBox(
        color: tokens.background.primary,
        child: SafeArea(top: false, child: child ?? const SizedBox.shrink()),
      ),
    );
  }
}
