import 'sensor_reading.dart';

class DeviceInfo {
  final String id;
  final String? userId;
  final String deviceName;
  final String modelVersion;
  final String? serialNumber;
  final bool isOnline;
  final DataSourceType dataSource;
  final DateTime? lastSeenAt;
  final DateTime createdAt;

  const DeviceInfo({
    required this.id,
    this.userId,
    required this.deviceName,
    this.modelVersion = 'ESP32-MediGuard-v1',
    this.serialNumber,
    this.isOnline = true,
    this.dataSource = DataSourceType.simulated,
    this.lastSeenAt,
    required this.createdAt,
  });

  DeviceInfo copyWith({
    String? id,
    String? userId,
    String? deviceName,
    String? modelVersion,
    String? serialNumber,
    bool? isOnline,
    DataSourceType? dataSource,
    DateTime? lastSeenAt,
    DateTime? createdAt,
  }) {
    return DeviceInfo(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      deviceName: deviceName ?? this.deviceName,
      modelVersion: modelVersion ?? this.modelVersion,
      serialNumber: serialNumber ?? this.serialNumber,
      isOnline: isOnline ?? this.isOnline,
      dataSource: dataSource ?? this.dataSource,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson({String? userId}) {
    return {
      'id': id,
      if (userId != null || this.userId != null)
        'user_id': userId ?? this.userId,
      'device_name': deviceName,
      'model_version': modelVersion,
      'serial_number': serialNumber,
      'is_online': isOnline,
      'data_source': dataSource.name,
      'last_seen_at': lastSeenAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory DeviceInfo.fromJson(Map<String, dynamic> map) {
    return DeviceInfo(
      id: map['id']?.toString() ?? '',
      userId: map['user_id']?.toString(),
      deviceName: map['device_name']?.toString() ?? 'MediGuard Box',
      modelVersion: map['model_version']?.toString() ?? 'ESP32-MediGuard-v1',
      serialNumber: map['serial_number']?.toString(),
      isOnline: map['is_online'] ?? true,
      dataSource: DataSourceType.fromString(map['data_source']?.toString()),
      lastSeenAt: map['last_seen_at'] != null
          ? DateTime.tryParse(map['last_seen_at'].toString())
          : null,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
