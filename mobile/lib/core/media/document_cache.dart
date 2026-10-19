import 'dart:io';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:path_provider/path_provider.dart';
import '../database/app_database.dart';
import 'media_api.dart';

/// Downloads into the current account's scope. Org bytes require a fresh
/// assignment check; downloaded files are removed with revoked vehicle data.
Future<String?> cacheDocument({
  required Dio dio,
  required AppDatabase db,
  required String userId,
  required String documentId,
  String? organizationId,
}) async {
  final row = await (db.select(
    db.documentRecords,
  )..where((r) => r.id.equals(documentId))).getSingleOrNull();
  if (row?.mediaId == null) return null;
  if (row!.localFilePath != null && await File(row.localFilePath!).exists()) {
    return row.localFilePath;
  }
  final url = organizationId == null
      ? (await DioMediaApi(dio).get(row.mediaId!)).downloadUrl
      : '/organizations/$organizationId/media/${row.mediaId}/content';
  if (url == null) return null;
  final response = await dio.get<List<int>>(
    url,
    options: Options(responseType: ResponseType.bytes),
  );
  final contentType = response.headers.value('content-type') ?? '';
  final extension = contentType.contains('pdf')
      ? 'pdf'
      : contentType.contains('png')
      ? 'png'
      : 'jpg';
  final root = await getApplicationSupportDirectory();
  final directory = Directory(
    '${root.path}/documents/$userId/${organizationId ?? 'personal'}/${row.vehicleId}',
  );
  await directory.create(recursive: true);
  final file = File('${directory.path}/${row.mediaId}.$extension');
  await file.writeAsBytes(response.data!);
  // Revocation may have removed the row while the download was in flight.
  final updated =
      await (db.update(db.documentRecords)
            ..where((r) => r.id.equals(documentId)))
          .write(DocumentRecordsCompanion(localFilePath: Value(file.path)));
  if (updated == 0) {
    await file.delete();
    return null;
  }
  return file.path;
}
