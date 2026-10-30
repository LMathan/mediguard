import 'package:flutter/foundation.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import '../../core/config/onesignal_config.dart';
import '../models/alert_item.dart';
import 'notification_service.dart';

typedef PushSubscriptionCallback = void Function(String subscriptionId);

class OneSignalService {
  static final OneSignalService _instance = OneSignalService._internal();
  factory OneSignalService() => _instance;
  OneSignalService._internal();

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  // Callback registered by UI to show the Verification Dialog
  PushSubscriptionCallback? _onSubscribedCallback;
  bool _verificationDialogShown = false;

  void setSubscriptionCallback(PushSubscriptionCallback callback) {
    _onSubscribedCallback = callback;
    // Check if already subscribed at registration time
    final currentId = OneSignal.User.pushSubscription.id;
    if (_isValidServerId(currentId) && !_verificationDialogShown) {
      _verificationDialogShown = true;
      callback(currentId!);
    }
  }

  bool _isValidServerId(String? id) {
    return id != null && id.isNotEmpty && !id.startsWith('local-');
  }

  Future<void> initialize() async {
    if (_isInitialized) return;
    if (!OneSignalConfig.isConfigured) {
      debugPrint('[OneSignalService] OneSignal App ID not configured.');
      return;
    }

    try {
      // 1. Set debug log level in debug mode
      OneSignal.Debug.setLogLevel(
        kDebugMode ? OSLogLevel.verbose : OSLogLevel.none,
      );

      // 2. Initialize SDK
      OneSignal.initialize(OneSignalConfig.appId);

      // 3. Register Push Subscription Observer
      OneSignal.User.pushSubscription.addObserver((state) {
        final newId = state.current.id;
        debugPrint('[OneSignalService] Push subscription state changed: $newId');
        if (_isValidServerId(newId) && !_verificationDialogShown) {
          _verificationDialogShown = true;
          _onSubscribedCallback?.call(newId!);
        }
      });

      // 4. Handle Notification Clicks
      OneSignal.Notifications.addClickListener((event) {
        debugPrint(
          '[OneSignalService] Notification clicked: ${event.notification.title} - ${event.notification.additionalData}',
        );
      });

      // 5. Handle Foreground Notifications
      OneSignal.Notifications.addForegroundWillDisplayListener((event) {
        debugPrint(
          '[OneSignalService] Foreground notification received: ${event.notification.title}',
        );
        // Suppress duplicate local notifications for this alert type
        final alertTypeStr =
            event.notification.additionalData?['alert_type']?.toString();
        if (alertTypeStr != null && alertTypeStr.isNotEmpty) {
          NotificationService().markAlertAsRecentlyNotified(alertTypeStr);
          final mapped = AlertType.fromString(alertTypeStr);
          NotificationService().markAlertAsRecentlyNotified(mapped.name);
        }
        // Suppress system push notification banner when app is open (foreground).
        // The user can already see alerts directly in the app UI, avoiding duplicate/repeated push banners.
        event.preventDefault();
      });

      _isInitialized = true;
      debugPrint(
        '[OneSignalService] Initialized successfully with App ID: ${OneSignalConfig.appId}',
      );
    } catch (e) {
      debugPrint('[OneSignalService] Initialization error: $e');
    }
  }

  /// Check if notification permission is currently granted
  bool get hasPermission => OneSignal.Notifications.permission;

  /// Check if notification permission is currently granted across system & OneSignal
  Future<bool> checkPermission() async {
    try {
      final systemEnabled =
          await NotificationService().areNotificationsEnabled();
      // If Android system notifications are enabled, permission is granted!
      if (systemEnabled) return true;
      return OneSignal.Notifications.permission;
    } catch (e) {
      return OneSignal.Notifications.permission;
    }
  }

  /// Request push permission from user
  Future<bool> requestPermission() async {
    try {
      final granted = await OneSignal.Notifications.requestPermission(true);
      await NotificationService().requestPermissions();
      if (granted) {
        OneSignal.User.pushSubscription.optIn();
      }
      return granted;
    } catch (e) {
      debugPrint('[OneSignalService] Request permission error: $e');
      return false;
    }
  }

  /// Bind logged-in user to OneSignal
  Future<void> login(String userId) async {
    if (!_isInitialized) await initialize();
    try {
      await OneSignal.login(userId);
      debugPrint('[OneSignalService] Logged in user: $userId');
    } catch (e) {
      debugPrint('[OneSignalService] Login error: $e');
    }
  }

  /// Unbind user from OneSignal on logout
  Future<void> logout() async {
    try {
      await OneSignal.logout();
      debugPrint('[OneSignalService] User logged out.');
    } catch (e) {
      debugPrint('[OneSignalService] Logout error: $e');
    }
  }

  /// Set user tags for segmentation
  void addTag(String key, String value) {
    OneSignal.User.addTagWithKey(key, value);
  }

  void removeTag(String key) {
    OneSignal.User.removeTag(key);
  }

  String? get subscriptionId => OneSignal.User.pushSubscription.id;
  bool get isOptedIn => OneSignal.User.pushSubscription.optedIn ?? false;
}
