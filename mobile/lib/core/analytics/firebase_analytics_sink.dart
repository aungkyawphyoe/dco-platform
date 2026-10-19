import 'package:firebase_analytics/firebase_analytics.dart';

import 'analytics.dart';

/// [AnalyticsSink] backed by Google Analytics for Firebase (GA4).
class FirebaseAnalyticsSink implements AnalyticsSink {
  FirebaseAnalyticsSink(this._analytics);

  final FirebaseAnalytics _analytics;

  @override
  Future<void> logEvent(String name, Map<String, Object?> parameters) {
    return _analytics.logEvent(
      name: name,
      parameters: sanitizeFirebaseParameters(parameters),
    );
  }

  @override
  Future<void> setUserId(String? userId) => _analytics.setUserId(id: userId);

  @override
  Future<void> setUserProperty(String name, String? value) =>
      _analytics.setUserProperty(name: name, value: value);

  @override
  Future<void> setCollectionEnabled(bool enabled) =>
      _analytics.setAnalyticsCollectionEnabled(enabled);
}

const int _maxParams = 25;
const int _maxNameLength = 40;
const int _maxValueLength = 100;

/// GA4 only accepts a flat map of string/num values and rejects reserved
/// names. Normalize our loosely-typed call sites so a bad param can never
/// drop an event.
Map<String, Object> sanitizeFirebaseParameters(
  Map<String, Object?> parameters,
) {
  final sanitized = <String, Object>{};
  for (final entry in parameters.entries) {
    if (sanitized.length >= _maxParams) break;
    if (_isReserved(entry.key)) continue;
    final value = _sanitizeValue(entry.value);
    if (value == null) continue;
    sanitized[_truncate(entry.key, _maxNameLength)] = value;
  }
  return sanitized;
}

bool _isReserved(String name) {
  return name.startsWith('firebase_') ||
      name.startsWith('google_') ||
      name.startsWith('ga_');
}

Object? _sanitizeValue(Object? value) {
  if (value == null) return null;
  if (value is num) return value;
  if (value is bool) return value ? 'true' : 'false';
  final text = value.toString();
  if (text.isEmpty) return null;
  return _truncate(text, _maxValueLength);
}

String _truncate(String value, int maxLength) {
  return value.length <= maxLength ? value : value.substring(0, maxLength);
}
