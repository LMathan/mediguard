import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/supabase_config.dart';
import 'onesignal_service.dart';

import 'dart:io';

void _debugLog(String msg) {
  debugPrint(msg);
  try {
    stderr.writeln(msg);
  } catch (_) {}
}

class SupabaseService extends ChangeNotifier {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  bool _isServiceInitialized = false;
  bool get isServiceInitialized => _isServiceInitialized;

  bool get isInitialized {
    try {
      return Supabase.instance.isInitialized;
    } catch (_) {
      return false;
    }
  }

  StreamSubscription<AuthState>? _authSubscription;

  SupabaseClient? get client {
    try {
      if (Supabase.instance.isInitialized) {
        return Supabase.instance.client;
      }
    } catch (_) {}
    return null;
  }

  bool get isSupabaseConfigured => SupabaseConfig.isConfigured;

  String _getPersistKey() {
    final host = Uri.parse(SupabaseConfig.supabaseUrl).host;
    return "sb-${host.split('.').first}-auth-token";
  }

  Future<void> initialize() async {
    _debugLog('[SupabaseService] initialize() started.');
    if (!SupabaseConfig.isConfigured) {
      _debugLog('[SupabaseService] Supabase credentials not configured.');
      _isServiceInitialized = true;
      notifyListeners();
      return;
    }

    try {
      if (!isInitialized) {
        _debugLog('[SupabaseService] Initializing Supabase SDK...');
        await Supabase.initialize(
          url: SupabaseConfig.supabaseUrl,
          // ignore: deprecated_member_use
          anonKey: SupabaseConfig.supabaseAnonKey,
        );
      }

      // Check for persisted session in storage and restore it before UI loads
      try {
        final prefs = await SharedPreferences.getInstance();
        final key = _getPersistKey();
        final persisted = prefs.getString(key);
        _debugLog(
          '[SupabaseService] Pref key $key exists: ${persisted != null}, currentSession: ${Supabase.instance.client.auth.currentSession != null}',
        );
        if (persisted != null) {
          if (Supabase.instance.client.auth.currentSession == null) {
            _debugLog('[SupabaseService] Setting initial session from storage key: $key...');
            try {
              await Supabase.instance.client.auth.setInitialSession(persisted);
            } catch (setErr) {
              _debugLog('[SupabaseService] setInitialSession error: $setErr');
            }
          }

          final curr = Supabase.instance.client.auth.currentSession;
          if (curr != null && curr.isExpired) {
            _debugLog('[SupabaseService] Session is expired, recovering...');
            try {
              await Supabase.instance.client.auth.recoverSession(persisted);
            } catch (recErr) {
              _debugLog('[SupabaseService] recoverSession error: $recErr');
            }
          }
          _debugLog(
            '[SupabaseService] Session status: user=${Supabase.instance.client.auth.currentUser?.email}',
          );
        }
      } catch (e) {
        _debugLog('[SupabaseService] Session restoration check error: $e');
      }

      try {
        final initialUser = Supabase.instance.client.auth.currentUser;
        if (initialUser != null) {
          OneSignalService().login(initialUser.id);
        }
      } catch (e) {
        _debugLog('[SupabaseService] Initial user sync error: $e');
      }

      _authSubscription?.cancel();
      _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
        data,
      ) async {
        _debugLog(
          '[SupabaseService] onAuthStateChange event: ${data.event}, user: ${data.session?.user.email}',
        );
        if (data.session?.user.id != null) {
          OneSignalService().login(data.session!.user.id);
        } else if (data.event == AuthChangeEvent.signedOut) {
          OneSignalService().logout();
        }

        // Keep SharedPreferences in sync with every session update
        if (data.session != null) {
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(
              _getPersistKey(),
              jsonEncode(data.session!.toJson()),
            );
          } catch (_) {}
        } else if (data.event == AuthChangeEvent.signedOut) {
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.remove(_getPersistKey());
          } catch (_) {}
        }

        notifyListeners();
      });

      _isServiceInitialized = true;
      _debugLog(
        '[SupabaseService] Successfully initialized. User: ${client?.auth.currentUser?.email}, isAuthenticated: $isAuthenticated',
      );
      notifyListeners();
    } catch (e) {
      _debugLog('[SupabaseService] Failed to initialize Supabase: $e');
      _isServiceInitialized = true;
      notifyListeners();
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

  bool get isAuthenticated {
    final auth = client?.auth.currentUser != null;
    _debugLog(
      '[SupabaseService] isAuthenticated: $auth (${client?.auth.currentUser?.email})',
    );
    return auth;
  }

  Stream<AuthState>? get authStateChanges => client?.auth.onAuthStateChange;

  // Real Auth Operations
  static String get authRedirectUrl =>
      '${SupabaseConfig.supabaseUrl}/functions/v1/auth-confirm';

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    SupabaseClient? c = client;
    if (c == null) {
      await initialize();
      c = client;
    }
    if (c == null) {
      throw Exception('Supabase is not initialized. Please verify your connection.');
    }

    final response = await c.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName},
      emailRedirectTo: authRedirectUrl,
    );

    if (response.session != null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          _getPersistKey(),
          jsonEncode(response.session!.toJson()),
        );
        _debugLog('[SupabaseService] Explicitly persisted session after signUp');
      } catch (e) {
        _debugLog('[SupabaseService] Error persisting session on signUp: $e');
      }
    }

    notifyListeners();
    return response;
  }

  Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) async {
    _debugLog('[SupabaseService] signInWithPassword for $email...');
    SupabaseClient? c = client;
    if (c == null) {
      await initialize();
      c = client;
    }
    if (c == null) {
      throw Exception('Supabase is not initialized. Please verify your connection.');
    }

    final response = await c.auth.signInWithPassword(
      email: email,
      password: password,
    );

    if (response.session != null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          _getPersistKey(),
          jsonEncode(response.session!.toJson()),
        );
        _debugLog(
          '[SupabaseService] Explicitly persisted session after signInWithPassword for ${_getPersistKey()}',
        );
      } catch (e) {
        _debugLog(
          '[SupabaseService] Error persisting session on signInWithPassword: $e',
        );
      }
    }

    _debugLog(
      '[SupabaseService] signInWithPassword successful. User: ${response.user?.email}',
    );
    notifyListeners();
    return response;
  }

  Future<void> resetPasswordForEmail(String email) async {
    SupabaseClient? c = client;
    if (c == null) {
      await initialize();
      c = client;
    }
    if (c != null) {
      await c.auth.resetPasswordForEmail(
        email,
        redirectTo: authRedirectUrl,
      );
    }
  }

  Future<void> signOut() async {
    _debugLog('[SupabaseService] signOut() called');
    final c = client;
    if (c != null) {
      await c.auth.signOut();
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_getPersistKey());
      _debugLog('[SupabaseService] Cleared persisted session key');
    } catch (e) {
      _debugLog('[SupabaseService] Error removing persisted session key: $e');
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
