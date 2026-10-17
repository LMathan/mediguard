import 'medicine.dart';

enum TransactionAction {
  add,
  remove,
  adjustQuantity;

  String get label {
    switch (this) {
      case TransactionAction.add:
        return 'Medicine Inbound (Add)';
      case TransactionAction.remove:
        return 'Medicine Outbound (Remove)';
      case TransactionAction.adjustQuantity:
        return 'Manual Stock Adjustment';
    }
  }

  static TransactionAction fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'remove':
        return TransactionAction.remove;
      case 'adjust_quantity':
        return TransactionAction.adjustQuantity;
      default:
        return TransactionAction.add;
    }
  }

  String get dbValue {
    switch (this) {
      case TransactionAction.add:
        return 'add';
      case TransactionAction.remove:
        return 'remove';
      case TransactionAction.adjustQuantity:
        return 'adjust_quantity';
    }
  }
}

enum TransactionStatus {
  pending,
  confirmed,
  cancelled,
  failed;

  String get label {
    switch (this) {
      case TransactionStatus.pending:
        return 'Pending Confirmation';
      case TransactionStatus.confirmed:
        return 'Confirmed';
      case TransactionStatus.cancelled:
        return 'Cancelled';
      case TransactionStatus.failed:
        return 'Failed';
    }
  }

  static TransactionStatus fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'confirmed':
        return TransactionStatus.confirmed;
      case 'cancelled':
        return TransactionStatus.cancelled;
      case 'failed':
        return TransactionStatus.failed;
      default:
        return TransactionStatus.pending;
    }
  }
}

class InventoryTransaction {
  final String id;
  final String? userId;
  final String? medicineId;
  final String? medicineName;
  final String? deviceId;
  final TransactionAction action;
  final int quantityChange;
  final CompartmentType compartment;
  final String? rfidUid;
  final String initiationMethod; // 'rfid' | 'manual'
  final String confirmationMethod; // 'app' | 'hardware_button'
  final TransactionStatus status;
  final DateTime initiatedAt;
  final DateTime? confirmedAt;
  final String? notes;

  const InventoryTransaction({
    required this.id,
    this.userId,
    this.medicineId,
    this.medicineName,
    this.deviceId,
    required this.action,
    required this.quantityChange,
    required this.compartment,
    this.rfidUid,
    this.initiationMethod = 'manual',
    this.confirmationMethod = 'app',
    this.status = TransactionStatus.pending,
    required this.initiatedAt,
    this.confirmedAt,
    this.notes,
  });

  bool get isPending => status == TransactionStatus.pending;
  bool get isConfirmed => status == TransactionStatus.confirmed;

  InventoryTransaction copyWith({
    String? id,
    String? userId,
    String? medicineId,
    String? medicineName,
    String? deviceId,
    TransactionAction? action,
    int? quantityChange,
    CompartmentType? compartment,
    String? rfidUid,
    String? initiationMethod,
    String? confirmationMethod,
    TransactionStatus? status,
    DateTime? initiatedAt,
    DateTime? confirmedAt,
    String? notes,
  }) {
    return InventoryTransaction(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      medicineId: medicineId ?? this.medicineId,
      medicineName: medicineName ?? this.medicineName,
      deviceId: deviceId ?? this.deviceId,
      action: action ?? this.action,
      quantityChange: quantityChange ?? this.quantityChange,
      compartment: compartment ?? this.compartment,
      rfidUid: rfidUid ?? this.rfidUid,
      initiationMethod: initiationMethod ?? this.initiationMethod,
      confirmationMethod: confirmationMethod ?? this.confirmationMethod,
      status: status ?? this.status,
      initiatedAt: initiatedAt ?? this.initiatedAt,
      confirmedAt: confirmedAt ?? this.confirmedAt,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson({String? userId}) {
    return {
      'id': id,
      if (userId != null || this.userId != null)
        'user_id': userId ?? this.userId,
      'medicine_id': medicineId,
      'device_id': deviceId,
      'action': action.dbValue,
      'quantity_change': quantityChange,
      'compartment': compartment.name,
      'rfid_uid': rfidUid,
      'initiation_method': initiationMethod,
      'confirmation_method': confirmationMethod,
      'status': status.name,
      'initiated_at': initiatedAt.toIso8601String(),
      'confirmed_at': confirmedAt?.toIso8601String(),
      'notes': notes,
    };
  }

  factory InventoryTransaction.fromJson(
    Map<String, dynamic> map, {
    String? medicineName,
  }) {
    return InventoryTransaction(
      id: map['id']?.toString() ?? '',
      userId: map['user_id']?.toString(),
      medicineId: map['medicine_id']?.toString(),
      medicineName:
          medicineName ??
          map['medicine_name']?.toString() ??
          (map['medicines'] is Map
              ? map['medicines']['name']?.toString()
              : null),
      deviceId: map['device_id']?.toString(),
      action: TransactionAction.fromString(map['action']?.toString()),
      quantityChange: (map['quantity_change'] as num?)?.toInt() ?? 0,
      compartment: CompartmentType.fromString(map['compartment']?.toString()),
      rfidUid: map['rfid_uid']?.toString(),
      initiationMethod: map['initiation_method']?.toString() ?? 'manual',
      confirmationMethod: map['confirmation_method']?.toString() ?? 'app',
      status: TransactionStatus.fromString(map['status']?.toString()),
      initiatedAt: map['initiated_at'] != null
          ? DateTime.tryParse(map['initiated_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      confirmedAt: map['confirmed_at'] != null
          ? DateTime.tryParse(map['confirmed_at'].toString())
          : null,
      notes: map['notes']?.toString(),
    );
  }
}
