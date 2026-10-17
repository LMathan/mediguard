import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/empty_state_view.dart';
import '../../data/models/alert_item.dart';
import '../../shared/providers/app_providers.dart';

class AlertsScreen extends ConsumerStatefulWidget {
  const AlertsScreen({super.key});

  @override
  ConsumerState<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends ConsumerState<AlertsScreen> {
  AlertStatus _selectedTab = AlertStatus.active;

  @override
  Widget build(BuildContext context) {
    final alertsAsync = ref.watch(alertsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('System Alerts')),
      body: Column(
        children: [
          // Filter Tabs
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildTab(AlertStatus.active, 'Active'),
                const SizedBox(width: 8),
                _buildTab(AlertStatus.acknowledged, 'Acknowledged'),
                const SizedBox(width: 8),
                _buildTab(AlertStatus.resolved, 'Resolved'),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: alertsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (allAlerts) {
                final filtered = allAlerts
                    .where((a) => a.status == _selectedTab)
                    .toList();

                if (filtered.isEmpty) {
                  return EmptyStateView(
                    icon: Icons.notifications_off_outlined,
                    title: _selectedTab == AlertStatus.active
                        ? 'No Active Alerts'
                        : 'No ${_selectedTab.label} Alerts',
                    message: _selectedTab == AlertStatus.active
                        ? 'All environmental readings and medicine expiry statuses are within configured limits.'
                        : 'Any alerts transitioning to ${_selectedTab.label} will be archived here.',
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    await ref.read(alertsProvider.notifier).refresh();
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final alert = filtered[index];
                      return _AlertItemCard(alert: alert);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(AlertStatus status, String label) {
    final isSelected = _selectedTab == status;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedTab = status;
          });
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primaryContainer
                : AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _AlertItemCard extends ConsumerWidget {
  final AlertItem alert;

  const _AlertItemCard({required this.alert});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Color severityBg;
    Color severityColor;

    switch (alert.severity) {
      case AlertSeverity.critical:
        severityBg = AppColors.statusCriticalBg;
        severityColor = AppColors.statusCritical;
        break;
      case AlertSeverity.warning:
        severityBg = AppColors.statusWarningBg;
        severityColor = AppColors.statusWarning;
        break;
      case AlertSeverity.info:
        severityBg = AppColors.statusInfoBg;
        severityColor = AppColors.statusInfo;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: alert.isActive
              ? severityColor.withValues(alpha: 0.4)
              : AppColors.border,
          width: alert.isActive ? 1.2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row with Severity Pill and Time
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: severityBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  alert.severity.label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: severityColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  alert.dataSource.label,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                Formatters.timeAgo(alert.createdAt),
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Title & Message
          Text(
            alert.title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            alert.message,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),

          // Action Buttons: Acknowledge & Resolve
          if (alert.isActive) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    minimumSize: Size.zero,
                  ),
                  onPressed: () {
                    ref.read(alertsProvider.notifier).acknowledge(alert.id);
                  },
                  child: const Text(
                    'Acknowledge',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    minimumSize: Size.zero,
                  ),
                  onPressed: () {
                    ref.read(alertsProvider.notifier).resolve(alert.id);
                  },
                  child: const Text(
                    'Mark Resolved',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ] else if (alert.status == AlertStatus.acknowledged) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    minimumSize: Size.zero,
                  ),
                  onPressed: () {
                    ref.read(alertsProvider.notifier).resolve(alert.id);
                  },
                  child: const Text(
                    'Mark Resolved',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
