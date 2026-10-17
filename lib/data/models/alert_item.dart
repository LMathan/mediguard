import 'sensor_reading.dart';

enum AlertSeverity {
  info,
  warning,
  critical;

  String get label {
    switch (this) {
      case AlertSeverity.info:
        return 'Info';
      case AlertSeverity.warning:
        return 'Warning';
      case AlertSeverity.critical:
        return 'Critical';
    }
  }

  static AlertSeverity fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'critical':
        return AlertSeverity.critical;
      case 'warning':
        return AlertSeverity.warning;
      default:
        return AlertSeverity.info;
    }
  }
}

enum AlertStatus {
  active,
  acknowledged,
  resolved;

  String get label {
    switch (this) {
      case AlertStatus.active:
        return 'Active';
      case AlertStatus.acknowledged:
        return 'Acknowledged';
      case AlertStatus.resolved:
        return 'Resolved';
    }
  }

  static AlertStatus fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'acknowledged':
        return AlertStatus.acknowledged;
      case 'resolved':
        return AlertStatus.resolved;
      default:
        return AlertStatus.active;
    }
  }
}

enum AlertType {
  highTemp,
  lowTemp,
  highHumidity,
  lowHumidity,
  doorLeftOpen,
  deviceOffline,
  sensorError,
  medicineNearingExpiry,
  medicineExpired,
  inventoryEvent,
  system;

  String get dbValue {
    switch (this) {
      case AlertType.highTemp:
        return 'high_temp';
      case AlertType.lowTemp:
        return 'low_temp';
      case AlertType.highHumidity:
        return 'high_humidity';
      case AlertType.lowHumidity:
        return 'low_humidity';
      case AlertType.doorLeftOpen:
        return 'door_left_open';
      case AlertType.deviceOffline:
        return 'device_offline';
      case AlertType.sensorError:
        return 'sensor_error';
      case AlertType.medicineNearingExpiry:
        return 'medicine_nearing_expiry';
      case AlertType.medicineExpired:
        return 'medicine_expired';
      case AlertType.inventoryEvent:
        return 'inventory_event';
      case AlertType.system:
        return 'system';
    }
  }

  static AlertType fromString(String? val) {
    switch (val) {
      case 'high_temp':
        return AlertType.highTemp;
      case 'low_temp':
        return AlertType.lowTemp;
      case 'high_humidity':
        return AlertType.highHumidity;
      case 'low_humidity':
        return AlertType.lowHumidity;
      case 'door_left_open':
        return AlertType.doorLeftOpen;
      case 'device_offline':
        return AlertType.deviceOffline;
      case 'sensor_error':
        return AlertType.sensorError;
      case 'medicine_nearing_expiry':
        return AlertType.medicineNearingExpiry;
      case 'medicine_expired':
        return AlertType.medicineExpired;
      case 'inventory_event':
        return AlertType.inventoryEvent;
      default:
        return AlertType.system;
    }
  }
}

class AlertItem {
  final String id;
  final String? userId;
  final String? deviceId;
  final String? medicineId;
  final AlertType type;
  final String title;
  final String message;
  final AlertSeverity severity;
  final AlertStatus status;
  final DataSourceType dataSource;
  final DateTime createdAt;
  final DateTime? acknowledgedAt;
  final DateTime? resolvedAt;

  const AlertItem({
    required this.id,
    this.userId,
    this.deviceId,
    this.medicineId,
    required this.type,
    required this.title,
    required this.message,
    required this.severity,
    this.status = AlertStatus.active,
    this.dataSource = DataSourceType.simulated,
    required this.createdAt,
    this.acknowledgedAt,
    this.resolvedAt,
  });

  bool get isActive => status == AlertStatus.active;
  bool get isCritical => severity == AlertSeverity.critical;

  AlertItem copyWith({
    String? id,
    String? userId,
    String? deviceId,
    String? medicineId,
    AlertType? type,
    String? title,
    String? message,
    AlertSeverity? severity,
    AlertStatus? status,
    DataSourceType? dataSource,
    DateTime? createdAt,
    DateTime? acknowledgedAt,
    DateTime? resolvedAt,
  }) {
    return AlertItem(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      deviceId: deviceId ?? this.deviceId,
      medicineId: medicineId ?? this.medicineId,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      severity: severity ?? this.severity,
      status: status ?? this.status,
      dataSource: dataSource ?? this.dataSource,
      createdAt: createdAt ?? this.createdAt,
      acknowledgedAt: acknowledgedAt ?? this.acknowledgedAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
    );
  }

  Map<String, dynamic> toJson({String? userId}) {
    return {
      'id': id,
      if (userId != null || this.userId != null)
        'user_id': userId ?? this.userId,
      'device_id': deviceId,
      'medicine_id': medicineId,
      'type': type.dbValue,
      'title': title,
      'message': message,
      'severity': severity.name,
      'status': status.name,
      'data_source': dataSource.name,
      'created_at': createdAt.toIso8601String(),
      'acknowledged_at': acknowledgedAt?.toIso8601String(),
      'resolved_at': resolvedAt?.toIso8601String(),
    };
  }

  factory AlertItem.fromJson(Map<String, dynamic> map) {
    return AlertItem(
      id: map['id']?.toString() ?? '',
      userId: map['user_id']?.toString(),
      deviceId: map['device_id']?.toString(),
      medicineId: map['medicine_id']?.toString(),
      type: AlertType.fromString(map['type']?.toString()),
      title: map['title']?.toString() ?? 'Alert',
      message: map['message']?.toString() ?? '',
      severity: AlertSeverity.fromString(map['severity']?.toString()),
      status: AlertStatus.fromString(map['status']?.toString()),
      dataSource: DataSourceType.fromString(map['data_source']?.toString()),
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      acknowledgedAt: map['acknowledged_at'] != null
          ? DateTime.tryParse(map['acknowledged_at'].toString())
          : null,
      resolvedAt: map['resolved_at'] != null
          ? DateTime.tryParse(map['resolved_at'].toString())
          : null,
    );
  }
}
