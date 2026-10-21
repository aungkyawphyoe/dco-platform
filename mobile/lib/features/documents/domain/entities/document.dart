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

class DocumentLink {
  const DocumentLink({required this.kind, required this.recordId});
  final String kind;
  final String recordId;
  Map<String, dynamic> toJson() => {'kind': kind, 'record_id': recordId};
  factory DocumentLink.fromJson(Map<String, dynamic> json) => DocumentLink(
    kind: json['kind'] as String,
    recordId: json['record_id'] as String,
  );
  bool matches(DocumentLink other) =>
      kind == other.kind && recordId == other.recordId;
}

class Document {
  const Document({
    required this.id,
    required this.vehicleId,
    required this.name,
    required this.category,
    this.notes,
    this.links = const [],
    this.expiresOn,
    this.localFilePath,
    this.mediaId,
    this.createdBy,
    required this.updatedAt,
    required this.createdAt,
  });

  final String id;
  final String vehicleId;
  final String name;
  final DocumentCategory category;
  final String? notes;
  final List<DocumentLink> links;
  final DateTime? expiresOn;
  final String? localFilePath;
  final String? mediaId;
  final String? createdBy;
  final DateTime updatedAt;
  final DateTime createdAt;

  bool get hasLocalFile => localFilePath != null && localFilePath!.isNotEmpty;
  bool get isSynced => mediaId != null;

  String? get expiresOnDate => expiresOn?.toIso8601String().split('T').first;

  Map<String, dynamic> toWriteJson() => {
    'id': id,
    'vehicle_id': vehicleId,
    'name': name,
    'category': category.storage,
    'links': links.map((link) => link.toJson()).toList(),
    if (notes != null) 'notes': notes,
    'expires_on': expiresOnDate,
    if (mediaId != null) 'media_id': mediaId,
  };

  Document copyWith({
    List<DocumentLink>? links,
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
      links: links ?? this.links,
      name: name ?? this.name,
      category: category ?? this.category,
      notes: notes ?? this.notes,
      expiresOn: identical(expiresOn, _unset)
          ? this.expiresOn
          : expiresOn as DateTime?,
      localFilePath: localFilePath ?? this.localFilePath,
      mediaId: mediaId ?? this.mediaId,
      createdBy: createdBy,
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
    this.links = const [],
    this.expiresOn,
    this.localFilePath,
  });

  final String name;
  final DocumentCategory category;
  final String? notes;
  final List<DocumentLink> links;
  final DateTime? expiresOn;
  final String? localFilePath;
}
