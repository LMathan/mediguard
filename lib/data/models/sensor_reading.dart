enum DataSourceType {
  simulated,
  hardware;

  String get label {
    switch (this) {
      case DataSourceType.simulated:
        return 'Simulated';
      case DataSourceType.hardware:
        return 'ESP32 Hardware';
    }
  }

  static DataSourceType fromString(String? val) {
    if (val?.toLowerCase() == 'hardware') return DataSourceType.hardware;
    return DataSourceType.simulated;
  }
}

enum SensorHealth {
  healthy,
  warning,
  error;

  String get label {
    switch (this) {
      case SensorHealth.healthy:
        return 'Healthy';
      case SensorHealth.warning:
        return 'Warning';
      case SensorHealth.error:
        return 'Sensor Fault';
    }
  }

  static SensorHealth fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'warning':
        return SensorHealth.warning;
      case 'error':
        return SensorHealth.error;
      default:
        return SensorHealth.healthy;
    }
  }
}

enum OverallStatus {
  normal,
  warning,
  critical,
  unknown,
  offline;

  String get label {
    switch (this) {
      case OverallStatus.normal:
        return 'Normal';
      case OverallStatus.warning:
        return 'Warning';
      case OverallStatus.critical:
        return 'Critical';
      case OverallStatus.unknown:
        return 'Unknown';
      case OverallStatus.offline:
        return 'Device Offline';
    }
  }
}

class SensorReading {
  final String? id;
  final String? deviceId;
  final double normalTemperatureC;
  final double normalHumidityPct;
  final double coldTemperatureC;
  final double coldHumidityPct;
  final bool normalDoorOpen;
  final bool coldDoorOpen;
  final bool normalLightDetected;
  final bool coldLightDetected;
  final bool coolingActive;
  final bool normalFanActive;
  final SensorHealth sensorHealth;
  final DataSourceType dataSource;
  final DateTime recordedAt;

  const SensorReading({
    this.id,
    this.deviceId,
    required this.normalTemperatureC,
    required this.normalHumidityPct,
    required this.coldTemperatureC,
    required this.coldHumidityPct,
    this.normalDoorOpen = false,
    this.coldDoorOpen = false,
    this.normalLightDetected = false,
    this.coldLightDetected = false,
    this.coolingActive = false,
    this.normalFanActive = false,
    this.sensorHealth = SensorHealth.healthy,
    this.dataSource = DataSourceType.simulated,
    required this.recordedAt,
  });

  /// True if reading was recorded more than [threshold] ago
  bool isStale({Duration threshold = const Duration(seconds: 90)}) {
    return DateTime.now().difference(recordedAt) > threshold;
  }

  SensorReading copyWith({
    String? id,
    String? deviceId,
    double? normalTemperatureC,
    double? normalHumidityPct,
    double? coldTemperatureC,
    double? coldHumidityPct,
    bool? normalDoorOpen,
    bool? coldDoorOpen,
    bool? normalLightDetected,
    bool? coldLightDetected,
    bool? coolingActive,
    bool? normalFanActive,
    SensorHealth? sensorHealth,
    DataSourceType? dataSource,
    DateTime? recordedAt,
  }) {
    return SensorReading(
      id: id ?? this.id,
      deviceId: deviceId ?? this.deviceId,
      normalTemperatureC: normalTemperatureC ?? this.normalTemperatureC,
      normalHumidityPct: normalHumidityPct ?? this.normalHumidityPct,
      coldTemperatureC: coldTemperatureC ?? this.coldTemperatureC,
      coldHumidityPct: coldHumidityPct ?? this.coldHumidityPct,
      normalDoorOpen: normalDoorOpen ?? this.normalDoorOpen,
      coldDoorOpen: coldDoorOpen ?? this.coldDoorOpen,
      normalLightDetected: normalLightDetected ?? this.normalLightDetected,
      coldLightDetected: coldLightDetected ?? this.coldLightDetected,
      coolingActive: coolingActive ?? this.coolingActive,
      normalFanActive: normalFanActive ?? this.normalFanActive,
      sensorHealth: sensorHealth ?? this.sensorHealth,
      dataSource: dataSource ?? this.dataSource,
      recordedAt: recordedAt ?? this.recordedAt,
    );
  }

  Map<String, dynamic> toJson({String? userId, String? deviceId}) {
    return {
      // ignore: use_null_aware_elements
      if (id != null) 'id': id,
      // ignore: use_null_aware_elements
      if (userId != null) 'user_id': userId,
      'device_id': deviceId ?? this.deviceId,
      'normal_temperature_c': normalTemperatureC,
      'normal_humidity_pct': normalHumidityPct,
      'cold_temperature_c': coldTemperatureC,
      'cold_humidity_pct': coldHumidityPct,
      'normal_door_open': normalDoorOpen,
      'cold_door_open': coldDoorOpen,
      'normal_light_detected': normalLightDetected,
      'cold_light_detected': coldLightDetected,
      'cooling_active': coolingActive,
      'normal_fan_active': normalFanActive,
      'sensor_health': sensorHealth.name,
      'data_source': dataSource.name,
      'recorded_at': recordedAt.toIso8601String(),
    };
  }

  factory SensorReading.fromJson(Map<String, dynamic> map) {
    return SensorReading(
      id: map['id']?.toString(),
      deviceId: map['device_id']?.toString(),
      normalTemperatureC:
          (map['normal_temperature_c'] as num?)?.toDouble() ?? 20.0,
      normalHumidityPct:
          (map['normal_humidity_pct'] as num?)?.toDouble() ?? 50.0,
      coldTemperatureC: (map['cold_temperature_c'] as num?)?.toDouble() ?? 4.0,
      coldHumidityPct: (map['cold_humidity_pct'] as num?)?.toDouble() ?? 55.0,
      normalDoorOpen: map['normal_door_open'] == true,
      coldDoorOpen: map['cold_door_open'] == true,
      normalLightDetected: map['normal_light_detected'] == true,
      coldLightDetected: map['cold_light_detected'] == true,
      coolingActive: map['cooling_active'] == true,
      normalFanActive: map['normal_fan_active'] == true,
      sensorHealth: SensorHealth.fromString(map['sensor_health']?.toString()),
      dataSource: DataSourceType.fromString(map['data_source']?.toString()),
      recordedAt: map['recorded_at'] != null
          ? DateTime.tryParse(map['recorded_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
