import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/inventory_transaction.dart';
import '../../data/models/medicine.dart';
import '../../shared/providers/app_providers.dart';

class MedicineDetailScreen extends ConsumerWidget {
  final String medicineId;

  const MedicineDetailScreen({super.key, required this.medicineId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final medicinesAsync = ref.watch(medicineListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Medicine Specification'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Medicine',
            onPressed: () {
              context.push('/inventory/edit/$medicineId');
            },
          ),
        ],
      ),
      body: medicinesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (medicines) {
          final medicine = medicines
              .where((m) => m.id == medicineId)
              .firstOrNull;
          if (medicine == null) {
            return const Center(child: Text('Medicine not found.'));
          }

          final isCold = medicine.compartment == CompartmentType.cold;
          final isExpired = medicine.isExpired;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Card with Title, Brand & Quantity
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: isCold
                                  ? AppColors.coldCompartmentBg
                                  : AppColors.normalCompartmentBg,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              medicine.compartment.label.toUpperCase(),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: isCold
                                    ? AppColors.coldCompartment
                                    : AppColors.normalCompartment,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.mintSurface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.mintAccent),
                            ),
                            child: Text(
                              '${medicine.quantity} UNITS AVAILABLE',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        medicine.name,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (medicine.brand != null ||
                          medicine.strength != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          [
                            medicine.brand,
                            medicine.strength,
                            medicine.dosageForm,
                          ].where((s) => s != null && s.isNotEmpty).join(' • '),
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Inbound & Outbound Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () {
                          // Start Inbound Add Transaction
                          _startTransaction(
                            context: context,
                            ref: ref,
                            medicine: medicine,
                            action: TransactionAction.add,
                          );
                        },
                        icon: const Icon(Icons.add_shopping_cart, size: 18),
                        label: const Text('Inbound Stock'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.statusCritical,
                          side: const BorderSide(
                            color: AppColors.statusCritical,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: medicine.quantity <= 0
                            ? null
                            : () {
                                // Start Outbound Remove Transaction
                                _startTransaction(
                                  context: context,
                                  ref: ref,
                                  medicine: medicine,
                                  action: TransactionAction.remove,
                                );
                              },
                        icon: const Icon(Icons.remove_shopping_cart, size: 18),
                        label: const Text('Dispense Stock'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Environmental Safety Specification Card
                const Text(
                  'Storage Requirements & Limits',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      _buildSpecRow(
                        label: 'Storage Classification',
                        value: medicine.requiredStorage.label,
                      ),
                      const Divider(height: 20),
                      _buildSpecRow(
                        label: 'Safe Temperature Limits',
                        value:
                            '${medicine.minTemperatureC?.toStringAsFixed(1) ?? '2.0'}°C to ${medicine.maxTemperatureC?.toStringAsFixed(1) ?? '8.0'}°C',
                      ),
                      const Divider(height: 20),
                      _buildSpecRow(
                        label: 'Safe Relative Humidity',
                        value:
                            '${medicine.minHumidityPct?.toStringAsFixed(0) ?? '30'}% to ${medicine.maxHumidityPct?.toStringAsFixed(0) ?? '70'}%',
                      ),
                      const Divider(height: 20),
                      _buildSpecRow(
                        label: 'Target Compartment',
                        value: medicine.compartment.label,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Product & Identification Details
                const Text(
                  'Identification & Batch Registry',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      _buildSpecRow(
                        label: 'RFID UID Tag',
                        value: medicine.rfidUid ?? 'No RFID tag attached',
                        isMonospace: medicine.rfidUid != null,
                      ),
                      const Divider(height: 20),
                      _buildSpecRow(
                        label: 'Batch / Lot Number',
                        value: medicine.batchNumber ?? 'Unassigned',
                      ),
                      const Divider(height: 20),
                      _buildSpecRow(
                        label: 'Expiration Date',
                        value:
                            '${Formatters.date(medicine.expiryDate)} (${Formatters.daysUntil(medicine.expiryDate)})',
                        valueColor: isExpired ? AppColors.statusCritical : null,
                      ),
                      const Divider(height: 20),
                      _buildSpecRow(
                        label: 'Inventory Status',
                        value: medicine.status.label,
                      ),
                      if (medicine.notes != null &&
                          medicine.notes!.isNotEmpty) ...[
                        const Divider(height: 20),
                        _buildSpecRow(
                          label: 'Clinical Notes',
                          value: medicine.notes!,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Delete Button
                Center(
                  child: TextButton.icon(
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Delete Medicine?'),
                          content: Text(
                            'Are you sure you want to remove "${medicine.name}" from inventory?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.statusCritical,
                              ),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );

                      if (confirmed == true && context.mounted) {
                        await ref
                            .read(medicineListProvider.notifier)
                            .deleteMedicine(medicine.id);
                        if (context.mounted) context.pop();
                      }
                    },
                    icon: const Icon(
                      Icons.delete_outline,
                      color: AppColors.statusCritical,
                      size: 18,
                    ),
                    label: const Text(
                      'Delete Medicine from Registry',
                      style: TextStyle(color: AppColors.statusCritical),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _startTransaction({
    required BuildContext context,
    required WidgetRef ref,
    required Medicine medicine,
    required TransactionAction action,
  }) {
    context.push(
      '/inventory/transaction/flow?medId=${medicine.id}&action=${action.name}',
    );
  }

  Widget _buildSpecRow({
    required String label,
    required String value,
    Color? valueColor,
    bool isMonospace = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              fontFamily: isMonospace ? 'monospace' : null,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
