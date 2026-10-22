import 'package:dco_mobile/features/settings/data/datasources/email_reminder_settings_api.dart';
import 'package:dco_mobile/features/settings/domain/entities/email_reminder_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EmailReminderSettings', () {
    test('parses the API payload', () {
      final settings = EmailReminderSettings.fromJson({
        'enabled': true,
        'lead_days': 14,
        'available': true,
      });

      expect(settings.enabled, isTrue);
      expect(settings.leadDays, 14);
      expect(settings.available, isTrue);
    });

    test('falls back to safe defaults when fields are missing', () {
      final settings = EmailReminderSettings.fromJson({});

      expect(settings.enabled, isFalse);
      expect(settings.leadDays, 30);
      expect(settings.available, isFalse);
    });

    test('copyWith only replaces provided fields', () {
      final settings = EmailReminderSettings.defaults.copyWith(
        enabled: true,
        leadDays: 45,
      );

      expect(settings.enabled, isTrue);
      expect(settings.leadDays, 45);
      expect(settings.available, isFalse);
    });
  });

  group('MockEmailReminderSettingsApi', () {
    test('starts disabled and persists updates', () async {
      final api = MockEmailReminderSettingsApi();
      final initial = await api.get();
      expect(initial.enabled, isFalse);
      expect(initial.leadDays, 30);
      expect(initial.available, isTrue);

      final updated = await api.update(enabled: true, leadDays: 21);
      expect(updated.enabled, isTrue);
      expect(updated.leadDays, 21);
      expect((await api.get()).enabled, isTrue);
    });
  });
}
