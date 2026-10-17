import 'package:supabase_flutter/supabase_flutter.dart';

/// Translates raw Supabase/Network errors into user-friendly clinical messages.
String formatAuthError(dynamic error) {
  if (error == null) return 'An unexpected error occurred. Please try again.';

  String msg = '';
  if (error is AuthException) {
    msg = error.message;
  } else {
    msg = error.toString();
  }

  final lower = msg.toLowerCase();

  if (lower.contains('email not confirmed')) {
    return 'Your email address is not verified yet. Please check your inbox and click the verification link before logging in.';
  }
  if (lower.contains('invalid login credentials') ||
      lower.contains('invalid_grant')) {
    return 'Invalid email or password. Please verify your credentials and try again.';
  }
  if (lower.contains('user not found') || lower.contains('invalid user')) {
    return 'No account was found with this email address. Please register first.';
  }
  if (lower.contains('user already registered') ||
      lower.contains('already in use') ||
      lower.contains('already registered')) {
    return 'An account with this email address already exists. Please sign in or reset your password.';
  }
  if (lower.contains('password') &&
      (lower.contains('least') || lower.contains('short'))) {
    return 'Password is too short. Please use at least 6 characters.';
  }
  if (lower.contains('over_email_send_rate_limit') ||
      lower.contains('rate limit') ||
      lower.contains('too many requests')) {
    return 'Security rate limit reached. Please wait a couple minutes before requesting another verification email.';
  }
  if (lower.contains('socket') ||
      lower.contains('network') ||
      lower.contains('failed host lookup') ||
      lower.contains('connection refused') ||
      lower.contains('connection timed out') ||
      lower.contains('timeout')) {
    return 'Network connection error. Please check your internet connection and try again.';
  }
  if (lower.contains('jwt') || lower.contains('token has expired')) {
    return 'Your authentication session has expired. Please sign in again.';
  }

  // Strip technical wrappers if any standard message remains
  final cleaned = msg
      .replaceAll(
        RegExp(r'^(AuthApiException|AuthException|Exception|ClientException):\s*'),
        '',
      )
      .trim();

  return cleaned.isNotEmpty
      ? cleaned
      : 'An unexpected authentication error occurred. Please try again.';
}
