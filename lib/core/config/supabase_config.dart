import 'package:flutter/foundation.dart';

class SupabaseConfig {
  // Compile-time environment definitions or defaults
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://bskjisnvumbsiwcahvyw.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_43KPE7YGnNbT6RXg9gucDw_abLdXZ_h',
  );

  /// Check whether valid Supabase credentials have been configured
  static bool get isConfigured {
    return supabaseUrl.isNotEmpty &&
        supabaseUrl.startsWith('https://') &&
        supabaseAnonKey.isNotEmpty &&
        supabaseAnonKey != 'your-publishable-or-anon-key-here';
  }

  /// Project reference identifier
  static const String projectRef = 'bskjisnvumbsiwcahvyw';

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
