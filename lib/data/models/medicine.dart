enum StorageRequirement {
  normal,
  cold,
  custom;

  String get label {
    switch (this) {
      case StorageRequirement.normal:
        return 'Normal Room Storage (15-25°C)';
      case StorageRequirement.cold:
        return 'Cold Refrigerated Storage (2-8°C)';
      case StorageRequirement.custom:
        return 'Custom Specification';
    }
  }

  static StorageRequirement fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'cold':
        return StorageRequirement.cold;
      case 'custom':
        return StorageRequirement.custom;
      default:
        return StorageRequirement.normal;
    }
  }
}

enum CompartmentType {
  normal,
  cold;

  String get label {
    switch (this) {
      case CompartmentType.normal:
        return 'Normal Compartment';
      case CompartmentType.cold:
        return 'Cold Compartment';
    }
  }

  static CompartmentType fromString(String? val) {
    if (val?.toLowerCase() == 'cold') return CompartmentType.cold;
    return CompartmentType.normal;
  }
}

enum MedicineStatus {
  outside,
  pendingAdd,
  stored,
  pendingRemove,
  removed;

  String get label {
    switch (this) {
      case MedicineStatus.outside:
        return 'Outside Box';
      case MedicineStatus.pendingAdd:
        return 'Pending Addition';
      case MedicineStatus.stored:
        return 'Stored in Box';
      case MedicineStatus.pendingRemove:
        return 'Pending Removal';
      case MedicineStatus.removed:
        return 'Removed';
    }
  }

  static MedicineStatus fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'outside':
        return MedicineStatus.outside;
      case 'pending_add':
        return MedicineStatus.pendingAdd;
      case 'pending_remove':
        return MedicineStatus.pendingRemove;
      case 'removed':
        return MedicineStatus.removed;
      default:
        return MedicineStatus.stored;
    }
  }

  String get dbValue {
    switch (this) {
      case MedicineStatus.outside:
        return 'outside';
      case MedicineStatus.pendingAdd:
        return 'pending_add';
      case MedicineStatus.stored:
        return 'stored';
      case MedicineStatus.pendingRemove:
        return 'pending_remove';
      case MedicineStatus.removed:
        return 'removed';
    }
  }
}

