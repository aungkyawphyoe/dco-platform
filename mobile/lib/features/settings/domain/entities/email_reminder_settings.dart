class EmailReminderSettings {
  const EmailReminderSettings({
    required this.enabled,
    required this.leadDays,
    required this.available,
  });

  factory EmailReminderSettings.fromJson(Map<String, dynamic> json) {
    return EmailReminderSettings(
      enabled: json['enabled'] as bool? ?? false,
      leadDays: json['lead_days'] as int? ?? 30,
      available: json['available'] as bool? ?? false,
    );
  }

  static const defaults = EmailReminderSettings(
    enabled: false,
    leadDays: 30,
    available: false,
  );

  final bool enabled;
  final int leadDays;
  final bool available;

  EmailReminderSettings copyWith({
    bool? enabled,
    int? leadDays,
    bool? available,
  }) {
    return EmailReminderSettings(
      enabled: enabled ?? this.enabled,
      leadDays: leadDays ?? this.leadDays,
      available: available ?? this.available,
    );
  }
}
