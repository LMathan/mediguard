import 'package:flutter_test/flutter_test.dart';
import 'package:mediguard/data/models/unregistered_medicine.dart';

void main() {
  group('Unregistered Medicine Model Tests', () {
    test('Correctly parses JSON from Supabase unregistered_medicines table', () {
      final json = {
        'id': '778a8f84-1888-472e-8395-8e2b8110543e',
        'rfid_uid': 'E28011700000025A',
        'compartment': 'cold',
        'device_id': 'mediguard-container-01',
        'status': 'pending',
        'scan_count': 3,
        'first_scanned_at': '2026-10-30T10:00:00.000Z',
        'last_scanned_at': '2026-10-30T10:15:30.000Z',
        'metadata': {'reader_port': 1},
      };

      final item = UnregisteredMedicine.fromJson(json);

      expect(item.id, equals('778a8f84-1888-472e-8395-8e2b8110543e'));
      expect(item.rfidUid, equals('E28011700000025A'));
      expect(item.compartment, equals('cold'));
      expect(item.deviceId, equals('mediguard-container-01'));
      expect(item.status, equals('pending'));
      expect(item.scanCount, equals(3));
      expect(item.firstScannedAt, isNotNull);
      expect(item.lastScannedAt, isNotNull);
      expect(item.metadata?['reader_port'], equals(1));
    });

    test('Serializes to JSON correctly', () {
      final item = UnregisteredMedicine(
        id: 'test-1',
        rfidUid: 'E28099999',
        compartment: 'normal',
        firstScannedAt: DateTime(2026, 10, 30, 10, 0),
        lastScannedAt: DateTime(2026, 10, 30, 10, 5),
      );

      final json = item.toJson();
      expect(json['rfid_uid'], equals('E28099999'));
      expect(json['compartment'], equals('normal'));
      expect(json['status'], equals('pending'));
      expect(json['scan_count'], equals(1));
    });
  });
}

