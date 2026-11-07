import 'dart:async';
import 'package:dco_mobile/core/database/app_database.dart';
import 'package:drift/native.dart';
import 'package:dio/dio.dart';
import 'package:dco_mobile/core/providers.dart';
import 'package:dco_mobile/core/theme/dco_theme.dart';
import 'package:dco_mobile/core/widgets/dco_filter_chip.dart';
import 'package:dco_mobile/features/documents/domain/entities/document.dart';
import 'package:dco_mobile/features/documents/presentation/screens/documents_screen.dart';
import 'package:dco_mobile/features/documents/providers.dart';
import 'package:dco_mobile/features/garage/access_provider.dart';
import 'package:dco_mobile/features/garage/providers.dart';
import 'package:dco_mobile/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import '../maintenance/suggested_items_scope_test.dart' as fixtures;

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  test(
    'file types use case-insensitive extensions and MIME types, not names',
    () {
      expect(
        DocumentFileType.fromPath('/docs/receipt.PDF'),
        DocumentFileType.pdf,
      );
      expect(
        DocumentFileType.fromPath('/docs/photo.HEIC'),
        DocumentFileType.photo,
      );
      expect(
        DocumentFileType.fromContentType('image/jpeg'),
        DocumentFileType.photo,
      );
      expect(
        DocumentFileType.fromContentType('application/pdf; charset=binary'),
        DocumentFileType.pdf,
      );
      expect(DocumentFileType.fromPath(null), isNull);
      expect(DocumentFileType.fromPath('/docs/unknown'), isNull);
    },
  );

  test('synced file types are cached for offline filtering', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final dio = Dio();
    var requests = 0;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests++;
          handler.resolve(
            Response(
              requestOptions: options,
              data: {'content_type': 'application/pdf'},
              statusCode: 200,
            ),
          );
        },
      ),
    );
    final container = ProviderContainer(
      overrides: [
        recordDatabaseProvider.overrideWithValue(db),
        currentUserIdProvider.overrideWithValue('user'),
        driverOrganizationIdProvider.overrideWithValue(null),
        dioProvider.overrideWithValue(dio),
      ],
    );
    final loaded = Completer<DocumentFileType>();
    final subscription = container.listen(documentFileTypeProvider('remote'), (_, next) {
      if (next.valueOrNull != null && !loaded.isCompleted) loaded.complete(next.valueOrNull!);
    });
    try {
      expect(await loaded.future.timeout(const Duration(seconds: 5)), DocumentFileType.pdf);
      expect(requests, 1);
      container.invalidate(documentFileTypeProvider('remote'));
      expect(
        await container.read(documentFileTypeProvider('remote').future),
        DocumentFileType.pdf,
      );
      expect(
        requests,
        1,
        reason: 'cached metadata must not need another request',
      );
    } finally {
      subscription.close();
      container.dispose();
      await db.close();
      dio.close();
    }
  });

  for (final brightness in Brightness.values) {
    for (final language in ['en', 'my']) {
      testWidgets(
        'document chips filter $brightness $language on a narrow screen',
        (tester) async {
          tester.view.physicalSize = const Size(375, 812);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final car = fixtures.vehicle('car', 'user');
          Document doc(String id, {String? path, String? media}) => Document(
            id: id,
            vehicleId: 'car',
            name: id,
            category: DocumentCategory.receipt,
            localFilePath: path,
            mediaId: media,
            createdAt: DateTime(2026, 11, 7),
            updatedAt: DateTime(2026, 11, 7),
          );
          final docs = [
            doc('Registration PDF', path: '/tmp/registration.PDF'),
            doc('Car photo', media: 'photo'),
            doc('Cloud invoice', media: 'pdf'),
            doc('Details only'),
          ];
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                activeVehicleProvider.overrideWith((ref) => Stream.value(car)),
                vehicleAccessProvider(
                  car,
                ).overrideWithValue(VehicleAccess.of(car, 'user')),
                driverOrganizationIdProvider.overrideWithValue(null),
                vehicleDocumentsProvider.overrideWith(
                  (ref) => Stream.value(docs),
                ),
                documentStorageProvider.overrideWith(
                  (ref) => Stream.value(null),
                ),
                documentFileTypeProvider(
                  'photo',
                ).overrideWith((ref) => Stream.value(DocumentFileType.photo)),
                documentFileTypeProvider(
                  'pdf',
                ).overrideWith((ref) => Stream.value(DocumentFileType.pdf)),
                documentUploadErrorProvider(
                  '/tmp/registration.PDF',
                ).overrideWith((ref) => Stream.value(null)),
                for (final d in docs)
                  recordAdminLockProvider(
                    'document:${d.id}',
                  ).overrideWith((ref) => Stream.value(false)),
              ],
              child: MaterialApp(
                theme: buildDcoTheme(brightness),
                locale: Locale(language),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: const DocumentsScreen(),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final s = AppLocalizations.of(
            tester.element(find.byType(DocumentsScreen)),
          )!;
          expect(find.text('Details only'), findsOneWidget);
          expect(find.byType(DcoFilterChip), findsNWidgets(3));
          await tester.tap(find.text(s.documentsFilterPhotos));
          await tester.pumpAndSettle();
          expect(find.text('Car photo'), findsOneWidget);
          expect(find.text('Registration PDF'), findsNothing);
          expect(find.text('Cloud invoice'), findsNothing);
          expect(find.text('Details only'), findsNothing);
          await tester.tap(find.text('PDF'));
          await tester.pumpAndSettle();
          expect(find.text('Registration PDF'), findsOneWidget);
          expect(find.text('Cloud invoice'), findsOneWidget);
          expect(find.text('Car photo'), findsNothing);
          await tester.tap(find.text(s.documentsFilterAll));
          await tester.pumpAndSettle();
          expect(find.text('Car photo'), findsOneWidget);
          expect(find.text('Details only'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
}
