import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/alert_item.dart';
import '../../data/models/device_info.dart';
import '../../data/models/device_settings.dart';
import '../../data/models/inventory_transaction.dart';
import '../../data/models/medicine.dart';
import '../../data/models/sensor_reading.dart';
import '../../data/repositories/alert_repository.dart';
import '../../data/repositories/medicine_repository.dart';
import '../../data/repositories/sensor_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../data/services/demo_sensor_service.dart';
import '../../data/services/hardware_sensor_service.dart';
import '../../data/services/notification_service.dart';
import '../../data/services/sensor_data_source.dart';
import '../../data/services/supabase_service.dart';

// 1. Core Services Providers
final supabaseServiceProvider = Provider<SupabaseService>((ref) {
  return SupabaseService();
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

final hardwareSensorServiceProvider = Provider<HardwareSensorService>((ref) {
  final supabase = ref.watch(supabaseServiceProvider);
  final service = HardwareSensorService(
    supabase: supabase.client,
    userId: supabase.currentUserId,
  );
  service.initialize();
  ref.onDispose(() {
    service.dispose();
  });
  return service;
});

final demoSensorServiceProvider = Provider<DemoSensorService>((ref) {
  final service = DemoSensorService();
  service.initialize();
  ref.onDispose(() {
    service.dispose();
  });
  return service;
});

// Currently active SensorDataSource (strictly uses real database hardware service)
final sensorDataSourceProvider = Provider<SensorDataSource>((ref) {
  return ref.watch(hardwareSensorServiceProvider);
});

// 2. Repositories
final medicineRepositoryProvider = Provider<MedicineRepository>((ref) {
  final supabase = ref.watch(supabaseServiceProvider);
  return MedicineRepository(supabaseService: supabase);
});

final sensorRepositoryProvider = Provider<SensorRepository>((ref) {
  final supabase = ref.watch(supabaseServiceProvider);
  return SensorRepository(supabaseService: supabase);
});

final alertRepositoryProvider = Provider<AlertRepository>((ref) {
  final supabase = ref.watch(supabaseServiceProvider);
  final notif = ref.watch(notificationServiceProvider);
  return AlertRepository(supabaseService: supabase, notificationService: notif);
});

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  final supabase = ref.watch(supabaseServiceProvider);
  final medRepo = ref.watch(medicineRepositoryProvider);
  return TransactionRepository(
    supabaseService: supabase,
    medicineRepository: medRepo,
  );
});

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  final supabase = ref.watch(supabaseServiceProvider);
  return SettingsRepository(supabaseService: supabase);
});

// 3. Device Settings Notifier
class DeviceSettingsNotifier extends AsyncNotifier<DeviceSettings> {
  @override
  Future<DeviceSettings> build() async {
    final repo = ref.watch(settingsRepositoryProvider);
    return await repo.getSettings();
  }

