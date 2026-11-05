import 'package:dco_mobile/core/providers.dart';
import 'package:dco_mobile/core/theme/dco_theme.dart';
import 'package:dco_mobile/features/garage/domain/entities/vehicle.dart';
import 'package:dco_mobile/features/garage/providers.dart';
import 'package:dco_mobile/features/maintenance/domain/entities/plan_item.dart';
import 'package:dco_mobile/features/maintenance/domain/repositories/maintenance_repository.dart';
import 'package:dco_mobile/features/maintenance/presentation/screens/plan_item_form_screen.dart';
import 'package:dco_mobile/features/settings/providers.dart';
import 'package:dco_mobile/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'suggested_items_scope_test.dart' as fixtures;

class Repository implements MaintenanceRepository {
  final item = PlanItem(
    id: 'plan',
    vehicleId: 'car',
    name: 'Oil change',
    enabled: true,
    nextDueMileage: 15000,
    nextDueOn: DateTime(2026, 12, 1),
    intervalDays: 7,
    intervalDistance: 5000,
    warningDays: 9,
    warningDistance: 123,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
  PlanItemDraft? saved;
  @override
  Future<PlanItem?> getPlanItem(String id) async => item;
  @override
  Future<PlanItem> updatePlanItem({
    required String userId,
    required Vehicle vehicle,
    required String planItemId,
    required PlanItemDraft draft,
  }) async {
    saved = draft;
    return item;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  for (final clearDate in [false, true]) {
    testWidgets(
      'routed edit uses a sheet and saves applicable repeats clearDate=$clearDate',
      (tester) async {
        final repo = Repository();
        final editing = ValueNotifier(true);
        addTearDown(editing.dispose);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              maintenanceRepositoryProvider.overrideWithValue(repo),
              lengthUnitProvider.overrideWithValue(MileageUnit.km),
              activeVehicleProvider.overrideWith(
                (ref) => Stream.value(fixtures.vehicle('car', 'user')),
              ),
            ],
            child: MaterialApp(
              theme: buildDcoTheme(Brightness.light),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: ValueListenableBuilder<bool>(
                valueListenable: editing,
                builder: (_, open, _) => Navigator(
                  pages: [
                    const MaterialPage<void>(
                      child: Scaffold(body: Text('Plan')),
                    ),
                    if (open) const PlanItemFormPage(planItemId: 'plan'),
                  ],
                  onDidRemovePage: (_) => editing.value = false,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final form = find.byType(PlanItemFormScreen);
        expect(
          ModalRoute.of(tester.element(form)),
          isA<ModalBottomSheetRoute<void>>(),
        );
        expect(find.text('Oil change'), findsOneWidget);
        if (clearDate) {
          await tester.tap(find.byKey(const Key('plan-item-clear-date')));
          await tester.pumpAndSettle();
          expect(find.byKey(const Key('plan-item-repeat-time')), findsNothing);
        }
        // The footer stays usable when the keyboard reduces the sheet's space.
        tester.view.viewInsets = const FakeViewPadding(bottom: 280);
        addTearDown(tester.view.resetViewInsets);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await ProviderScope.containerOf(
          tester.element(form),
        ).read(activeVehicleProvider.future);
        await tester.tap(find.byKey(const Key('plan-item-save')));
        await tester.pumpAndSettle();
        expect(repo.saved, isNotNull);
        expect(repo.saved!.timeUnit, clearDate ? null : 'days');
        expect(repo.saved!.timeCount, clearDate ? null : 7);
        expect(repo.saved!.intervalDistance, isNotNull);
        expect(repo.saved!.warningDays, isNull);
        expect(repo.saved!.warningDistance, isNull);
        expect(find.byType(PlanItemFormScreen), findsNothing);
      },
    );
  }
}
