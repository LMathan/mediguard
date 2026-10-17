class DeviceSettings {
  final String? id;
  final String? userId;
  final String? deviceId;
  final double normalTempMinC;
  final double normalTempMaxC;
  final double normalHumidityMinPct;
  final double normalHumidityMaxPct;
  final double coldTempMinC;
  final double coldTempMaxC;
  final double coldHumidityMinPct;
  final double coldHumidityMaxPct;
  final int doorOpenWarningSeconds;
  final bool notificationsEnabled;
  final bool criticalAlertVibrate;
  final int expiryWarningDays;
  final int simulationIntervalSeconds;
  final int persistIntervalSeconds;
  final DateTime updatedAt;

  const DeviceSettings({
    this.id,
    this.userId,
    this.deviceId,
    this.normalTempMinC = 15.0,
    this.normalTempMaxC = 25.0,
    this.normalHumidityMinPct = 30.0,
    this.normalHumidityMaxPct = 60.0,
    this.coldTempMinC = 2.0,
    this.coldTempMaxC = 8.0,
    this.coldHumidityMinPct = 35.0,
    this.coldHumidityMaxPct = 65.0,
    this.doorOpenWarningSeconds = 60,
    this.notificationsEnabled = true,
    this.criticalAlertVibrate = true,
    this.expiryWarningDays = 30,
    this.simulationIntervalSeconds = 3,
    this.persistIntervalSeconds = 30,
    required this.updatedAt,
  });

  DeviceSettings copyWith({
    String? id,
    String? userId,
    String? deviceId,
    double? normalTempMinC,
    double? normalTempMaxC,
    double? normalHumidityMinPct,
    double? normalHumidityMaxPct,
    double? coldTempMinC,
    double? coldTempMaxC,
    double? coldHumidityMinPct,
    double? coldHumidityMaxPct,
    int? doorOpenWarningSeconds,
    bool? notificationsEnabled,
    bool? criticalAlertVibrate,
    int? expiryWarningDays,
    int? simulationIntervalSeconds,
    int? persistIntervalSeconds,
    DateTime? updatedAt,
  }) {
    return DeviceSettings(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      deviceId: deviceId ?? this.deviceId,
      normalTempMinC: normalTempMinC ?? this.normalTempMinC,
      normalTempMaxC: normalTempMaxC ?? this.normalTempMaxC,
      normalHumidityMinPct: normalHumidityMinPct ?? this.normalHumidityMinPct,
      normalHumidityMaxPct: normalHumidityMaxPct ?? this.normalHumidityMaxPct,
      coldTempMinC: coldTempMinC ?? this.coldTempMinC,
      coldTempMaxC: coldTempMaxC ?? this.coldTempMaxC,
      coldHumidityMinPct: coldHumidityMinPct ?? this.coldHumidityMinPct,
      coldHumidityMaxPct: coldHumidityMaxPct ?? this.coldHumidityMaxPct,
      doorOpenWarningSeconds:
          doorOpenWarningSeconds ?? this.doorOpenWarningSeconds,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      criticalAlertVibrate: criticalAlertVibrate ?? this.criticalAlertVibrate,
      expiryWarningDays: expiryWarningDays ?? this.expiryWarningDays,
      simulationIntervalSeconds:
          simulationIntervalSeconds ?? this.simulationIntervalSeconds,
      persistIntervalSeconds:
          persistIntervalSeconds ?? this.persistIntervalSeconds,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson({String? userId, String? deviceId}) {
    return {
      if (id != null) 'id': id,
      if (userId != null || this.userId != null)
        'user_id': userId ?? this.userId,
      if (deviceId != null || this.deviceId != null)
        'device_id': deviceId ?? this.deviceId,
      'normal_temp_min_c': normalTempMinC,
      'normal_temp_max_c': normalTempMaxC,
      'normal_humidity_min_pct': normalHumidityMinPct,
      'normal_humidity_max_pct': normalHumidityMaxPct,
      'cold_temp_min_c': coldTempMinC,
      'cold_temp_max_c': coldTempMaxC,
      'cold_humidity_min_pct': coldHumidityMinPct,
      'cold_humidity_max_pct': coldHumidityMaxPct,
      'door_open_warning_seconds': doorOpenWarningSeconds,
      'notifications_enabled': notificationsEnabled,
      'critical_alert_vibrate': criticalAlertVibrate,
      'expiry_warning_days': expiryWarningDays,
      'simulation_interval_seconds': simulationIntervalSeconds,
      'persist_interval_seconds': persistIntervalSeconds,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory DeviceSettings.fromJson(Map<String, dynamic> map) {
    return DeviceSettings(
      id: map['id']?.toString(),
      userId: map['user_id']?.toString(),
      deviceId: map['device_id']?.toString(),
      normalTempMinC: (map['normal_temp_min_c'] as num?)?.toDouble() ?? 15.0,
      normalTempMaxC: (map['normal_temp_max_c'] as num?)?.toDouble() ?? 25.0,
      normalHumidityMinPct:
          (map['normal_humidity_min_pct'] as num?)?.toDouble() ?? 30.0,
      normalHumidityMaxPct:
          (map['normal_humidity_max_pct'] as num?)?.toDouble() ?? 60.0,
      coldTempMinC: (map['cold_temp_min_c'] as num?)?.toDouble() ?? 2.0,
      coldTempMaxC: (map['cold_temp_max_c'] as num?)?.toDouble() ?? 8.0,
      coldHumidityMinPct:
          (map['cold_humidity_min_pct'] as num?)?.toDouble() ?? 35.0,
      coldHumidityMaxPct:
          (map['cold_humidity_max_pct'] as num?)?.toDouble() ?? 65.0,
      doorOpenWarningSeconds:
          (map['door_open_warning_seconds'] as num?)?.toInt() ?? 60,
      notificationsEnabled: map['notifications_enabled'] ?? true,
      criticalAlertVibrate: map['critical_alert_vibrate'] ?? true,
      expiryWarningDays: (map['expiry_warning_days'] as num?)?.toInt() ?? 30,
      simulationIntervalSeconds:
          (map['simulation_interval_seconds'] as num?)?.toInt() ?? 3,
      persistIntervalSeconds:
          (map['persist_interval_seconds'] as num?)?.toInt() ?? 30,
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  static DeviceSettings defaultSettings() =>
      DeviceSettings(updatedAt: DateTime.now());
}
