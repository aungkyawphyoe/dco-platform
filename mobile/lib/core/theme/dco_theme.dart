import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'dco_tokens.dart';

ThemeData buildDcoTheme() {
  const tokens = DcoTokens.garageMinimalDark;
  final scheme = ColorScheme.dark(
    primary: tokens.text.accent,
    onPrimary: tokens.text.onAccent,
    secondary: tokens.background.secondary,
    onSecondary: tokens.text.primary,
    error: tokens.status.dangerFg,
    onError: tokens.text.primary,
    surface: tokens.background.card,
    onSurface: tokens.text.primary,
    outline: tokens.border.defaultColor,
    outlineVariant: tokens.border.divider,
  );

  final barlowTitle = GoogleFonts.barlow(
    fontWeight: FontWeight.w600,
    color: tokens.text.primary,
  );
  final plexBody = GoogleFonts.ibmPlexSans(
    fontWeight: FontWeight.w400,
    color: tokens.text.primary,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: tokens.background.primary,
    canvasColor: tokens.background.primary,
    cardColor: tokens.background.card,
    dividerColor: tokens.border.divider,
    extensions: const [tokens],
    textTheme: TextTheme(
      displaySmall: barlowTitle.copyWith(fontSize: 28, height: 34 / 28, letterSpacing: -0.3),
      titleLarge: barlowTitle.copyWith(fontSize: 20, height: 26 / 20),
      titleMedium: barlowTitle.copyWith(fontSize: 18, height: 24 / 18),
      bodyLarge: plexBody.copyWith(fontSize: 16, height: 24 / 16),
      bodyMedium: plexBody.copyWith(fontSize: 16, height: 24 / 16),
      labelLarge: GoogleFonts.ibmPlexSans(
        fontWeight: FontWeight.w500,
        fontSize: 13,
        height: 18 / 13,
        letterSpacing: 0.2,
        color: tokens.text.primary,
      ),
      bodySmall: GoogleFonts.ibmPlexSans(
        fontWeight: FontWeight.w400,
        fontSize: 12,
        height: 16 / 12,
        color: tokens.text.caption,
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: tokens.background.primary,
      foregroundColor: tokens.text.primary,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: barlowTitle.copyWith(fontSize: 20, height: 26 / 20),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: tokens.background.nav,
      elevation: 0,
      height: 72,
      indicatorColor: Colors.transparent,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? tokens.icon.active : tokens.icon.inactive,
          size: 24,
        );
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return GoogleFonts.ibmPlexSans(
          fontWeight: FontWeight.w500,
          fontSize: 12,
          color: selected ? tokens.icon.active : tokens.icon.inactive,
        );
      }),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: tokens.input.background,
      hintStyle: GoogleFonts.ibmPlexSans(color: tokens.input.placeholder),
      labelStyle: GoogleFonts.ibmPlexSans(color: tokens.text.secondary),
      errorStyle: GoogleFonts.ibmPlexSans(color: tokens.status.dangerFg),
      contentPadding: EdgeInsets.symmetric(
        horizontal: tokens.space.s4,
        vertical: tokens.space.s3,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(tokens.radius.md),
        borderSide: BorderSide(color: tokens.input.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(tokens.radius.md),
        borderSide: BorderSide(color: tokens.input.borderFocus, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(tokens.radius.md),
        borderSide: BorderSide(color: tokens.input.errorBorder),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(tokens.radius.md),
        borderSide: BorderSide(color: tokens.input.errorBorder, width: 2),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: tokens.background.secondary,
      contentTextStyle: plexBody.copyWith(color: tokens.text.primary),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
