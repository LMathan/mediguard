import 'package:flutter_test/flutter_test.dart';
import 'package:mediguard/data/models/medicine.dart';

void main() {
  group('Medicine Expiry and Storage Rule Calculations', () {
    final now = DateTime.now();

    test('Medicine with past date is flagged as expired', () {
      final expiredMed = Medicine(
        id: 'test-1',
        name: 'Expired Antibiotic',
        expiryDate: now.subtract(const Duration(days: 5)),
        requiredStorage: StorageRequirement.normal,
        createdAt: now.subtract(const Duration(days: 30)),
        updatedAt: now.subtract(const Duration(days: 30)),
      );

      expect(expiredMed.isExpired, isTrue);
      expect(expiredMed.daysUntilExpiry, isNegative);
      expect(
        expiredMed.isNearingExpiry(30),
        isFalse,
      ); // Already expired, not just nearing
    });

    test('Medicine expiring in 10 days is flagged as nearing expiry', () {
      final nearingMed = Medicine(
        id: 'test-2',
        name: 'Augmentin Suspension',
        expiryDate: now.add(const Duration(days: 10)),
        requiredStorage: StorageRequirement.cold,
        createdAt: now,
        updatedAt: now,
      );

      expect(nearingMed.isExpired, isFalse);
      expect(nearingMed.isNearingExpiry(30), isTrue);
      expect(nearingMed.daysUntilExpiry, equals(10));
    });

    test(
      'Cold storage requirement enforces cold compartment compatibility',
      () {
        final coldMed = Medicine(
          id: 'test-3',
          name: 'Insulin Glargine',
          expiryDate: now.add(const Duration(days: 180)),
          requiredStorage: StorageRequirement.cold,
          createdAt: now,
          updatedAt: now,
        );

        expect(
          coldMed.isCompatibleWithCompartment(CompartmentType.cold),
          isTrue,
        );
        expect(
          coldMed.isCompatibleWithCompartment(CompartmentType.normal),
          isFalse,
        );
      },
    );

    test('Normal room storage accepts normal compartment', () {
      final roomMed = Medicine(
        id: 'test-4',
        name: 'Paracetamol',
        expiryDate: now.add(const Duration(days: 365)),
        requiredStorage: StorageRequirement.normal,
        createdAt: now,
        updatedAt: now,
      );

      expect(
        roomMed.isCompatibleWithCompartment(CompartmentType.normal),
        isTrue,
      );
      expect(
        roomMed.isCompatibleWithCompartment(CompartmentType.cold),
        isFalse,
      );
    });
  });
}
