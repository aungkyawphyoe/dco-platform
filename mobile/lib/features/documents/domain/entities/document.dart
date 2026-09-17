enum DocumentCategory {
  insurance,
  registration,
  invoice,
  warranty,
  receipt,
  other;

  String get storage => name;

  static DocumentCategory fromString(String value) {
    return DocumentCategory.values.firstWhere(
      (e) => e.name == value,
      orElse: () => DocumentCategory.other,
    );
  }
}

class Document {
  const Document({
    required this.id,
    required this.vehicleId,
    required this.name,
    required this.category,
    this.notes,
    this.localFilePath,
    this.mediaId,
    required this.updatedAt,
    required this.createdAt,
  });

  final String id;
  final String vehicleId;
  final String name;
  final DocumentCategory category;
  final String? notes;
  final String? localFilePath;
  final String? mediaId;
  final DateTime updatedAt;
  final DateTime createdAt;

  bool get hasLocalFile => localFilePath != null && localFilePath!.isNotEmpty;
  bool get isSynced => mediaId != null;

  Map<String, dynamic> toWriteJson() => {
        'id': id,
        'name': name,
        'category': category.storage,
        if (notes != null) 'notes': notes,
        if (mediaId != null) 'media_id': mediaId,
      };

  Document copyWith({
    String? name,
    DocumentCategory? category,
    String? notes,
    String? localFilePath,
    String? mediaId,
    DateTime? updatedAt,
  }) {
    return Document(
      id: id,
      vehicleId: vehicleId,
      name: name ?? this.name,
      category: category ?? this.category,
      notes: notes ?? this.notes,
      localFilePath: localFilePath ?? this.localFilePath,
      mediaId: mediaId ?? this.mediaId,
      updatedAt: updatedAt ?? this.updatedAt,
      createdAt: createdAt,
    );
  }
}

class DocumentDraft {
  const DocumentDraft({
    required this.name,
    required this.category,
    this.notes,
    this.localFilePath,
  });

  final String name;
  final DocumentCategory category;
  final String? notes;
  final String? localFilePath;
}
