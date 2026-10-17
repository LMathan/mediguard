import 'package:flutter_test/flutter_test.dart';
import 'package:mediguard/core/utils/auth_error_formatter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('AuthErrorFormatter Tests', () {
    test('Formats email not confirmed error clearly', () {
      final error = const AuthException('Email not confirmed');
      final result = formatAuthError(error);
      expect(result, contains('not verified yet'));
      expect(result, contains('check your inbox'));
    });

    test('Formats invalid credentials error cleanly', () {
      final error = const AuthException('Invalid login credentials');
      final result = formatAuthError(error);
      expect(result, 'Invalid email or password. Please verify your credentials and try again.');
    });

    test('Formats rate limit error cleanly', () {
      final error = const AuthException('over_email_send_rate_limit');
      final result = formatAuthError(error);
      expect(result, contains('Security rate limit reached'));
    });

    test('Formats user already registered error cleanly', () {
      final error = const AuthException('User already registered');
      final result = formatAuthError(error);
      expect(result, contains('already exists'));
    });

    test('Strips raw Exception: wrappers gracefully', () {
      final result = formatAuthError(Exception('Some unexpected service failure'));
      expect(result, 'Some unexpected service failure');
    });
  });
}
