import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/supabase_config.dart';

class SupabaseService extends ChangeNotifier {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  bool _initialized = false;
  bool get isInitialized => _initialized;
  StreamSubscription<AuthState>? _authSubscription;

  SupabaseClient? get client {
    if (_initialized && SupabaseConfig.isConfigured) {
      try {
        return Supabase.instance.client;
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  bool get isSupabaseConfigured => SupabaseConfig.isConfigured;

  Future<void> initialize() async {
    if (!SupabaseConfig.isConfigured) {
      debugPrint(
        '[SupabaseService] Supabase credentials not set in environment.',
      );
      return;
    }

    try {
      await Supabase.initialize(
        url: SupabaseConfig.supabaseUrl,
        publishableKey: SupabaseConfig.supabaseAnonKey,
      );
      _initialized = true;
      _authSubscription?.cancel();
      _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
        data,
      ) {
        notifyListeners();
      });
      debugPrint('[SupabaseService] Successfully initialized Supabase client.');
    } catch (e) {
      debugPrint('[SupabaseService] Failed to initialize Supabase: $e');
    }
  }

  // Real Auth Getters
  User? get currentUser => client?.auth.currentUser;
  String? get currentUserId => client?.auth.currentUser?.id;

  String get currentUserName {
    if (client?.auth.currentUser != null) {
      final meta = client!.auth.currentUser!.userMetadata;
      return meta?['full_name']?.toString() ??
          meta?['name']?.toString() ??
          client!.auth.currentUser!.email?.split('@').first ??
          'MediGuard Clinician';
    }
    return 'Guest';
  }

  String get currentUserEmail => client?.auth.currentUser?.email ?? '';

  bool get isAuthenticated => client?.auth.currentUser != null;

  Stream<AuthState>? get authStateChanges => client?.auth.onAuthStateChange;

  // Real Auth Operations
  static const String authRedirectUrl =
      'https://bskjisnvumbsiwcahvyw.supabase.co/functions/v1/auth-confirm';

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    if (client == null) {
      throw Exception('Supabase is not initialized. Please verify your connection.');
    }

    final response = await client!.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName},
      emailRedirectTo: authRedirectUrl,
    );
    notifyListeners();
    return response;
  }

  Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) async {
    if (client == null) {
      throw Exception('Supabase is not initialized. Please verify your connection.');
    }

    final response = await client!.auth.signInWithPassword(
      email: email,
      password: password,
    );
    notifyListeners();
    return response;
  }

  Future<void> resetPasswordForEmail(String email) async {
    if (client != null) {
      await client!.auth.resetPasswordForEmail(
        email,
        redirectTo: authRedirectUrl,
      );
    }
  }

  Future<void> signOut() async {
    if (client != null) {
      await client!.auth.signOut();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}

