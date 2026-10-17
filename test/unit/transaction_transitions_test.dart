import 'package:flutter_test/flutter_test.dart';
import 'package:mediguard/data/models/inventory_transaction.dart';
import 'package:mediguard/data/models/medicine.dart';
import 'package:mediguard/data/repositories/medicine_repository.dart';
import 'package:mediguard/data/repositories/transaction_repository.dart';

void main() {
  group('Inventory Transaction State Transitions & Recovery', () {
    late MedicineRepository medRepo;
    late TransactionRepository txRepo;

    setUp(() async {
      medRepo = MedicineRepository();
      txRepo = TransactionRepository(medicineRepository: medRepo);
      await medRepo.addMedicine(Medicine(
        id: 'med-001',
        name: 'Insulin Glargine',
        expiryDate: DateTime.now().add(const Duration(days: 90)),
        requiredStorage: StorageRequirement.cold,
        compartment: CompartmentType.cold,
        quantity: 5,
        status: MedicineStatus.stored,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
    });

    test(
      'Confirmed add transaction increases medicine quantity atomically',
      () async {
        final medicines = await medRepo.getMedicines();
        final med = medicines.first; // e.g. Lantus (initial quantity: 5)
        final initialQuantity = med.quantity;

        final tx = InventoryTransaction(
          id: 'tx-test-add',
          medicineId: med.id,
          medicineName: med.name,
          action: TransactionAction.add,
          quantityChange: 3,
          compartment: med.compartment,
          rfidUid: med.rfidUid,
          status: TransactionStatus.pending,
          initiatedAt: DateTime.now(),
        );

        final created = await txRepo.createPendingTransaction(tx);
        expect(created.isPending, isTrue);

        // Confirm transaction
        final confirmedOk = await txRepo.confirmTransaction(
          transactionId: created.id,
          confirm: true,
          notes: 'Verified inbound',
        );
        expect(confirmedOk, isTrue);

        final updatedMed = await medRepo.getMedicineById(med.id);
        expect(updatedMed?.quantity, equals(initialQuantity + 3));
        expect(updatedMed?.status, equals(MedicineStatus.stored));
      },
    );

    test(
      'Cancelling a pending transaction does NOT change inventory quantity',
      () async {
        final medicines = await medRepo.getMedicines();
        final med = medicines.last;
        final initialQuantity = med.quantity;

        final tx = InventoryTransaction(
          id: 'tx-test-cancel',
          medicineId: med.id,
          medicineName: med.name,
          action: TransactionAction.remove,
          quantityChange: -2,
          compartment: med.compartment,
          rfidUid: med.rfidUid,
          status: TransactionStatus.pending,
          initiatedAt: DateTime.now(),
        );

        final created = await txRepo.createPendingTransaction(tx);

        // Cancel transaction
        final cancelOk = await txRepo.confirmTransaction(
          transactionId: created.id,
          confirm: false,
          notes: 'User cancelled door open',
        );
        expect(cancelOk, isTrue);

        final updatedMed = await medRepo.getMedicineById(med.id);
        expect(
          updatedMed?.quantity,
          equals(initialQuantity),
        ); // Quantity preserved unchanged!
      },
    );
  });
}
