class UnregisteredMedicine {
  final String id;
  final String rfidUid;
  final String compartment;
  final String? deviceId;
  final String status;
  final int scanCount;
  final DateTime firstScannedAt;
  final DateTime lastScannedAt;
  final Map<String, dynamic>? metadata;

  const UnregisteredMedicine({
    required this.id,
    required this.rfidUid,
    this.compartment = 'unknown',
    this.deviceId,
    this.status = 'pending',
    this.scanCount = 1,
    required this.firstScannedAt,
    required this.lastScannedAt,
    this.metadata,
  });

  factory UnregisteredMedicine.fromJson(Map<String, dynamic> json) {
    return UnregisteredMedicine(
      id: json['id']?.toString() ?? '',
      rfidUid: json['rfid_uid']?.toString() ?? '',
      compartment: json['compartment']?.toString() ?? 'unknown',
      deviceId: json['device_id']?.toString(),
      status: json['status']?.toString() ?? 'pending',
      scanCount: (json['scan_count'] as num?)?.toInt() ?? 1,
      firstScannedAt: json['first_scanned_at'] != null
          ? DateTime.tryParse(json['first_scanned_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      lastScannedAt: json['last_scanned_at'] != null
          ? DateTime.tryParse(json['last_scanned_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      metadata: json['metadata'] is Map<String, dynamic>
          ? json['metadata'] as Map<String, dynamic>
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'rfid_uid': rfidUid,
      'compartment': compartment,
      if (deviceId != null) 'device_id': deviceId,
      'status': status,
      'scan_count': scanCount,
      'first_scanned_at': firstScannedAt.toIso8601String(),
      'last_scanned_at': lastScannedAt.toIso8601String(),
      if (metadata != null) 'metadata': metadata,
    };
  }
}

