import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/empty_state_view.dart';
import '../../data/models/medicine.dart';
import '../../shared/providers/app_providers.dart';
import 'widgets/unregistered_rfid_sheet.dart';

class InventoryScreen extends ConsumerWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filteredMedicines = ref.watch(filteredMedicinesProvider);
    final filterState = ref.watch(inventoryFilterProvider);
    final medicinesAsync = ref.watch(medicineListProvider);
    final unregisteredCount = ref.watch(unregisteredMedicinesCountProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Search & Filter Header Container
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                // Unregistered RFIDs Alert Banner (if pending)
                if (unregisteredCount > 0)
                  InkWell(
                    onTap: () => UnregisteredRfidSheet.show(context),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        border: Border.all(color: const Color(0xFFF59E0B)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Color(0xFFF59E0B),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.nfc_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$unregisteredCount Unregistered RFID Tag${unregisteredCount > 1 ? 's' : ''} Detected',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF92400E),
                                  ),
                                ),
                                const Text(
                                  'Tap to select and register into inventory',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFFB45309),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD97706),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Enroll',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(width: 4),
                                Icon(
                                  Icons.arrow_forward_ios,
                                  size: 10,
                                  color: Colors.white,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Search Input Field & Unregistered RFID Button
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        onChanged: (val) {
                          ref
                              .read(inventoryFilterProvider.notifier)
                              .update(filterState.copyWith(searchQuery: val));
                        },
                        decoration: InputDecoration(
                          hintText:
                              'Search by name, brand, or RFID UID...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          suffixIcon: filterState.searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    ref
                                        .read(inventoryFilterProvider.notifier)
                                        .update(
                                          filterState.copyWith(searchQuery: ''),
                                        );
                                  },
                                )
                              : null,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Quick button to view and enroll unregistered RFIDs
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        IconButton.filledTonal(
                          icon: const Icon(Icons.nfc_rounded, size: 20),
                          tooltip: 'Unregistered RFID Tags',
                          onPressed: () => UnregisteredRfidSheet.show(context),
                          style: IconButton.styleFrom(
                            backgroundColor: unregisteredCount > 0
                                ? const Color(0xFFFEF3C7)
                                : AppColors.surface,
                            foregroundColor: unregisteredCount > 0
                                ? const Color(0xFFD97706)
                                : AppColors.primary,
                          ),
                        ),
                        if (unregisteredCount > 0)
                          Positioned(
                            right: -2,
                            top: -2,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Color(0xFFDC2626),
                                shape: BoxShape.circle,
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 16,
                                minHeight: 16,
                              ),
                              child: Text(
                                '$unregisteredCount',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Filter & Sort Row
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip(
                        ref: ref,
                        current: filterState.filter,
                        target: InventoryFilter.all,
                        label: 'All Items',
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        ref: ref,
                        current: filterState.filter,
                        target: InventoryFilter.cold,
                        label: '❄️ Cold Storage',
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        ref: ref,
                        current: filterState.filter,
                        target: InventoryFilter.normal,
                        label: '🌿 Normal Storage',
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        ref: ref,
                        current: filterState.filter,
                        target: InventoryFilter.nearingExpiry,
                        label: '⏳ Nearing Expiry',
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        ref: ref,
                        current: filterState.filter,
                        target: InventoryFilter.expired,
                        label: '⚠️ Expired',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Inventory List / Empty State
          Expanded(
            child: medicinesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  Center(child: Text('Error loading inventory: $e')),
              data: (_) {
                if (filteredMedicines.isEmpty) {
                  return EmptyStateView(
                    icon: Icons.inventory_2_outlined,
                    title: filterState.searchQuery.isNotEmpty
                        ? 'No Medicines Match Search'
                        : 'No Medicines in this Category',
                    message: filterState.searchQuery.isNotEmpty
                        ? 'Check spelling or try searching by RFID UID.'
                        : 'Register your first medicine to begin tracking stock and temperature limits.',
                    actionLabel: 'Register Medicine',
                    onAction: () => context.push('/inventory/add'),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    await ref.read(medicineListProvider.notifier).refresh();
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    itemCount: filteredMedicines.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final med = filteredMedicines[index];
                      return _MedicineCard(medicine: med);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Medicine'),
        onPressed: () => context.push('/inventory/add'),
      ),
    );
  }

  Widget _buildFilterChip({
    required WidgetRef ref,
    required InventoryFilter current,
    required InventoryFilter target,
    required String label,
  }) {
    final isSelected = current == target;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        final currentFilter = ref.read(inventoryFilterProvider);
        ref
            .read(inventoryFilterProvider.notifier)
            .update(currentFilter.copyWith(filter: target));
      },
      selectedColor: AppColors.primaryContainer,
      backgroundColor: Colors.white,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        color: isSelected ? AppColors.primary : AppColors.textSecondary,
      ),
      side: BorderSide(
        color: isSelected ? AppColors.primary : AppColors.border,
      ),
    );
  }
}

class _MedicineCard extends StatelessWidget {
  final Medicine medicine;

  const _MedicineCard({required this.medicine});

  @override
  Widget build(BuildContext context) {
    final isCold = medicine.compartment == CompartmentType.cold;
    final isExpired = medicine.isExpired;
    final isNearExpiry = medicine.isNearingExpiry(30);

    return InkWell(
      onTap: () {
        context.push('/inventory/detail/${medicine.id}');
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isExpired
                ? AppColors.statusCritical
                : isNearExpiry
                ? AppColors.statusWarning
                : AppColors.border,
            width: isExpired || isNearExpiry ? 1.4 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Compartment Tag & Stock Count
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isCold
                        ? AppColors.coldCompartmentBg
                        : AppColors.normalCompartmentBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isCold ? Icons.ac_unit : Icons.home_outlined,
                        size: 13,
                        color: isCold
                            ? AppColors.coldCompartment
                            : AppColors.normalCompartment,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isCold ? 'COLD ZONE (2-8°C)' : 'NORMAL ZONE (15-25°C)',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: isCold
                              ? AppColors.coldCompartment
                              : AppColors.normalCompartment,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${medicine.quantity} in stock',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Medicine Name & Brand/Strength
            Text(
              medicine.name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            if (medicine.brand != null || medicine.strength != null) ...[
              const SizedBox(height: 2),
              Text(
                [
                  medicine.brand,
                  medicine.strength,
                  medicine.dosageForm,
                ].where((s) => s != null && s.isNotEmpty).join(' • '),
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),

            // Expiry & RFID Row
            Row(
              children: [
                Icon(
                  Icons.event_outlined,
                  size: 14,
                  color: isExpired
                      ? AppColors.statusCritical
                      : isNearExpiry
                      ? AppColors.statusWarning
                      : AppColors.textMuted,
                ),
                const SizedBox(width: 4),
                Text(
                  Formatters.daysUntil(medicine.expiryDate),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isExpired || isNearExpiry
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: isExpired
                        ? AppColors.statusCritical
                        : isNearExpiry
                        ? AppColors.statusWarning
                        : AppColors.textSecondary,
                  ),
                ),
                const Spacer(),
                if (medicine.rfidUid != null) ...[
                  const Icon(
                    Icons.nfc_rounded,
                    size: 14,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    medicine.rfidUid!,
                    style: const TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
