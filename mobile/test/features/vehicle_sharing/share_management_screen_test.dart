import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/features/vehicle_sharing/domain/entities/vehicle_share.dart';
import 'package:dco_mobile/features/vehicle_sharing/domain/repositories/vehicle_share_repository.dart';
import 'package:dco_mobile/features/vehicle_sharing/presentation/screens/share_management_screen.dart';
import 'package:dco_mobile/features/vehicle_sharing/providers.dart';
import 'package:dco_mobile/generated/app_localizations.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockShares extends Mock implements VehicleShareRepository {}

void main() {
  testWidgets('failed revoke shows error, no success, and allows retry', (
    tester,
  ) async {
    final repo = MockShares();
    when(() => repo.revokeShare(vehicleId: 'v', shareId: 's')).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: '/vehicles/v/shares/s'),
        type: DioExceptionType.badResponse,
        response: Response(requestOptions: RequestOptions(), statusCode: 500),
      ),
    );
    final detail = VehicleSharesDetail(
      vehicleId: 'v',
      vehicleName: 'Car',
      licensePlate: 'ABC',
      shares: [
        VehicleShare(
          id: 's',
          vehicleId: 'v',
          userId: 'u',
          grantedBy: 'owner',
          accessLevel: ShareAccessLevel.view,
          status: ShareStatus.active,
          createdAt: DateTime(2026),
          displayName: 'Shared user',
        ),
      ],
      pendingInvites: const [],
      limits: const ShareLimits(perVehicle: 2, total: 2),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vehicleShareRepositoryProvider.overrideWithValue(repo),
          vehicleSharesProvider('v').overrideWith((ref) async => detail),
        ],
        child: MaterialApp(
          theme: ThemeData(extensions: [DcoTokens.garageMinimalLight]),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ShareManagementScreen(vehicleId: 'v'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final s = AppLocalizations.of(
      tester.element(find.byType(ShareManagementScreen)),
    )!;
    Future<void> revoke() async {
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text(s.shareRevoke));
      await tester.pumpAndSettle();
      await tester.tap(find.text(s.shareRevokeAction));
      await tester.pumpAndSettle();
    }

    await revoke();
    expect(tester.takeException(), isNull);
    expect(find.text(s.shareErrorGeneric), findsOneWidget);
    expect(find.text(s.shareRevoked), findsNothing);
    await tester.tap(find.text(s.ok));
    await tester.pumpAndSettle();
    await revoke();
    verify(() => repo.revokeShare(vehicleId: 'v', shareId: 's')).called(2);
  });
}
