import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  // Track recent notifications to prevent duplicate buzzes
  final Set<String> _recentlyNotifiedAlerts = {};

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const initSettings = InitializationSettings(android: androidSettings);

      await _notificationsPlugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (response) {
          debugPrint(
            '[NotificationService] Notification tapped: ${response.payload}',
          );
        },
      );

      // Create Android Notification Channel
      final androidImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      if (androidImplementation != null) {
        await androidImplementation.createNotificationChannel(
          const AndroidNotificationChannel(
            'mediguard_alerts',
            'MediGuard Critical Alerts',
            description: 'Critical temperature, door, and inventory alerts',
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
          ),
        );
      }

      _isInitialized = true;
    } catch (e) {
      debugPrint('[NotificationService] Initialization error: $e');
    }
  }

  Future<bool> requestPermissions() async {
    try {
      final androidImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      if (androidImplementation != null) {
        final granted = await androidImplementation
            .requestNotificationsPermission();
        return granted ?? false;
      }
      return false;
    } catch (e) {
      debugPrint('[NotificationService] Request permission error: $e');
      return false;
    }
  }

  Future<void> showCriticalAlert({
    required String alertKey,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_isInitialized) await initialize();

    // Deduplicate: avoid firing duplicate notifications for the same active condition
    if (_recentlyNotifiedAlerts.contains(alertKey)) {
      return;
    }
    _recentlyNotifiedAlerts.add(alertKey);

    // Auto-clear from deduplication map after 5 minutes
    Future.delayed(const Duration(minutes: 5), () {
      _recentlyNotifiedAlerts.remove(alertKey);
    });

    const androidDetails = AndroidNotificationDetails(
      'mediguard_alerts',
      'MediGuard Critical Alerts',
      channelDescription: 'Critical temperature, door, and inventory alerts',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      ticker: 'MediGuard Alert',
    );

    const details = NotificationDetails(android: androidDetails);

    final notificationId = alertKey.hashCode.abs() % 100000;
    try {
      await _notificationsPlugin.show(
        id: notificationId,
        title: title,
        body: body,
        notificationDetails: details,
        payload: payload,
      );
    } catch (e) {
      debugPrint('[NotificationService] Error showing notification: $e');
    }
  }
}
