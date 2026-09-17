import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/entities/document.dart';

Document documentFromDrift(DocumentRecord row) {
  return Document(
    id: row.id,
    vehicleId: row.vehicleId,
    name: row.name,
    category: DocumentCategory.fromString(row.category),
    notes: row.notes,
    localFilePath: row.localFilePath,
    mediaId: row.mediaId,
    updatedAt: row.updatedAt,
    createdAt: row.createdAt,
  );
}

DocumentRecordsCompanion documentToCompanion(Document doc) {
  return DocumentRecordsCompanion.insert(
    id: doc.id,
    vehicleId: doc.vehicleId,
    name: doc.name,
    category: doc.category.storage,
    notes: Value(doc.notes),
    localFilePath: Value(doc.localFilePath),
    mediaId: Value(doc.mediaId),
    updatedAt: doc.updatedAt,
    createdAt: doc.createdAt,
  );
}
