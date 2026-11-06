import 'dart:async';
import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:dco_mobile/core/media/attachment_image_compressor.dart';
import 'package:dco_mobile/core/providers.dart';
import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/core/widgets/dco_text_field.dart';
import 'package:dco_mobile/features/documents/domain/entities/document.dart';
import 'package:dco_mobile/features/documents/presentation/screens/document_form_screen.dart';
import 'package:dco_mobile/features/documents/presentation/widgets/log_attachments.dart';
import 'package:dco_mobile/features/documents/providers.dart';
import 'package:dco_mobile/features/expenses/presentation/screens/expense_form_screen.dart';
import 'package:dco_mobile/features/garage/access_provider.dart';
import 'package:dco_mobile/features/garage/domain/entities/vehicle.dart';
import 'package:dco_mobile/features/garage/providers.dart';
import 'package:dco_mobile/features/maintenance/presentation/widgets/sticky_actions.dart';
import 'package:dco_mobile/features/parts/providers.dart';
import 'package:dco_mobile/features/settings/domain/entities/user_preferences.dart';
import 'package:dco_mobile/features/settings/providers.dart';
import 'package:dco_mobile/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

class PendingPicker extends AttachmentImagePicker {
  final pending = Completer<File?>();
  int calls = 0;
  @override
  Future<File?> pick(ImageSource source, {required String folder}) {
    calls++;
    return pending.future;
  }
}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  final vehicle = Vehicle(
    id: 'car',
    userId: 'owner',
    name: 'Car',
    make: 'Toyota',
    model: 'Camry',
    year: 2024,
    licensePlate: 'ABC',
    fuelType: FuelType.petrol,
    mileage: 100,
    mileageUnit: MileageUnit.km,
    archived: false,
    updatedAt: DateTime(2026),
    createdAt: DateTime(2026),
  );

  for (final screen in ['document', 'expense', 'service_record', 'fuel_log']) {
    for (final outcome in ['failure', 'cancel', 'success', 'leave']) {
      testWidgets('$screen blocks saving while processing; handles $outcome', (
        tester,
      ) async {
        final picker = PendingPicker();
        final logKey = GlobalKey<LogAttachmentsState>();
        final isLog = screen.endsWith('record') || screen == 'fuel_log';
        final body = switch (screen) {
          'document' => const DocumentFormScreen(),
          'expense' => const ExpenseFormScreen(),
          _ => Scaffold(
            body: LogAttachments(
              key: logKey,
              kind: screen,
              category: DocumentCategory.receipt,
              vehicleId: 'car',
              onChanged: () {},
            ),
          ),
        };
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              attachmentImagePickerProvider.overrideWithValue(picker),
              activeVehicleProvider.overrideWith(
                (ref) => Stream.value(vehicle),
              ),
              vehicleByIdProvider(
                'car',
              ).overrideWith((ref) => Stream.value(vehicle)),
              vehicleAccessProvider(
                vehicle,
              ).overrideWithValue(VehicleAccess.of(vehicle, 'owner')),
              driverOrganizationIdProvider.overrideWithValue(null),
              currencyProvider.overrideWithValue(AppCurrency.mmk),
              vehiclePartsProvider.overrideWith((ref) => Stream.value([])),
              documentsForVehicleProvider(
                'car',
              ).overrideWith((ref) => Stream.value([])),
            ],
            child: MaterialApp(
              theme: ThemeData(extensions: [DcoTokens.garageMinimalLight]),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              locale: const Locale('en'),
              home: body,
            ),
          ),
        );
        await tester.pumpAndSettle();
        final attach = find.text(
          isLog
              ? 'Upload file'
              : screen == 'expense'
              ? 'Add receipt photo'
              : 'Attach file',
        );
        if (!isLog) {
          await tester.scrollUntilVisible(
            attach,
            300,
            scrollable: find
                .descendant(
                  of: find.byType(ListView).first,
                  matching: find.byType(Scrollable),
                )
                .first,
          );
        }
        await tester.tap(attach);
        await tester.pumpAndSettle();
        await tester.tap(find.text(isLog ? 'Choose image' : 'Photo library'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(picker.calls, 1);
        expect(find.byType(LinearProgressIndicator), findsOneWidget);
        if (isLog) {
          await expectLater(
            logKey.currentState!.save('owner', 'record'),
            throwsStateError,
          );
        } else {
          expect(
            tester
                .widget<DcoStickyActions>(find.byType(DcoStickyActions))
                .onPrimary,
            isNull,
          );
        }
        File? generated;
        Directory? directory;
        if (outcome == 'success' || outcome == 'leave') {
          await tester.runAsync(() async {
            directory = await Directory.systemTemp.createTemp('picked-image');
            generated = await File(
              '${directory!.path}/prepared.jpg',
            ).writeAsBytes(img.encodeJpg(img.Image(width: 20, height: 20)));
          });
        }
        if (outcome == 'leave') {
          await tester.pumpWidget(const SizedBox.shrink());
        }
        await tester.runAsync(() async {
          if (outcome == 'failure') {
            picker.pending.completeError(const FormatException('bad image'));
          } else {
            picker.pending.complete(generated);
          }
          // Flush real file IO outside the widget test's fake clock.
          await Future<void>.delayed(const Duration(milliseconds: 50));
        });
        await tester.pumpAndSettle();
        expect(find.byType(LinearProgressIndicator), findsNothing);
        expect(
          find.text(
            'Could not prepare this image. Please choose another image.',
          ),
          outcome == 'failure' ? findsOneWidget : findsNothing,
        );
        if (outcome == 'success') {
          expect(generated!.existsSync(), isTrue);
          if (isLog) expect(logKey.currentState!.hasChanges, isTrue);
        }
        if (!isLog && outcome != 'leave') {
          final actions = tester.widget<DcoStickyActions>(
            find.byType(DcoStickyActions),
          );
          expect(actions.onPrimary, isNotNull);
          // The button must invoke validation, rather than return a callback.
          actions.onPrimary!();
          await tester.pump();
          final field = find.byKey(
            Key(screen == 'document' ? 'document-name' : 'expense-category'),
          );
          await tester.scrollUntilVisible(
            field,
            -300,
            scrollable: find
                .descendant(
                  of: find.byType(ListView).first,
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          expect(tester.widget<DcoTextField>(field).errorText, isNotNull);
        }
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          if (generated != null) expect(await generated!.exists(), isFalse);
          if (directory != null) await directory!.delete(recursive: true);
        });
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
