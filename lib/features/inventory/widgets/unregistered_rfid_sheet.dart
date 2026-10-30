import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/unregistered_medicine.dart';
import '../../../shared/providers/app_providers.dart';

class UnregisteredRfidSheet extends ConsumerWidget {
  const UnregisteredRfidSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const UnregisteredRfidSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unregisteredAsync = ref.watch(unregisteredMedicinesProvider);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.82,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.nfc_rounded,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Unregistered RFID Tags',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      unregisteredAsync.when(
                        data: (list) => Text(
                          list.isEmpty
                              ? 'No pending tags waiting for enrollment'
                              : '${list.length} tag${list.length > 1 ? 's' : ''} waiting to be registered',
                          style: TextStyle(
                            fontSize: 12,
                            color: list.isEmpty
                                ? AppColors.textMuted
                                : const Color(0xFFD97706),
                            fontWeight: list.isEmpty
                                ? FontWeight.normal
                                : FontWeight.w600,
                          ),
                        ),
                        loading: () => const Text(
                          'Checking database...',
                          style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                        ),
                        error: (_, _) => const Text(
                          'Error loading tags',
                          style: TextStyle(fontSize: 12, color: AppColors.statusCritical),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  tooltip: 'Refresh',
                  onPressed: () {
                    ref.read(unregisteredMedicinesProvider.notifier).refresh();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Body
          Expanded(
            child: unregisteredAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Failed to load unregistered tags:\n$err',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.statusCritical),
                  ),
                ),
              ),
              data: (list) {
                if (list.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.contactless_outlined,
                            size: 56,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No Unregistered Tags Found',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'When an unrecognized RFID tag is scanned by your MediGuard unit, it will automatically populate here so you can enroll it with one tap.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = list[index];
                    return _UnregisteredCard(item: item);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _UnregisteredCard extends ConsumerWidget {
  final UnregisteredMedicine item;

  const _UnregisteredCard({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCold = item.compartment.toLowerCase() == 'cold';
    final isNormal = item.compartment.toLowerCase() == 'normal';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFDE68A)),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tag & Time Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.new_releases_outlined,
                      size: 14,
                      color: Color(0xFFD97706),
                    ),
                    SizedBox(width: 4),
                    Text(
                      'NEW RFID TAG',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFD97706),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                Formatters.timeAgo(item.lastScannedAt),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Monospaced RFID UID
          Row(
            children: [
              const Icon(
                Icons.nfc_rounded,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SelectableText(
                  item.rfidUid,
                  style: const TextStyle(
                    fontSize: 15,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Compartment and Detection metadata
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              if (isCold || isNormal)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isCold
                        ? const Color(0xFFE0F2FE)
                        : const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isCold ? '❄️ Cold Zone Detected' : '🌿 Normal Zone Detected',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isCold
                          ? const Color(0xFF0369A1)
                          : const Color(0xFF15803D),
                    ),
                  ),
                ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Scanned ${item.scanCount} time${item.scanCount > 1 ? 's' : ''}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.delete_outline, size: 16),
                label: const Text('Ignore Tag'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey.shade600,
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Dismiss Unregistered Tag?'),
                      content: Text(
                        'Do you want to remove RFID tag "${item.rfidUid}" from the pending queue?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text(
                            'Dismiss',
                            style: TextStyle(color: AppColors.statusCritical),
                          ),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await ref
                        .read(unregisteredMedicinesProvider.notifier)
                        .consume(
                          rfidUid: item.rfidUid,
                          unregisteredId: item.id,
                        );
                  }
                },
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                icon: const Icon(Icons.app_registration, size: 16),
                label: const Text('Register Medicine'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).pop(); // dismiss sheet
                  final compartmentParam =
                      isCold ? 'cold' : (isNormal ? 'normal' : '');
                  context.push(
                    '/inventory/add?rfid=${Uri.encodeComponent(item.rfidUid)}&unregisteredId=${Uri.encodeComponent(item.id)}&compartment=$compartmentParam',
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

