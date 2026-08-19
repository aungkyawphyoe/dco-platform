import 'package:dco_mobile/features/auth/domain/auth_validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuthValidators.email', () {
    test('rejects empty', () {
      expect(AuthValidators.email(''), 'Email is required');
    });

    test('rejects invalid', () {
      expect(AuthValidators.email('not-an-email'), 'Enter a valid email');
    });

    test('rejects over 254 chars', () {
      final local = 'a' * 250;
      expect(AuthValidators.email('$local@x.com'), 'Email must be 254 characters or fewer');
    });

    test('accepts a normal address', () {
      expect(AuthValidators.email('owner@example.com'), isNull);
    });
  });

  group('AuthValidators.password', () {
    test('requires 8 characters', () {
      expect(AuthValidators.password('short'), 'Password must be at least 8 characters');
    });

    test('accepts 8+ characters', () {
      expect(AuthValidators.password('longenough'), isNull);
    });
  });

  group('AuthValidators.confirmPassword', () {
    test('must match', () {
      expect(
        AuthValidators.confirmPassword('abcdefghi', 'abcdefghj'),
        'Passwords do not match',
      );
    });
  });
}
