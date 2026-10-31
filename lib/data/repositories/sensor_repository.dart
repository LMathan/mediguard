import 'package:flutter/foundation.dart';
import '../models/sensor_reading.dart';
import '../services/supabase_service.dart';

class SensorRepository {
  final SupabaseService _supabaseService;

  SensorRepository({
    SupabaseService? supabaseService,
  }) : _supabaseService = supabaseService ?? SupabaseService();

  /// Get historical readings for charts based on time window from real database
  Future<List<SensorReading>> getHistory({
    Duration window = const Duration(hours: 24),
    String? deviceId,
  }) async {
    final client = _supabaseService.client;
    final userId = _supabaseService.currentUserId;

    if (client != null) {
      try {
        final cutoff = DateTime.now().subtract(window).toIso8601String();
        var filter = client
            .from('sensor_readings')
            .select()
            .gte('recorded_at', cutoff);

        if (deviceId != null) {
          filter = filter.eq('device_id', deviceId);
        } else if (userId != null) {
          filter = filter.eq('user_id', userId);
        }

        final data = await filter
            .order('recorded_at', ascending: true)
            .limit(100);
        return (data as List)
            .map((e) => SensorReading.fromJson(e))
            .toList();
      } catch (e) {
        debugPrint('[SensorRepository] Supabase history query error: $e');
      }
    }

    return [];
  }

  /// Persist a reading to Supabase
  Future<void> persistReading(SensorReading reading, {String? deviceId}) async {
    final client = _supabaseService.client;
    final userId = _supabaseService.currentUserId;

    if (client != null && userId != null) {
      try {
        await client
            .from('sensor_readings')
            .insert(reading.toJson(userId: userId, deviceId: deviceId));
      } catch (e) {
        debugPrint('[SensorRepository] Error saving reading to Supabase: $e');
      }
    }
  }
}
