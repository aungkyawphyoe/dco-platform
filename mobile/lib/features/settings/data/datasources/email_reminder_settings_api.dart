import 'package:dio/dio.dart';

import '../../../../core/network/auth_interceptor.dart';
import '../../domain/entities/email_reminder_settings.dart';

abstract class EmailReminderSettingsApi {
  Future<EmailReminderSettings> get();
  Future<EmailReminderSettings> update({
    required bool enabled,
    required int leadDays,
  });
}

class DioEmailReminderSettingsApi implements EmailReminderSettingsApi {
  DioEmailReminderSettingsApi(this._dio);

  final Dio _dio;

  @override
  Future<EmailReminderSettings> get() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/me/reminder-emails');
      return EmailReminderSettings.fromJson(response.data!);
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  @override
  Future<EmailReminderSettings> update({
    required bool enabled,
    required int leadDays,
  }) async {
    try {
      final response = await _dio.put<Map<String, dynamic>>(
        '/me/reminder-emails',
        data: {'enabled': enabled, 'lead_days': leadDays},
      );
      return EmailReminderSettings.fromJson(response.data!);
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }
}

class MockEmailReminderSettingsApi implements EmailReminderSettingsApi {
  EmailReminderSettings _settings = const EmailReminderSettings(
    enabled: false,
    leadDays: 30,
    available: true,
  );

  @override
  Future<EmailReminderSettings> get() async => _settings;

  @override
  Future<EmailReminderSettings> update({
    required bool enabled,
    required int leadDays,
  }) async {
    _settings = _settings.copyWith(enabled: enabled, leadDays: leadDays);
    return _settings;
  }
}
