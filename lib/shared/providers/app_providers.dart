import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/alert_item.dart';
import '../../data/models/device_info.dart';
import '../../data/models/device_settings.dart';
import '../../data/models/inventory_transaction.dart';
import '../../data/models/medicine.dart';
import '../../data/models/sensor_reading.dart';
import '../../data/models/unregistered_medicine.dart';
import '../../data/repositories/alert_repository.dart';
import '../../data/repositories/medicine_repository.dart';
import '../../data/repositories/sensor_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../data/services/demo_sensor_service.dart';
import '../../data/services/hardware_sensor_service.dart';
import '../../data/services/notification_service.dart';
import '../../data/services/onesignal_service.dart';
import '../../data/services/sensor_data_source.dart';
import '../../data/services/supabase_service.dart';

// 1. Core Services Providers
final supabaseServiceProvider = Provider<SupabaseService>((ref) {
  return SupabaseService();
});

final authStateStreamProvider = StreamProvider<AuthState?>((ref) {
  final supabase = ref.watch(supabaseServiceProvider);
  return supabase.authStateChanges ?? const Stream.empty();
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

final oneSignalServiceProvider = Provider<OneSignalService>((ref) {
  return OneSignalService();
});

// 1b. Device Selection & Management Providers
final devicesListProvider = FutureProvider<List<DeviceInfo>>((ref) async {
  final repo = ref.watch(settingsRepositoryProvider);
  return await repo.getDevices();
});

class SelectedDeviceNotifier extends Notifier<String> {
  String? _userChosenDeviceId;

  @override
  String build() {
    final devicesAsync = ref.watch(devicesListProvider);
    final devices = devicesAsync.value ?? [];
    if (_userChosenDeviceId != null &&
        devices.any((d) => d.id == _userChosenDeviceId)) {
      return _userChosenDeviceId!;
    }
    if (devices.isNotEmpty) {
      return devices.first.id;
    }
    return 'c0b54f87-1f7b-45a7-8554-de66122a0fbe';
  }

  void selectDevice(String deviceId) {
    _userChosenDeviceId = deviceId;
    state = deviceId;
  }
}

final selectedDeviceIdProvider =
    NotifierProvider<SelectedDeviceNotifier, String>(() {
      return SelectedDeviceNotifier();
    });

final selectedDeviceInfoProvider = Provider<DeviceInfo?>((ref) {
  final selectedId = ref.watch(selectedDeviceIdProvider);
  final devices = ref.watch(devicesListProvider).value ?? [];
  return devices.where((d) => d.id == selectedId).firstOrNull;
});

final hardwareSensorServiceProvider = Provider<HardwareSensorService>((ref) {
  final supabase = ref.watch(supabaseServiceProvider);
  final selectedDeviceId = ref.watch(selectedDeviceIdProvider);
  final service = HardwareSensorService(
    supabase: supabase.client,
    deviceId: selectedDeviceId,
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
    // Re-fetch when auth state or selected device changes
    ref.watch(authStateStreamProvider);
    final selectedDeviceId = ref.watch(selectedDeviceIdProvider);
    final repo = ref.watch(settingsRepositoryProvider);
    final dev = await repo.getDeviceById(selectedDeviceId);
    return dev ?? await repo.getDeviceInfo(deviceId: selectedDeviceId);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      final selectedDeviceId = ref.read(selectedDeviceIdProvider);
      final repo = ref.read(settingsRepositoryProvider);
      final dev = await repo.getDeviceById(selectedDeviceId);
      final info = dev ?? await repo.getDeviceInfo(deviceId: selectedDeviceId);
      state = AsyncValue.data(info);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
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
      final selectedDeviceId = ref.watch(selectedDeviceIdProvider);
      return await repo.getHistory(window: window, deviceId: selectedDeviceId);
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
    final selectedDeviceId = ref.watch(selectedDeviceIdProvider);
    final repo = ref.watch(medicineRepositoryProvider);
    return await repo.getMedicines(deviceId: selectedDeviceId);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      final selectedDeviceId = ref.read(selectedDeviceIdProvider);
      final repo = ref.read(medicineRepositoryProvider);
      final list = await repo.getMedicines(deviceId: selectedDeviceId);
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addMedicine(Medicine med) async {
    final selectedDeviceId = ref.read(selectedDeviceIdProvider);
    final repo = ref.read(medicineRepositoryProvider);
    final medWithDevice = med.deviceId == null
        ? med.copyWith(deviceId: selectedDeviceId)
        : med;
    await repo.addMedicine(medWithDevice, deviceId: selectedDeviceId);
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

// 8b. Unregistered Medicines Notifier & Provider
class UnregisteredMedicinesNotifier
    extends AsyncNotifier<List<UnregisteredMedicine>> {
  RealtimeChannel? _realtimeChannel;

  @override
  Future<List<UnregisteredMedicine>> build() async {
    final repo = ref.watch(medicineRepositoryProvider);
    final supabase = ref.watch(supabaseServiceProvider);

    if (supabase.client != null) {
      _realtimeChannel?.unsubscribe();
      _realtimeChannel = supabase.client!
          .channel('public:unregistered_medicines')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'unregistered_medicines',
            callback: (_) {
              refresh();
            },
          )
          .subscribe();

      ref.onDispose(() {
        if (_realtimeChannel != null && supabase.client != null) {
          supabase.client!.removeChannel(_realtimeChannel!);
        }
      });
    }

    return await repo.getUnregisteredMedicines();
  }

  Future<void> refresh() async {
    final repo = ref.read(medicineRepositoryProvider);
    final list = await repo.getUnregisteredMedicines();
    state = AsyncValue.data(list);
  }

  Future<void> consume({
    required String rfidUid,
    String? unregisteredId,
  }) async {
    final repo = ref.read(medicineRepositoryProvider);
    await repo.consumeUnregisteredMedicine(
      rfidUid: rfidUid,
      unregisteredId: unregisteredId,
    );
    await refresh();
  }
}

final unregisteredMedicinesProvider = AsyncNotifierProvider<
  UnregisteredMedicinesNotifier,
  List<UnregisteredMedicine>
>(() {
  return UnregisteredMedicinesNotifier();
});

final unregisteredMedicinesCountProvider = Provider<int>((ref) {
  final list = ref.watch(unregisteredMedicinesProvider).value ?? [];
  return list.length;
});

// 9. Alerts Notifiers
class AlertsNotifier extends AsyncNotifier<List<AlertItem>> {
  RealtimeChannel? _alertsChannel;

  @override
  Future<List<AlertItem>> build() async {
    final selectedDeviceId = ref.watch(selectedDeviceIdProvider);
    final repo = ref.watch(alertRepositoryProvider);
    final supabase = ref.watch(supabaseServiceProvider);

    if (supabase.client != null) {
      _alertsChannel?.unsubscribe();
      _alertsChannel = supabase.client!
          .channel('public:alerts:$selectedDeviceId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'alerts',
            callback: (_) {
              refresh();
            },
          )
          .subscribe();

      ref.onDispose(() {
        if (_alertsChannel != null && supabase.client != null) {
          supabase.client!.removeChannel(_alertsChannel!);
        }
      });
    }

    // Automatically resolve alerts when nominal telemetry arrives
    ref.listen(sensorReadingStreamProvider, (_, next) {
      final reading = next.value;
      if (reading != null) {
        autoResolveNominal(reading);
      }
    });

    final alerts = await repo.getAlerts(deviceId: selectedDeviceId);
    // Do not trigger local push notifications on app launch / refresh.
    // When the app is open, the user views active alerts directly on screen.
    return alerts;
  }

  Future<void> autoResolveNominal(SensorReading reading) async {
    final repo = ref.read(alertRepositoryProvider);
    bool changed = false;

    // If reading is fresh (under 60s), auto-resolve device offline alerts!
    if (!reading.isStale()) {
      await repo.resolveAlertsOfType(AlertType.deviceOffline);
      await NotificationService().cancelAlert(AlertType.deviceOffline.name);
      changed = true;
    }

    // If cold temp is nominal (2-8°C), auto-resolve temperature alerts!
    if (reading.coldTemperatureC >= 2.0 && reading.coldTemperatureC <= 8.0) {
      await repo.resolveAlertsOfType(AlertType.highTemp);
      await repo.resolveAlertsOfType(AlertType.lowTemp);
      await NotificationService().cancelAlert(AlertType.highTemp.name);
      await NotificationService().cancelAlert(AlertType.lowTemp.name);
      changed = true;
    }

    // If door is closed, auto-resolve door alerts!
    if (!reading.coldDoorOpen) {
      await repo.resolveAlertsOfType(AlertType.doorLeftOpen);
      await NotificationService().cancelAlert(AlertType.doorLeftOpen.name);
      changed = true;
    }

    // If sensor is healthy, auto-resolve sensor error alerts!
    if (reading.sensorHealth == SensorHealth.healthy) {
      await repo.resolveAlertsOfType(AlertType.sensorError);
      await NotificationService().cancelAlert(AlertType.sensorError.name);
      changed = true;
    }

    if (changed) {
      await refresh();
    }
  }

  Future<void> refresh() async {
    final selectedDeviceId = ref.read(selectedDeviceIdProvider);
    final repo = ref.read(alertRepositoryProvider);
    final alerts = await repo.getAlerts(deviceId: selectedDeviceId);
    state = AsyncValue.data(alerts);
  }

  Future<void> acknowledge(String id) async {
    final repo = ref.read(alertRepositoryProvider);
    await repo.acknowledgeAlert(id);
    await refresh();
  }

  Future<void> resolve(String id) async {
    final repo = ref.read(alertRepositoryProvider);
    final currentList = state.value ?? [];
    final matchingAlerts = currentList.where((a) => a.id == id).toList();
    await repo.resolveAlert(id);
    if (matchingAlerts.isNotEmpty) {
      await NotificationService().cancelAlert(matchingAlerts.first.type.name);
    }
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
