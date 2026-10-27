import 'package:dco_mobile/core/widgets/dco_system_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final bottom in [24.0, 48.0, 0.0]) {
    testWidgets('consumes side/bottom insets once ($bottom)', (tester) async {
      const key = Key('content');
      late MediaQueryData inner;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              padding: EdgeInsets.fromLTRB(30, 32, 20, bottom),
              viewPadding: EdgeInsets.fromLTRB(30, 32, 20, bottom),
              viewInsets: bottom == 0
                  ? const EdgeInsets.only(bottom: 300)
                  : EdgeInsets.zero,
            ),
            child: DcoSystemUi(
              themeMode: ThemeMode.light,
              child: Builder(
                builder: (context) {
                  inner = MediaQuery.of(context);
                  return const SafeArea(
                    top: false,
                    child: SizedBox.expand(key: key),
                  );
                },
              ),
            ),
          ),
        ),
      );
      final rect = tester.getRect(find.byKey(key));
      expect(rect.left, 30);
      expect(rect.right, 780);
      expect(rect.bottom, 600 - bottom);
      expect(inner.padding, const EdgeInsets.only(top: 32));
      expect(inner.viewInsets.bottom, bottom == 0 ? 300 : 0);
    });
  }
  testWidgets('theme updates icons without requesting bar colors', (
    tester,
  ) async {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      await tester.pumpWidget(
        MaterialApp(
          home: DcoSystemUi(themeMode: mode, child: const SizedBox.expand()),
        ),
      );
      final style = tester
          .widget<AnnotatedRegion<SystemUiOverlayStyle>>(
            find.byType(AnnotatedRegion<SystemUiOverlayStyle>).first,
          )
          .value;
      expect(
        style.systemNavigationBarIconBrightness,
        mode == ThemeMode.dark ? Brightness.light : Brightness.dark,
      );
      expect(style.statusBarColor, isNull);
      expect(style.systemNavigationBarColor, isNull);
      expect(style.systemNavigationBarDividerColor, isNull);
    }
  });
}
