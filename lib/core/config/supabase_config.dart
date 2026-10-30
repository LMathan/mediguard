import 'package:flutter/foundation.dart';

class SupabaseConfig {
  // Compile-time environment definitions loaded via --dart-define-from-file=.env
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  static const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Check whether valid Supabase credentials have been configured
  static bool get isConfigured {
    return supabaseUrl.isNotEmpty &&
        supabaseUrl.startsWith('https://') &&
        supabaseAnonKey.isNotEmpty &&
        supabaseAnonKey != 'your-publishable-or-anon-key-here';
  }

  /// Project reference identifier extracted from Supabase URL
  static String get projectRef =>
      Uri.tryParse(supabaseUrl)?.host.split('.').first ?? '';

  static void printStatus() {
    if (kDebugMode) {
      if (isConfigured) {
        debugPrint('[MediGuard] Supabase configured: $supabaseUrl');
      } else {
        debugPrint(
          '[MediGuard] Supabase credentials not provided. Running in standalone Demo Mode with local simulation and mock auth.',
        );
      }
    }
  }
}
