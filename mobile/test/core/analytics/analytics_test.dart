import 'package:dco_mobile/core/analytics/analytics.dart';
import 'package:dco_mobile/core/analytics/firebase_analytics_sink.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingSink implements AnalyticsSink {
  final events = <(String, Map<String, Object?>)>[];
  String? userId;
  (String, String?)? userProperty;
  bool? collectionEnabled;

  @override
  Future<void> logEvent(String name, Map<String, Object?> parameters) async {
    events.add((name, parameters));
  }

  @override
  Future<void> setUserId(String? userId) async {
    this.userId = userId;
  }

  @override
  Future<void> setUserProperty(String name, String? value) async {
    userProperty = (name, value);
  }

  @override
  Future<void> setCollectionEnabled(bool enabled) async {
    collectionEnabled = enabled;
  }
}

void main() {
  group('Analytics facade', () {
    test('forwards tracked events to the sink', () {
      final sink = _RecordingSink();
      final analytics = Analytics(sink);

      analytics.track(AnalyticsEvent.vehicleAdded, {'fuel_type': 'petrol'});

      expect(sink.events, hasLength(1));
      expect(sink.events.single.$1, 'vehicle_added');
      expect(sink.events.single.$2, {'fuel_type': 'petrol'});
    });

    test('forwards identity and collection controls', () async {
      final sink = _RecordingSink();
      final analytics = Analytics(sink);

      await analytics.setUserId('u1');
      await analytics.setUserProperty('plan', 'standard');
      await analytics.setCollectionEnabled(false);

      expect(sink.userId, 'u1');
      expect(sink.userProperty, ('plan', 'standard'));
      expect(sink.collectionEnabled, isFalse);
    });

    test('defaults to a safe no-op sink', () {
      const analytics = Analytics();
      expect(
        () => analytics.track(AnalyticsEvent.garageOpened),
        returnsNormally,
      );
    });
  });

  group('sanitizeFirebaseParameters', () {
    test('converts booleans and keeps numbers', () {
      final result = sanitizeFirebaseParameters({
        'ok': true,
        'nope': false,
        'count': 3,
      });
      expect(result, {'ok': 'true', 'nope': 'false', 'count': 3});
    });

    test('drops null and empty values', () {
      final result = sanitizeFirebaseParameters({'a': null, 'b': '', 'c': 'x'});
      expect(result, {'c': 'x'});
    });

    test('truncates long values and keys', () {
      final result = sanitizeFirebaseParameters({'k' * 60: 'v' * 200});
      expect(result.keys.single.length, 40);
      expect((result.values.single as String).length, 100);
    });

    test('drops reserved parameter names', () {
      final result = sanitizeFirebaseParameters({
        'firebase_previous_id': 'x',
        'ga_session': 'y',
        'google_x': 'z',
        'screen': 'fuel',
      });
      expect(result, {'screen': 'fuel'});
    });

    test('caps at 25 parameters', () {
      final result = sanitizeFirebaseParameters({
        for (var i = 0; i < 40; i++) 'p$i': i,
      });
      expect(result, hasLength(25));
    });
  });
}
