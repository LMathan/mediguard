import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/inventory_transaction.dart';
import '../models/medicine.dart';
import '../services/supabase_service.dart';
import 'medicine_repository.dart';

class TransactionRepository {
  final SupabaseService _supabaseService;
  final MedicineRepository _medicineRepository;
  final _uuid = const Uuid();
  final List<InventoryTransaction> _inMemoryTransactions = [];

  TransactionRepository({
    SupabaseService? supabaseService,
    MedicineRepository? medicineRepository,
  }) : _supabaseService = supabaseService ?? SupabaseService(),
       _medicineRepository = medicineRepository ?? MedicineRepository();

  Future<List<InventoryTransaction>> getTransactions() async {
    final client = _supabaseService.client;
    final userId = _supabaseService.currentUserId;

    if (client != null && userId != null) {
      try {
        final data = await client
            .from('inventory_transactions')
            .select('*, medicines(name)')
            .eq('user_id', userId)
            .order('initiated_at', ascending: false)
            .limit(50);
        return (data as List)
            .map((e) => InventoryTransaction.fromJson(e))
            .toList();
      } catch (e) {
        debugPrint('[TransactionRepository] Supabase fetch error: $e');
      }
    }

    return List.unmodifiable(_inMemoryTransactions);
  }

  Future<InventoryTransaction> createPendingTransaction(
    InventoryTransaction tx,
  ) async {
    final newTx = tx.id.isEmpty ? tx.copyWith(id: _uuid.v4()) : tx;

    final client = _supabaseService.client;
    final userId = _supabaseService.currentUserId;

    if (client != null && userId != null) {
      final payload = newTx.toJson(userId: userId);
      final res = await client
          .from('inventory_transactions')
          .insert(payload)
          .select()
          .single();
      final created = InventoryTransaction.fromJson(
        res,
        medicineName: tx.medicineName,
      );

      // Update medicine status to pending
      if (tx.medicineId != null) {
        final pendingStatus = tx.action == TransactionAction.add
            ? MedicineStatus.pendingAdd
            : MedicineStatus.pendingRemove;
        final med = await _medicineRepository.getMedicineById(tx.medicineId!);
        if (med != null) {
          await _medicineRepository.updateMedicine(
            med.copyWith(status: pendingStatus),
          );
        }
      }

      return created;
    }

    // In-memory fallback for unit tests
    _inMemoryTransactions.insert(0, newTx);
    if (newTx.medicineId != null) {
      final pendingStatus = newTx.action == TransactionAction.add
          ? MedicineStatus.pendingAdd
          : MedicineStatus.pendingRemove;
      final med = await _medicineRepository.getMedicineById(newTx.medicineId!);
      if (med != null) {
        await _medicineRepository.updateMedicine(
          med.copyWith(status: pendingStatus),
        );
      }
    }
    return newTx;
  }

  Future<bool> confirmTransaction({
    required String transactionId,
    required bool confirm,
    String? notes,
  }) async {
    final client = _supabaseService.client;
    final userId = _supabaseService.currentUserId;

    if (client != null && userId != null) {
      try {
        // Execute atomic PostgreSQL function
        final res = await client.rpc(
          'confirm_inventory_transaction',
          params: {
            'p_transaction_id': transactionId,
            'p_confirm': confirm,
            'p_notes': notes,
          },
        );
        debugPrint('[TransactionRepository] RPC confirmation result: $res');
        return true;
      } catch (e) {
        debugPrint('[TransactionRepository] RPC confirmation error: $e');
        rethrow;
      }
    }

    // In-memory update for unit test harnesses
    final txIndex = _inMemoryTransactions.indexWhere((t) => t.id == transactionId);
    if (txIndex == -1) return false;

    final tx = _inMemoryTransactions[txIndex];
    if (tx.status != TransactionStatus.pending) return false;

    if (!confirm) {
      _inMemoryTransactions[txIndex] = tx.copyWith(
        status: TransactionStatus.cancelled,
        confirmedAt: DateTime.now(),
        notes: notes ?? tx.notes,
      );

      if (tx.medicineId != null) {
        final med = await _medicineRepository.getMedicineById(tx.medicineId!);
        if (med != null) {
          await _medicineRepository.updateMedicine(
            med.copyWith(
              status: tx.action == TransactionAction.add
                  ? MedicineStatus.outside
                  : MedicineStatus.stored,
            ),
          );
        }
      }
      return true;
    }

    // Confirmed
    _inMemoryTransactions[txIndex] = tx.copyWith(
      status: TransactionStatus.confirmed,
      confirmedAt: DateTime.now(),
      notes: notes ?? tx.notes,
    );

    if (tx.medicineId != null) {
      final med = await _medicineRepository.getMedicineById(tx.medicineId!);
      if (med != null) {
        var newQty = med.quantity + tx.quantityChange;
        if (newQty < 0) newQty = 0;

        MedicineStatus newStatus = med.status;
        if (tx.action == TransactionAction.remove && newQty == 0) {
          newStatus = MedicineStatus.removed;
        } else {
          newStatus = MedicineStatus.stored;
        }

        await _medicineRepository.updateQuantityAndStatus(
          id: med.id,
          newQuantity: newQty,
          newStatus: newStatus,
        );
      }
    }

    return true;
  }
}
