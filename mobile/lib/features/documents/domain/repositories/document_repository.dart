import '../entities/document.dart';

abstract class DocumentRepository {
  Stream<List<Document>> watchForVehicle(String vehicleId);
  Future<Document?> getById(String id);
  Future<Document> add({
    required String userId,
    required String vehicleId,
    required DocumentDraft draft,
  });
  Future<Document> update({
    required String userId,
    required String documentId,
    required DocumentDraft draft,
  });
  Future<void> delete({
    required String userId,
    required String documentId,
  });
}
