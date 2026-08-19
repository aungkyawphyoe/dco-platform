class AuthValidators {
  const AuthValidators._();

  static final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String? email(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'Email is required';
    if (trimmed.length > 254) return 'Email must be 254 characters or fewer';
    if (!_email.hasMatch(trimmed)) return 'Enter a valid email';
    return null;
  }

  static String? password(String value) {
    if (value.isEmpty) return 'Password is required';
    if (value.length < 8) return 'Password must be at least 8 characters';
    return null;
  }

  static String? confirmPassword(String value, String password) {
    if (value.isEmpty) return 'Confirm your password';
    if (value != password) return 'Passwords do not match';
    return null;
  }
}