  Future<void> updateSettings(DeviceSettings newSettings) async {
    state = const AsyncValue.loading();
    try {
      final repo = ref.read(settingsRepositoryProvider);
      final updated = await repo.updateSettings(newSettings);
      state = AsyncValue.data(updated);

      // Also update simulation interval if changed
      ref
          .read(demoSensorServiceProvider)
          .updateInterval(updated.simulationIntervalSeconds);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final deviceSettingsProvider =
    AsyncNotifierProvider<DeviceSettingsNotifier, DeviceSettings>(() {
      return DeviceSettingsNotifier();
    });

// 4. Device Info Notifier
class DeviceInfoNotifier extends AsyncNotifier<DeviceInfo> {
  @override
  Future<DeviceInfo> build() async {
    final repo = ref.watch(settingsRepositoryProvider);
    return await repo.getDeviceInfo();
  }

  Future<void> updateDevice(DeviceInfo info) async {
    state = const AsyncValue.loading();
    try {
      final repo = ref.read(settingsRepositoryProvider);
      final updated = await repo.updateDeviceInfo(info);
      state = AsyncValue.data(updated);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final deviceInfoProvider =
    AsyncNotifierProvider<DeviceInfoNotifier, DeviceInfo>(() {
      return DeviceInfoNotifier();
    });

// 5. Sensor Reading Stream & Latest Reading Provider
final sensorReadingStreamProvider = StreamProvider<SensorReading>((ref) {
  final dataSource = ref.watch(sensorDataSourceProvider);
  return dataSource.readingStream;
});

// 6. Sensor History Provider with parameter (Duration window)
final sensorHistoryProvider =
    FutureProvider.family<List<SensorReading>, Duration>((ref, window) async {
      final repo = ref.watch(sensorRepositoryProvider);
      return await repo.getHistory(window: window);
    });

// 7. Overall System Status Provider
final overallStatusProvider = Provider<OverallStatus>((ref) {
  final dataSource = ref.watch(sensorDataSourceProvider);
  final readingAsync = ref.watch(sensorReadingStreamProvider);
  final settingsAsync = ref.watch(deviceSettingsProvider);

  final reading = readingAsync.value ?? dataSource.latestReading;
  final settings = settingsAsync.value ?? DeviceSettings.defaultSettings();

  // If no readings have been recorded in DB yet
  if (reading.recordedAt.millisecondsSinceEpoch == 0) {
    return OverallStatus.offline;
  }

  // If telemetry is older than 60 seconds, device is marked offline, never false normal
  if (reading.isStale()) {
    return OverallStatus.offline;
  }

  if (reading.sensorHealth == SensorHealth.error) {
    return OverallStatus.critical;
  }

  // Check critical thresholds
  if (reading.coldTemperatureC > (settings.coldTempMaxC + 4.0) ||
      reading.coldTemperatureC < (settings.coldTempMinC - 3.0) ||
      reading.normalTemperatureC > (settings.normalTempMaxC + 6.0)) {
    return OverallStatus.critical;
  }

  // Check warning thresholds
  if (reading.coldTemperatureC > settings.coldTempMaxC ||
      reading.coldTemperatureC < settings.coldTempMinC ||
      reading.normalTemperatureC > settings.normalTempMaxC ||
      reading.normalTemperatureC < settings.normalTempMinC ||
      reading.sensorHealth == SensorHealth.warning ||
      reading.coldDoorOpen ||
      reading.normalDoorOpen) {
    return OverallStatus.warning;
  }

  return OverallStatus.normal;
});

// 8. Medicine List Notifier (with search and filter states)
enum InventoryFilter { all, normal, cold, nearingExpiry, expired }

enum InventorySort { name, expiry, quantity, recentlyAdded }

class InventoryFilterState {
  final String searchQuery;
  final InventoryFilter filter;
  final InventorySort sort;

  const InventoryFilterState({
    this.searchQuery = '',
    this.filter = InventoryFilter.all,
    this.sort = InventorySort.name,
  });

  InventoryFilterState copyWith({
    String? searchQuery,
    InventoryFilter? filter,
    InventorySort? sort,
  }) {
    return InventoryFilterState(
      searchQuery: searchQuery ?? this.searchQuery,
      filter: filter ?? this.filter,
      sort: sort ?? this.sort,
    );
  }
}

class InventoryFilterNotifier extends Notifier<InventoryFilterState> {
  @override
  InventoryFilterState build() => const InventoryFilterState();

  void update(InventoryFilterState newState) {
    state = newState;
  }
}

final inventoryFilterProvider =
    NotifierProvider<InventoryFilterNotifier, InventoryFilterState>(() {
      return InventoryFilterNotifier();
    });

class MedicineListNotifier extends AsyncNotifier<List<Medicine>> {
  @override
  Future<List<Medicine>> build() async {
    final repo = ref.watch(medicineRepositoryProvider);
    return await repo.getMedicines();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      final repo = ref.read(medicineRepositoryProvider);
      final list = await repo.getMedicines();
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addMedicine(Medicine med) async {
    final repo = ref.read(medicineRepositoryProvider);
    await repo.addMedicine(med);
    await refresh();
  }

  Future<void> updateMedicine(Medicine med) async {
    final repo = ref.read(medicineRepositoryProvider);
    await repo.updateMedicine(med);
    await refresh();
  }

  Future<void> deleteMedicine(String id) async {
    final repo = ref.read(medicineRepositoryProvider);
    await repo.deleteMedicine(id);
    await refresh();
  }
}

final medicineListProvider =
    AsyncNotifierProvider<MedicineListNotifier, List<Medicine>>(() {
      return MedicineListNotifier();
    });

// Filtered and sorted medicine list provider
final filteredMedicinesProvider = Provider<List<Medicine>>((ref) {
  final medicinesAsync = ref.watch(medicineListProvider);
  final filterState = ref.watch(inventoryFilterProvider);

  return medicinesAsync.when(
    data: (medicines) {
      var list = medicines.where((med) {
        // Query match
        final q = filterState.searchQuery.toLowerCase().trim();
        final matchesQuery =
            q.isEmpty ||
            med.name.toLowerCase().contains(q) ||
            (med.brand?.toLowerCase().contains(q) ?? false) ||
            (med.rfidUid?.toLowerCase().contains(q) ?? false) ||
            (med.batchNumber?.toLowerCase().contains(q) ?? false);

        if (!matchesQuery) return false;

        // Compartment / Expiry filter match
        switch (filterState.filter) {
          case InventoryFilter.all:
            return true;
          case InventoryFilter.normal:
            return med.compartment == CompartmentType.normal;
          case InventoryFilter.cold:
            return med.compartment == CompartmentType.cold;
          case InventoryFilter.nearingExpiry:
            return med.isNearingExpiry(30);
          case InventoryFilter.expired:
            return med.isExpired;
        }
      }).toList();

      // Sort
      switch (filterState.sort) {
        case InventorySort.name:
          list.sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
          break;
        case InventorySort.expiry:
          list.sort((a, b) => a.expiryDate.compareTo(b.expiryDate));
          break;
        case InventorySort.quantity:
          list.sort((a, b) => b.quantity.compareTo(a.quantity));
          break;
        case InventorySort.recentlyAdded:
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          break;
      }

      return list;
    },
    loading: () => [],
    error: (_, _) => [],
  );
});

// 9. Alerts Notifiers
class AlertsNotifier extends AsyncNotifier<List<AlertItem>> {
  @override
  Future<List<AlertItem>> build() async {
    final repo = ref.watch(alertRepositoryProvider);
    return await repo.getAlerts();
  }

  Future<void> refresh() async {
    final repo = ref.read(alertRepositoryProvider);
    final alerts = await repo.getAlerts();
    state = AsyncValue.data(alerts);
  }

  Future<void> acknowledge(String id) async {
    final repo = ref.read(alertRepositoryProvider);
    await repo.acknowledgeAlert(id);
    await refresh();
  }

  Future<void> resolve(String id) async {
    final repo = ref.read(alertRepositoryProvider);
    await repo.resolveAlert(id);
    await refresh();
  }

  Future<void> createAlertIfNew(AlertItem alert) async {
    final repo = ref.read(alertRepositoryProvider);
    await repo.createAlertIfNew(alert);
    await refresh();
  }
}

final alertsProvider = AsyncNotifierProvider<AlertsNotifier, List<AlertItem>>(
  () {
    return AlertsNotifier();
  },
);

final activeAlertsProvider = Provider<List<AlertItem>>((ref) {
  final allAlerts = ref.watch(alertsProvider).value ?? [];
  return allAlerts.where((a) => a.isActive).toList();
});

// 10. Transactions Provider
class TransactionsNotifier extends AsyncNotifier<List<InventoryTransaction>> {
  @override
  Future<List<InventoryTransaction>> build() async {
    final repo = ref.watch(transactionRepositoryProvider);
    return await repo.getTransactions();
  }

  Future<void> refresh() async {
    final repo = ref.read(transactionRepositoryProvider);
    final txs = await repo.getTransactions();
    state = AsyncValue.data(txs);
  }

  Future<InventoryTransaction> startPending(InventoryTransaction tx) async {
    final repo = ref.read(transactionRepositoryProvider);
    final created = await repo.createPendingTransaction(tx);
    await refresh();
    await ref.read(medicineListProvider.notifier).refresh();
    return created;
  }

  Future<bool> confirm(String id, bool confirm, {String? notes}) async {
    final repo = ref.read(transactionRepositoryProvider);
    final ok = await repo.confirmTransaction(
      transactionId: id,
      confirm: confirm,
      notes: notes,
    );
    await refresh();
    await ref.read(medicineListProvider.notifier).refresh();
    return ok;
  }
}

final transactionsProvider =
    AsyncNotifierProvider<TransactionsNotifier, List<InventoryTransaction>>(() {
      return TransactionsNotifier();
    });
