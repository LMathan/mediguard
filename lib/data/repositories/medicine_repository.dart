import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/medicine.dart';
import '../services/supabase_service.dart';

class MedicineRepository {
  final SupabaseService _supabaseService;
  final _uuid = const Uuid();
  final List<Medicine> _inMemoryStore = [];

  MedicineRepository({SupabaseService? supabaseService})
    : _supabaseService = supabaseService ?? SupabaseService();

  Future<List<Medicine>> getMedicines() async {
    final client = _supabaseService.client;
    final userId = _supabaseService.currentUserId;

    if (client != null && userId != null) {
      try {
        final data = await client
            .from('medicines')
            .select()
            .eq('user_id', userId)
            .neq('status', 'removed')
            .order('name');
        return (data as List).map((e) => Medicine.fromJson(e)).toList();
      } catch (e) {
        debugPrint('[MedicineRepository] Supabase fetch error: $e');
        rethrow;
      }
    }

    return List.unmodifiable(_inMemoryStore.where((m) => m.status != MedicineStatus.removed));
  }

  Future<Medicine?> getMedicineById(String id) async {
    final client = _supabaseService.client;
    final userId = _supabaseService.currentUserId;

    if (client != null && userId != null) {
      try {
        final data = await client
            .from('medicines')
            .select()
            .eq('id', id)
            .eq('user_id', userId)
            .maybeSingle();
        if (data != null) return Medicine.fromJson(data);
      } catch (e) {
        debugPrint('[MedicineRepository] Error fetching medicine $id: $e');
      }
    }

    try {
      return _inMemoryStore.firstWhere((m) => m.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<Medicine?> getMedicineByRfid(String rfidUid) async {
    final client = _supabaseService.client;
    final userId = _supabaseService.currentUserId;

    if (client != null && userId != null) {
      try {
        final data = await client
            .from('medicines')
            .select()
            .eq('rfid_uid', rfidUid)
            .eq('user_id', userId)
            .neq('status', 'removed')
            .maybeSingle();
        if (data != null) return Medicine.fromJson(data);
      } catch (e) {
        debugPrint('[MedicineRepository] Error querying RFID: $e');
      }
    }

    try {
      return _inMemoryStore.firstWhere(
        (m) => m.rfidUid == rfidUid && m.status != MedicineStatus.removed,
      );
    } catch (_) {
      return null;
    }
  }

  Future<Medicine> addMedicine(Medicine medicine) async {
    final medWithId = medicine.id.isEmpty
        ? medicine.copyWith(id: _uuid.v4())
        : medicine;

    final client = _supabaseService.client;
    final userId = _supabaseService.currentUserId;

    if (client != null && userId != null) {
      final payload = medWithId.toJson(userId: userId);
      final res = await client
          .from('medicines')
          .insert(payload)
          .select()
          .single();
      return Medicine.fromJson(res);
    }

    _inMemoryStore.add(medWithId);
    return medWithId;
  }

  Future<Medicine> updateMedicine(Medicine medicine) async {
    final updated = medicine.copyWith(updatedAt: DateTime.now());

    final client = _supabaseService.client;
    final userId = _supabaseService.currentUserId;

    if (client != null && userId != null) {
      final payload = updated.toJson(userId: userId);
      final res = await client
          .from('medicines')
          .update(payload)
          .eq('id', updated.id)
          .eq('user_id', userId)
          .select()
          .single();
      return Medicine.fromJson(res);
    }

    final index = _inMemoryStore.indexWhere((m) => m.id == updated.id);
    if (index != -1) {
      _inMemoryStore[index] = updated;
    }
    return updated;
  }

  Future<void> updateQuantityAndStatus({
    required String id,
    required int newQuantity,
    required MedicineStatus newStatus,
  }) async {
    final client = _supabaseService.client;
    final userId = _supabaseService.currentUserId;

    if (client != null && userId != null) {
      await client
          .from('medicines')
          .update({
            'quantity': newQuantity,
            'status': newStatus.dbValue,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', id)
          .eq('user_id', userId);
    }

    final index = _inMemoryStore.indexWhere((m) => m.id == id);
    if (index != -1) {
      _inMemoryStore[index] = _inMemoryStore[index].copyWith(
        quantity: newQuantity,
        status: newStatus,
        updatedAt: DateTime.now(),
      );
    }
  }

  Future<void> deleteMedicine(String id) async {
    final client = _supabaseService.client;
    final userId = _supabaseService.currentUserId;

    if (client != null && userId != null) {
      await client
          .from('medicines')
          .delete()
          .eq('id', id)
          .eq('user_id', userId);
    }

    _inMemoryStore.removeWhere((m) => m.id == id);
  }
}
