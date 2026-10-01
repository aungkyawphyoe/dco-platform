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

const Object _unset = Object();

class Document {
  const Document({
    required this.id,
    required this.vehicleId,
    required this.name,
    required this.category,
    this.notes,
    this.expiresOn,
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
  final DateTime? expiresOn;
  final String? localFilePath;
  final String? mediaId;
  final DateTime updatedAt;
  final DateTime createdAt;

  bool get hasLocalFile => localFilePath != null && localFilePath!.isNotEmpty;
  bool get isSynced => mediaId != null;

  String? get expiresOnDate => expiresOn?.toIso8601String().split('T').first;

  Map<String, dynamic> toWriteJson() => {
        'id': id,
        'name': name,
        'category': category.storage,
        if (notes != null) 'notes': notes,
        'expires_on': expiresOnDate,
        if (mediaId != null) 'media_id': mediaId,
      };

  Document copyWith({
    String? name,
    DocumentCategory? category,
    String? notes,
    Object? expiresOn = _unset,
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
      expiresOn: identical(expiresOn, _unset)
          ? this.expiresOn
          : expiresOn as DateTime?,
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
    this.expiresOn,
    this.localFilePath,
  });

  final String name;
  final DocumentCategory category;
  final String? notes;
  final DateTime? expiresOn;
  final String? localFilePath;
}
