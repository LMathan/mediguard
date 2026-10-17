import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/sensor_reading.dart';
import 'sensor_data_source.dart';

class HardwareSensorService implements SensorDataSource {
  final SupabaseClient? supabase;
  final String? deviceId;
  final String? userId;
  final StreamController<SensorReading> _streamController =
      StreamController<SensorReading>.broadcast();
  RealtimeChannel? _subscription;
  Timer? _pollingTimer;

  bool _hasReadings = false;
  bool get hasReadings => _hasReadings;

  SensorReading _latestReading = SensorReading(
    normalTemperatureC: 0.0,
    normalHumidityPct: 0.0,
    coldTemperatureC: 0.0,
    coldHumidityPct: 0.0,
    sensorHealth: SensorHealth.healthy,
    dataSource: DataSourceType.hardware,
    recordedAt: DateTime.fromMillisecondsSinceEpoch(0),
  );

  HardwareSensorService({
    required this.supabase,
    this.deviceId,
    this.userId,
  });

  @override
  Stream<SensorReading> get readingStream => _streamController.stream;

  @override
  SensorReading get latestReading => _latestReading;

  @override
  bool get isSimulated => false;

  @override
  Future<void> initialize() async {
    if (supabase == null) {
      debugPrint(
        '[HardwareSensorService] Supabase client is null, hardware channel disabled',
      );
      return;
    }

    // Initial fetch from DB
    await fetchLatest();

    // Start 10-second polling backup for fresh DB telemetry
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      fetchLatest();
    });

    try {
      // Subscribe to Realtime Postgres Changes
      final channelName = 'public:sensor_readings:${userId ?? deviceId ?? 'all'}';
      _subscription = supabase!
          .channel(channelName)
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'sensor_readings',
            callback: (payload) {
              try {
                final reading = SensorReading.fromJson(payload.newRecord);
                // Verify relevance
                if (userId != null && payload.newRecord['user_id'] != userId) {
                  return;
                }
                if (deviceId != null && payload.newRecord['device_id'] != deviceId) {
                  return;
                }
                _hasReadings = true;
                _latestReading = reading;
                _streamController.add(reading);
              } catch (e) {
                debugPrint(
                  '[HardwareSensorService] Error parsing realtime reading: $e',
                );
              }
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('[HardwareSensorService] Realtime subscription error: $e');
    }
  }

  Future<void> fetchLatest() async {
    if (supabase == null) return;

    try {
      var query = supabase!.from('sensor_readings').select();

      if (userId != null) {
        query = query.eq('user_id', userId!);
      }
      if (deviceId != null) {
        query = query.eq('device_id', deviceId!);
      }

      final response = await query
          .order('recorded_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response != null) {
        _hasReadings = true;
        _latestReading = SensorReading.fromJson(response);
        _streamController.add(_latestReading);
      }
    } catch (e) {
      debugPrint('[HardwareSensorService] Error fetching latest reading: $e');
    }
  }

  @override
  Future<void> dispose() async {
    _pollingTimer?.cancel();
    if (_subscription != null && supabase != null) {
      await supabase!.removeChannel(_subscription!);
    }
    await _streamController.close();
  }
}
