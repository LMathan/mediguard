import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/empty_state_view.dart';
import '../../data/models/alert_item.dart';
import '../../data/models/inventory_transaction.dart';
import '../../shared/providers/app_providers.dart';

enum HistoryFilter { all, inventory, alerts, door }

class ActivityEvent {
  final String title;
  final String description;
  final DateTime timestamp;
  final IconData icon;
  final Color color;
  final String category;

  const ActivityEvent({
    required this.title,
    required this.description,
    required this.timestamp,
    required this.icon,
    required this.color,
    required this.category,
  });
}

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  HistoryFilter _currentFilter = HistoryFilter.all;

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(transactionsProvider);
    final alertsAsync = ref.watch(alertsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Activity Audit Log')),
      body: Column(
        children: [
          // Filter Chips Row
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip(HistoryFilter.all, 'All Events'),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    HistoryFilter.inventory,
                    '📦 Medicine Stocking',
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(HistoryFilter.alerts, '⚠️ Alert Events'),
                  const SizedBox(width: 8),
                  _buildFilterChip(HistoryFilter.door, '🚪 Door Access Cycles'),
                ],
              ),
            ),
          ),
          const Divider(height: 1),

          // Unified History List
          Expanded(
            child: Builder(
              builder: (context) {
                final txs = transactionsAsync.value ?? [];
                final alerts = alertsAsync.value ?? [];

                final events = <ActivityEvent>[];

                // Map Transactions to events
                for (final tx in txs) {
                  events.add(
                    ActivityEvent(
                      title: tx.action == TransactionAction.add
                          ? 'Stock Inbound: ${tx.medicineName ?? 'Medicine'}'
                          : tx.action == TransactionAction.remove
                          ? 'Stock Dispensed: ${tx.medicineName ?? 'Medicine'}'
                          : 'Stock Adjustment: ${tx.medicineName ?? 'Medicine'}',
                      description:
                          '${tx.action.name == 'add' ? '+' : '-'}${tx.quantityChange.abs()} units into ${tx.compartment.label}. Method: ${tx.initiationMethod.toUpperCase()} (Audit: ${tx.status.label}).',
                      timestamp: tx.confirmedAt ?? tx.initiatedAt,
                      icon: tx.action == TransactionAction.add
                          ? Icons.add_box
                          : Icons.indeterminate_check_box,
                      color: tx.action == TransactionAction.add
                          ? AppColors.statusNormal
                          : AppColors.statusWarning,
                      category: 'inventory',
                    ),
                  );
                }

                // Map Alerts to events
                for (final a in alerts) {
                  final isDoor = a.type == AlertType.doorLeftOpen;
                  events.add(
                    ActivityEvent(
                      title: a.title,
                      description: '${a.message} Status: ${a.status.label}.',
                      timestamp: a.createdAt,
                      icon: isDoor
                          ? Icons.door_sliding_outlined
                          : Icons.warning_rounded,
                      color: isDoor
                          ? AppColors.statusWarning
                          : AppColors.statusCritical,
                      category: isDoor ? 'door' : 'alerts',
                    ),
                  );
                }

                // Sort descending by timestamp
                events.sort((a, b) => b.timestamp.compareTo(a.timestamp));

                // Filter by selected tab
                final filtered = events.where((e) {
                  switch (_currentFilter) {
                    case HistoryFilter.all:
                      return true;
                    case HistoryFilter.inventory:
                      return e.category == 'inventory';
                    case HistoryFilter.alerts:
                      return e.category == 'alerts';
                    case HistoryFilter.door:
                      return e.category == 'door';
                  }
                }).toList();

                if (filtered.isEmpty) {
                  return const EmptyStateView(
                    icon: Icons.history_toggle_off_rounded,
                    title: 'No Activity Found',
                    message:
                        'Activity logs will populate as medicine inventory, door cycles, and telemetry alerts occur.',
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: item.color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(item.icon, size: 20, color: item.color),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item.title,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      Formatters.timeAgo(item.timestamp),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item.description,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                    height: 1.3,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  Formatters.dateTime(item.timestamp),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(HistoryFilter filter, String label) {
    final isSelected = _currentFilter == filter;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        setState(() {
          _currentFilter = filter;
        });
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
