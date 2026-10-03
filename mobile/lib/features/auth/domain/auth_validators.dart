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

  static String? identifier(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'Email or username is required';
    if (trimmed.length > 254) return 'Email or username must be 254 characters or fewer';
    // Accept either email format or username format (lowercase alphanumeric with . _)
    if (_email.hasMatch(trimmed)) return null;
    if (RegExp(r'^[a-z0-9._]{3,30}$').hasMatch(trimmed.toLowerCase())) return null;
    return 'Enter a valid email or username';
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
