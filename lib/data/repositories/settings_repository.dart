import 'package:flutter/foundation.dart';
import '../models/device_info.dart';
import '../models/device_settings.dart';
import '../models/sensor_reading.dart';
import '../services/supabase_service.dart';

class SettingsRepository {
  final SupabaseService _supabaseService;

  DeviceSettings _cachedSettings = DeviceSettings.defaultSettings();
  DeviceInfo _cachedDevice = DeviceInfo(
    id: 'c0b54f87-1f7b-45a7-8554-de66122a0fbe',
    deviceName: 'MediGuard Smart Box Alpha',
    modelVersion: 'ESP32-MediGuard-v1',
    serialNumber: 'mediguard-container-01',
    isOnline: true,
    dataSource: DataSourceType.hardware,
    createdAt: DateTime.now().subtract(const Duration(days: 30)),
  );

  SettingsRepository({SupabaseService? supabaseService})
    : _supabaseService = supabaseService ?? SupabaseService();

  Future<DeviceSettings> getSettings() async {
    final client = _supabaseService.client;
    final userId = _supabaseService.currentUserId;

    if (client != null && userId != null) {
      try {
        final data = await client
            .from('device_settings')
            .select()
            .eq('user_id', userId)
            .maybeSingle();

        if (data != null) {
          _cachedSettings = DeviceSettings.fromJson(data);
          return _cachedSettings;
        }
      } catch (e) {
        debugPrint(
          '[SettingsRepository] Error loading settings from Supabase: $e',
        );
      }
    }

    return _cachedSettings;
  }

  Future<DeviceSettings> updateSettings(DeviceSettings settings) async {
    _cachedSettings = settings.copyWith(updatedAt: DateTime.now());

    final client = _supabaseService.client;
    final userId = _supabaseService.currentUserId;

    if (client != null && userId != null) {
      try {
        final payload = _cachedSettings.toJson(userId: userId);
        final res = await client
            .from('device_settings')
            .upsert(payload, onConflict: 'user_id')
            .select()
            .single();
        _cachedSettings = DeviceSettings.fromJson(res);
      } catch (e) {
        debugPrint('[SettingsRepository] Error updating settings: $e');
      }
    }

    return _cachedSettings;
  }

  Future<List<DeviceInfo>> getDevices() async {
    final client = _supabaseService.client;

    if (client != null) {
      try {
        final data = await client
            .from('devices')
            .select()
            .order('created_at', ascending: true);

        final list = (data as List).map((e) => DeviceInfo.fromJson(e)).toList();
        if (list.isNotEmpty) {
          return list;
        }
      } catch (e) {
        debugPrint('[SettingsRepository] Error loading devices: $e');
      }
    }

    return [
      _cachedDevice,
      DeviceInfo(
        id: 'd1b54f87-2f7b-45a7-8554-de66122a0fbf',
        deviceName: 'MediGuard ICU Unit Beta',
        modelVersion: 'ESP32-MediGuard-v1',
        serialNumber: 'mediguard-container-02',
        isOnline: true,
        dataSource: DataSourceType.hardware,
        createdAt: DateTime.now().subtract(const Duration(days: 10)),
      ),
    ];
  }

  Future<DeviceInfo?> getDeviceById(String id) async {
    final client = _supabaseService.client;
    if (client != null) {
      try {
        final data = await client
            .from('devices')
            .select()
            .eq('id', id)
            .maybeSingle();
        if (data != null) {
          return DeviceInfo.fromJson(data);
        }
      } catch (e) {
        debugPrint('[SettingsRepository] Error fetching device $id: $e');
      }
    }
    if (_cachedDevice.id == id) return _cachedDevice;
    if (id == 'd1b54f87-2f7b-45a7-8554-de66122a0fbf') {
      return DeviceInfo(
        id: 'd1b54f87-2f7b-45a7-8554-de66122a0fbf',
        deviceName: 'MediGuard ICU Unit Beta',
        modelVersion: 'ESP32-MediGuard-v1',
        serialNumber: 'mediguard-container-02',
        isOnline: true,
        dataSource: DataSourceType.hardware,
        createdAt: DateTime.now().subtract(const Duration(days: 10)),
      );
    }
    return null;
  }

  Future<DeviceInfo> getDeviceInfo({String? deviceId}) async {
    final client = _supabaseService.client;

    if (client != null) {
      try {
        var query = client.from('devices').select();
        if (deviceId != null) {
          query = query.eq('id', deviceId);
        }
        final data = await query
            .order('last_seen_at', ascending: false)
            .limit(1)
            .maybeSingle();

        if (data != null) {
          _cachedDevice = DeviceInfo.fromJson(data);
          return _cachedDevice;
        }
      } catch (e) {
        debugPrint('[SettingsRepository] Error loading device info: $e');
      }
    }

    return _cachedDevice;
  }
  Future<DeviceInfo> updateDeviceInfo(DeviceInfo info) async {
    _cachedDevice = info;

    final client = _supabaseService.client;
    final userId = _supabaseService.currentUserId;

    if (client != null && userId != null) {
      try {
        final payload = info.toJson(userId: userId);
        final res = await client
            .from('devices')
            .upsert(payload)
            .select()
            .single();
        _cachedDevice = DeviceInfo.fromJson(res);
      } catch (e) {
        debugPrint('[SettingsRepository] Error updating device: $e');
      }
    }

    return _cachedDevice;
  }
}