class Medicine {
  final String id;
  final String? userId;
  final String? deviceId;
  final String name;
  final String? brand;
  final String? strength;
  final String? dosageForm;
  final String? batchNumber;
  final DateTime expiryDate;
  final String? rfidUid;
  final StorageRequirement requiredStorage;
  final double? minTemperatureC;
  final double? maxTemperatureC;
  final double? minHumidityPct;
  final double? maxHumidityPct;
  final int quantity;
  final CompartmentType compartment;
  final MedicineStatus status;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Medicine({
    required this.id,
    this.userId,
    this.deviceId,
    required this.name,
    this.brand,
    this.strength,
    this.dosageForm,
    this.batchNumber,
    required this.expiryDate,
    this.rfidUid,
    this.requiredStorage = StorageRequirement.normal,
    this.minTemperatureC,
    this.maxTemperatureC,
    this.minHumidityPct,
    this.maxHumidityPct,
    this.quantity = 1,
    this.compartment = CompartmentType.normal,
    this.status = MedicineStatus.stored,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isExpired {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
    return target.isBefore(today);
  }

  bool isNearingExpiry([int warningDays = 30]) {
    if (isExpired) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
    final diff = target.difference(today).inDays;
    return diff >= 0 && diff <= warningDays;
  }

  int get daysUntilExpiry {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
    return target.difference(today).inDays;
  }

  /// Validates compatibility between medicine storage requirement and compartment
  bool isCompatibleWithCompartment(CompartmentType intendedCompartment) {
    if (requiredStorage == StorageRequirement.cold) {
      return intendedCompartment == CompartmentType.cold;
    }
    if (requiredStorage == StorageRequirement.normal) {
      return intendedCompartment == CompartmentType.normal;
    }
    // Custom requirement checks
    if (minTemperatureC != null && minTemperatureC! < 10.0) {
      return intendedCompartment == CompartmentType.cold;
    }
    return true;
  }

  Medicine copyWith({
    String? id,
    String? userId,
    String? deviceId,
    String? name,
    String? brand,
    String? strength,
    String? dosageForm,
    String? batchNumber,
    DateTime? expiryDate,
    String? rfidUid,
    StorageRequirement? requiredStorage,
    double? minTemperatureC,
    double? maxTemperatureC,
    double? minHumidityPct,
    double? maxHumidityPct,
    int? quantity,
    CompartmentType? compartment,
    MedicineStatus? status,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Medicine(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      deviceId: deviceId ?? this.deviceId,
      name: name ?? this.name,
      brand: brand ?? this.brand,
      strength: strength ?? this.strength,
      dosageForm: dosageForm ?? this.dosageForm,
      batchNumber: batchNumber ?? this.batchNumber,
      expiryDate: expiryDate ?? this.expiryDate,
      rfidUid: rfidUid ?? this.rfidUid,
      requiredStorage: requiredStorage ?? this.requiredStorage,
      minTemperatureC: minTemperatureC ?? this.minTemperatureC,
      maxTemperatureC: maxTemperatureC ?? this.maxTemperatureC,
      minHumidityPct: minHumidityPct ?? this.minHumidityPct,
      maxHumidityPct: maxHumidityPct ?? this.maxHumidityPct,
      quantity: quantity ?? this.quantity,
      compartment: compartment ?? this.compartment,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson({String? userId, String? deviceId}) {
    return {
      'id': id,
      if (userId != null || this.userId != null)
        'user_id': userId ?? this.userId,
      if (deviceId != null || this.deviceId != null)
        'device_id': deviceId ?? this.deviceId,
      'name': name,
      'brand': brand,
      'strength': strength,
      'dosage_form': dosageForm,
      'batch_number': batchNumber,
      'expiry_date': expiryDate.toIso8601String().split('T').first,
      'rfid_uid': rfidUid,
      'required_storage': requiredStorage.name,
      'min_temperature_c': minTemperatureC,
      'max_temperature_c': maxTemperatureC,
      'min_humidity_pct': minHumidityPct,
      'max_humidity_pct': maxHumidityPct,
      'quantity': quantity,
      'compartment': compartment.name,
      'status': status.dbValue,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Medicine.fromJson(Map<String, dynamic> map) {
    return Medicine(
      id: map['id']?.toString() ?? '',
      userId: map['user_id']?.toString(),
      deviceId: map['device_id']?.toString(),
      name: map['name']?.toString() ?? 'Unnamed Medicine',
      brand: map['brand']?.toString(),
      strength: map['strength']?.toString(),
      dosageForm: map['dosage_form']?.toString(),
      batchNumber: map['batch_number']?.toString(),
      expiryDate: map['expiry_date'] != null
          ? DateTime.tryParse(map['expiry_date'].toString()) ?? DateTime.now()
          : DateTime.now(),
      rfidUid: map['rfid_uid']?.toString(),
      requiredStorage: StorageRequirement.fromString(
        map['required_storage']?.toString(),
      ),
      minTemperatureC: (map['min_temperature_c'] as num?)?.toDouble(),
      maxTemperatureC: (map['max_temperature_c'] as num?)?.toDouble(),
      minHumidityPct: (map['min_humidity_pct'] as num?)?.toDouble(),
      maxHumidityPct: (map['max_humidity_pct'] as num?)?.toDouble(),
      quantity: (map['quantity'] as num?)?.toInt() ?? 1,
      compartment: CompartmentType.fromString(map['compartment']?.toString()),
      status: MedicineStatus.fromString(map['status']?.toString()),
      notes: map['notes']?.toString(),
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
