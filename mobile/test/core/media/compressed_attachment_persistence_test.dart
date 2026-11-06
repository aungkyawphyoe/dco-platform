import 'dart:io';

import 'package:dco_mobile/core/database/app_database.dart';
import 'package:dco_mobile/core/media/attachment_image_compressor.dart';
import 'package:dco_mobile/core/sync/outbox_writer.dart';
import 'package:dco_mobile/features/documents/data/repositories/document_repository_impl.dart';
import 'package:dco_mobile/features/documents/domain/entities/document.dart';
import 'package:dco_mobile/features/expenses/data/repositories/expense_repository_impl.dart';
import 'package:dco_mobile/features/expenses/domain/entities/expense.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('compressed bytes persist locally and queue metadata without a network', () async {
    final directory = await Directory.systemTemp.createTemp('offline-attachments');
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(() async {
      await db.close();
      await directory.delete(recursive: true);
    });
    final source = await File('${directory.path}/source.png').writeAsBytes(
      img.encodePng(img.Image(width: 100, height: 50, numChannels: 4)),
    );
    final compressed = await const AttachmentImageCompressor().compress(
      source, Directory('${directory.path}/documents'),
    );
    final bytes = await compressed.readAsBytes();
    final outbox = OutboxWriter(db);
    final documents = DocumentRepositoryImpl(db: db, outbox: outbox);
    final expenses = ExpenseRepositoryImpl(db: db, outbox: outbox);
    final document = await documents.add(
      userId: 'owner', vehicleId: 'vehicle',
      draft: DocumentDraft(name: 'Receipt', category: DocumentCategory.receipt,
        localFilePath: compressed.path,
        links: const [DocumentLink(kind: 'service_record', recordId: 'service'),
          DocumentLink(kind: 'fuel_log', recordId: 'fuel')]),
    );
    final expense = await expenses.add(
      userId: 'owner', vehicleId: 'vehicle',
      draft: ExpenseDraft(category: ExpenseCategory.parking, amount: 100,
        incurredOn: DateTime.now(), receiptLocalPath: compressed.path),
    );
    expect((await documents.getById(document.id))!.localFilePath, compressed.path);
    expect((await expenses.getById(expense.id))!.receiptLocalPath, compressed.path);
    expect(await compressed.readAsBytes(), orderedEquals(bytes));
    expect(await source.exists(), isTrue);
    final queued = await db.select(db.outboxEntries).get();
    expect(queued.map((row) => row.entityType), containsAll(['document', 'expense']));
  });
}
