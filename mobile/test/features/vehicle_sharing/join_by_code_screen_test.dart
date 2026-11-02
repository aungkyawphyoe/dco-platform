import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/core/widgets/dco_button.dart';
import 'package:dco_mobile/features/vehicle_sharing/domain/repositories/vehicle_share_repository.dart';
import 'package:dco_mobile/features/vehicle_sharing/presentation/screens/join_by_code_screen.dart';
import 'package:dco_mobile/features/vehicle_sharing/providers.dart';
import 'package:dco_mobile/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockShares extends Mock implements VehicleShareRepository {}

void main() {
  late MockShares repo;

  setUp(() {
    repo = MockShares();
    when(() => repo.previewCode(any())).thenAnswer((_) async => null);
  });

  Widget wrap({String? initialCode, ShareQrScanner? scan}) => ProviderScope(
    overrides: [vehicleShareRepositoryProvider.overrideWithValue(repo)],
    child: MaterialApp(
      locale: const Locale('en'),
      theme: ThemeData(extensions: [DcoTokens.garageMinimalLight]),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: JoinByCodeScreen(initialCode: initialCode, scanQrCode: scan),
    ),
  );

  String codeInField(WidgetTester tester) {
    final field = tester.widget<TextField>(find.byType(TextField));
    return field.controller!.text;
  }

  testWidgets('a second deep-link code replaces the previous one', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(initialCode: 'ABCD1234'));
    await tester.pumpAndSettle();
    expect(codeInField(tester), 'ABCD1234');

    await tester.pumpWidget(wrap(initialCode: 'WXYZ9876'));
    await tester.pumpAndSettle();

    expect(codeInField(tester), 'WXYZ9876');
  });

  testWidgets('a shared code pre-fills the field', (tester) async {
    await tester.pumpWidget(wrap(initialCode: 'ABCD1234'));
    await tester.pumpAndSettle();

    expect(codeInField(tester), 'ABCD1234');
  });

  testWidgets('scanning a QR payload fills the share code', (tester) async {
    await tester.pumpWidget(
      wrap(scan: (_) async => 'dco://vehicle/share/join?code=wxyz9876'),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('share-scan-qr')));
    await tester.pumpAndSettle();

    expect(codeInField(tester), 'WXYZ9876');
    final join = tester.widget<DcoButton>(
      find.widgetWithText(DcoButton, 'Join'),
    );
    expect(join.onPressed, isNotNull);
  });

  testWidgets('a scanned code can be joined', (tester) async {
    when(() => repo.joinByCode(any())).thenThrow(Exception('offline'));
    await tester.pumpWidget(wrap(scan: (_) async => 'WXYZ9876'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('share-scan-qr')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(DcoButton, 'Join'));
    await tester.pumpAndSettle();

    verify(() => repo.joinByCode('WXYZ9876')).called(1);
  });

  testWidgets('an unrelated QR payload shows an inline error', (tester) async {
    await tester.pumpWidget(
      wrap(scan: (_) async => 'https://example.com/not-a-share'),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('share-scan-qr')));
    await tester.pumpAndSettle();

    expect(codeInField(tester), isEmpty);
    expect(find.text('That code is not a vehicle share code.'), findsOneWidget);
  });

  testWidgets('backing out of the scanner leaves the code untouched', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(initialCode: 'ABCD1234', scan: (_) async => null),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('share-scan-qr')));
    await tester.pumpAndSettle();

    expect(codeInField(tester), 'ABCD1234');
    expect(find.text('That code is not a vehicle share code.'), findsNothing);
  });
}
