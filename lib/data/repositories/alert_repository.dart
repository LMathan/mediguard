import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/alert_item.dart';
import '../services/notification_service.dart';
import '../services/supabase_service.dart';

class AlertRepository {
  final SupabaseService _supabaseService;
  final NotificationService _notificationService;
  final _uuid = const Uuid();
  final List<AlertItem> _inMemoryAlerts = [];

  AlertRepository({
    SupabaseService? supabaseService,
    NotificationService? notificationService,
  }) : _supabaseService = supabaseService ?? SupabaseService(),
       _notificationService = notificationService ?? NotificationService();

  Future<List<AlertItem>> getAlerts() async {
    final client = _supabaseService.client;
    final userId = _supabaseService.currentUserId;

    if (client != null && userId != null) {
      try {
        final data = await client
            .from('alerts')
            .select()
            .eq('user_id', userId)
            .order('created_at', ascending: false)
            .limit(50);
        return (data as List).map((e) => AlertItem.fromJson(e)).toList();
      } catch (e) {
        debugPrint('[AlertRepository] Supabase alert fetch error: $e');
      }
    }

    return List.unmodifiable(_inMemoryAlerts);
  }

  Future<List<AlertItem>> getActiveAlerts() async {
    final all = await getAlerts();
    return all.where((a) => a.status == AlertStatus.active).toList();
  }

  /// Create an alert ONLY if no active alert with the exact same type is currently open
  Future<AlertItem?> createAlertIfNew(AlertItem alert) async {
    final newAlert = alert.id.isEmpty ? alert.copyWith(id: _uuid.v4()) : alert;

    final client = _supabaseService.client;
    final userId = _supabaseService.currentUserId;

    if (client != null && userId != null) {
      try {
        // Verify in Supabase
        final existing = await client
            .from('alerts')
            .select('id')
            .eq('user_id', userId)
            .inFilter('type', _matchingDbValues(newAlert.type))
            .eq('status', 'active')
            .maybeSingle();

        if (existing == null) {
          final res = await client
              .from('alerts')
              .insert(newAlert.toJson(userId: userId))
              .select()
              .single();

          if (newAlert.severity == AlertSeverity.critical) {
            await _notificationService.showCriticalAlert(
              alertKey: newAlert.type.name,
              title: newAlert.title,
              body: newAlert.message,
            );
          }

          return AlertItem.fromJson(res);
        }
        return null;
      } catch (e) {
        debugPrint('[AlertRepository] Error saving alert: $e');
      }
    }

    // In-memory fallback for test harnesses
    final duplicate = _inMemoryAlerts.any(
      (a) => a.type == alert.type && a.status == AlertStatus.active,
    );
    if (duplicate) return null;

    _inMemoryAlerts.insert(0, newAlert);
    return newAlert;
  }

  Future<void> acknowledgeAlert(String id) async {
    final client = _supabaseService.client;
    final userId = _supabaseService.currentUserId;

    if (client != null && userId != null) {
      try {
        await client
            .from('alerts')
            .update({
              'status': 'acknowledged',
              'acknowledged_at': DateTime.now().toIso8601String(),
            })
            .eq('id', id)
            .eq('user_id', userId);
      } catch (e) {
        debugPrint('[AlertRepository] Error acknowledging alert: $e');
      }
    }

    final index = _inMemoryAlerts.indexWhere((a) => a.id == id);
    if (index != -1) {
      _inMemoryAlerts[index] = _inMemoryAlerts[index].copyWith(
        status: AlertStatus.acknowledged,
        acknowledgedAt: DateTime.now(),
      );
    }
  }

  Future<void> resolveAlert(String id) async {
    final client = _supabaseService.client;
    final userId = _supabaseService.currentUserId;

    if (client != null && userId != null) {
      try {
        await client
            .from('alerts')
            .update({
              'status': 'resolved',
              'resolved_at': DateTime.now().toIso8601String(),
            })
            .eq('id', id)
            .eq('user_id', userId);
      } catch (e) {
        debugPrint('[AlertRepository] Error resolving alert: $e');
      }
    }

    final index = _inMemoryAlerts.indexWhere((a) => a.id == id);
    if (index != -1) {
      _inMemoryAlerts[index] = _inMemoryAlerts[index].copyWith(
        status: AlertStatus.resolved,
        resolvedAt: DateTime.now(),
      );
    }
  }

  List<String> _matchingDbValues(AlertType type) {
    switch (type) {
      case AlertType.highTemp:
        return ['high_temp', 'cold_temp_high', 'temperature_critical'];
      case AlertType.lowTemp:
        return ['low_temp', 'cold_temp_low'];
      case AlertType.doorLeftOpen:
        return ['door_left_open', 'door_open'];
      case AlertType.sensorError:
        return ['sensor_error', 'sensor_fault'];
      case AlertType.deviceOffline:
        return ['device_offline'];
      default:
        return [type.dbValue];
    }
  }

  Future<void> resolveAlertsOfType(AlertType type) async {
    final client = _supabaseService.client;
    final userId = _supabaseService.currentUserId;

    if (client != null && userId != null) {
      try {
        final dbValues = _matchingDbValues(type);
        await client
            .from('alerts')
            .update({
              'status': 'resolved',
              'resolved_at': DateTime.now().toIso8601String(),
            })
            .eq('user_id', userId)
            .inFilter('type', dbValues)
            .eq('status', 'active');
      } catch (e) {
        debugPrint(
          '[AlertRepository] Error resolving alerts of type $type: $e',
        );
      }
    }

    for (int i = 0; i < _inMemoryAlerts.length; i++) {
      if (_inMemoryAlerts[i].type == type &&
          _inMemoryAlerts[i].status == AlertStatus.active) {
        _inMemoryAlerts[i] = _inMemoryAlerts[i].copyWith(
          status: AlertStatus.resolved,
          resolvedAt: DateTime.now(),
        );
      }
    }
  }
}
