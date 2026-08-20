enum OutboxOp {
  upsert,
  archive,
  delete;

  String get storage => name;
}

abstract final class OutboxEntityType {
  static const vehicle = 'vehicle';
  static const planItem = 'plan_item';
  static const serviceRecord = 'service_record';
  static const part = 'part';
  static const document = 'document';
  static const expense = 'expense';
  static const media = 'media';
  static const user = 'user';
}
