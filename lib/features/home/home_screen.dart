import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/metric_card.dart';
import '../../data/models/sensor_reading.dart';
import '../../shared/providers/app_providers.dart';
import '../../shared/widgets/status_badge.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overallStatus = ref.watch(overallStatusProvider);
    final readingAsync = ref.watch(sensorReadingStreamProvider);
    final dataSource = ref.watch(sensorDataSourceProvider);
    final currentReading = readingAsync.value ?? dataSource.latestReading;
    final settings = ref.watch(deviceSettingsProvider).value;
    final activeAlerts = ref.watch(activeAlertsProvider);
    final recentTransactions = ref.watch(transactionsProvider).value ?? [];

    final isColdWithinRange = settings == null
        ? (currentReading.coldTemperatureC >= 2.0 &&
              currentReading.coldTemperatureC <= 8.0)
        : (currentReading.coldTemperatureC >= settings.coldTempMinC &&
              currentReading.coldTemperatureC <= settings.coldTempMaxC);

    final isNormalWithinRange = settings == null
        ? (currentReading.normalTemperatureC >= 15.0 &&
              currentReading.normalTemperatureC <= 25.0)
        : (currentReading.normalTemperatureC >= settings.normalTempMinC &&
              currentReading.normalTemperatureC <= settings.normalTempMaxC);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(devicesListProvider);
          await ref.read(hardwareSensorServiceProvider).fetchLatest();
          await ref.read(medicineListProvider.notifier).refresh();
          await ref.read(alertsProvider.notifier).refresh();
          await ref.read(transactionsProvider.notifier).refresh();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Storage Unit / Container Dropdown Selector
              _buildDeviceSelector(context, ref),
              const SizedBox(height: 14),

              // 2. System Health Summary Card
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF165B33), Color(0xFF0F3E22)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.25),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'SYSTEM STATUS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFA7D7B5),
                            letterSpacing: 1.2,
                          ),
                        ),
                        StatusBadge(status: overallStatus),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      overallStatus == OverallStatus.normal
                          ? 'All Storage Zones Optimal'
                          : overallStatus == OverallStatus.warning
                          ? 'Environmental Warning Detected'
                          : overallStatus == OverallStatus.critical
                          ? 'CRITICAL ALERT: Inspect Immediately'
                          : 'Device Status Unknown / Offline',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Divider(color: Colors.white24, height: 1),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(
                          Icons.sync_rounded,
                          size: 14,
                          color: Colors.white70,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            currentReading.recordedAt.millisecondsSinceEpoch == 0
                                ? 'Awaiting hardware data in DB'
                                : 'Updated: ${Formatters.timeAgo(currentReading.recordedAt)} (${Formatters.shortTime(currentReading.recordedAt)})',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white12,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            currentReading.dataSource.label.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Active Alert Banner if any
              if (activeAlerts.isNotEmpty) ...[
                InkWell(
                  onTap: () => context.push('/alerts'),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.statusCriticalBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.statusCritical.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: AppColors.statusCritical,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${activeAlerts.length} Active System Alert${activeAlerts.length > 1 ? 's' : ''}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.statusCritical,
                                ),
                              ),
                              Text(
                                activeAlerts.first.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right,
                          color: AppColors.statusCritical,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Compartment Telemetry Cards
              const Text(
                'Storage Compartments',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),

              // Cold Compartment Card
              CompartmentMetricCard(
                title: 'Cold Storage Compartment',
                targetRange:
                    '${settings?.coldTempMinC.toStringAsFixed(0) ?? 2}°C - ${settings?.coldTempMaxC.toStringAsFixed(0) ?? 8}°C',
                temperature: currentReading.coldTemperatureC,
                humidity: currentReading.coldHumidityPct,
                isDoorOpen: currentReading.coldDoorOpen,
                isCoolingActive: currentReading.coolingActive,
                isFanActive: currentReading.normalFanActive,
                isCold: true,
                isWithinRange: isColdWithinRange,
              ),
              const SizedBox(height: 14),

              // Normal Compartment Card
              CompartmentMetricCard(
                title: 'Normal Room Compartment',
                targetRange:
                    '${settings?.normalTempMinC.toStringAsFixed(0) ?? 15}°C - ${settings?.normalTempMaxC.toStringAsFixed(0) ?? 25}°C',
                temperature: currentReading.normalTemperatureC,
                humidity: currentReading.normalHumidityPct,
                isDoorOpen: currentReading.normalDoorOpen,
                isFanActive: currentReading.normalFanActive,
                isCold: false,
                isWithinRange: isNormalWithinRange,
              ),
              const SizedBox(height: 24),

              // Quick Actions Bar
              const Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildQuickActionButton(
                      icon: Icons.add_box_outlined,
                      label: 'Inbound Stock',
                      color: AppColors.primary,
                      onTap: () => context.push('/inventory/add'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildQuickActionButton(
                      icon: Icons.qr_code_scanner_rounded,
                      label: 'Scan RFID',
                      color: const Color(0xFF0284C7),
                      onTap: () => context.push('/inventory/transaction/scan'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildQuickActionButton(
                      icon: Icons.tune,
                      label: 'Sim Scenarios',
                      color: const Color(0xFFD97706),
                      onTap: () =>
                          context.push('/settings/simulation-controls'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Recent Activity Audit Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'Recent Inventory Activity',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.go('/history'),
                    child: const Text('View All'),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (recentTransactions.isEmpty)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Center(
                    child: Text(
                      'No recent inventory transactions recorded.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: recentTransactions.take(3).length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final tx = recentTransactions[index];
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: tx.action.name == 'add'
                                  ? AppColors.statusNormalBg
                                  : AppColors.statusWarningBg,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              tx.action.name == 'add'
                                  ? Icons.arrow_downward
                                  : Icons.arrow_upward,
                              size: 18,
                              color: tx.action.name == 'add'
                                  ? AppColors.statusNormal
                                  : AppColors.statusWarning,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tx.medicineName ?? 'Medicine Transaction',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  '${tx.action.label} • Compartment: ${tx.compartment.label}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${tx.action.name == 'add' ? '+' : '-'}${tx.quantityChange.abs()} units',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: tx.action.name == 'add'
                                      ? AppColors.statusNormal
                                      : AppColors.statusWarning,
                                ),
                              ),
                              Text(
                                Formatters.timeAgo(tx.initiatedAt),
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeviceSelector(BuildContext context, WidgetRef ref) {
    final devicesAsync = ref.watch(devicesListProvider);
    final selectedId = ref.watch(selectedDeviceIdProvider);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.view_in_ar_rounded,
                  size: 14,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'STORAGE UNIT / CONTAINER',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.9,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF16A34A),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Text(
                      'Live Linked',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF166534),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          devicesAsync.when(
            data: (devices) {
              if (devices.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    'No containers available',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                );
              }

              final currentSelection = devices.any((d) => d.id == selectedId)
                  ? selectedId
                  : devices.first.id;

              return DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: currentSelection,
                  icon: const Icon(
                    Icons.arrow_drop_down_circle_outlined,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  itemHeight: 52,
                  borderRadius: BorderRadius.circular(12),
                  items: devices.map((device) {
                    final isCurrent = device.id == currentSelection;
                    return DropdownMenuItem<String>(
                      value: device.id,
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: device.isOnline
                                  ? const Color(0xFF16A34A)
                                  : Colors.grey,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  device.deviceName,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: isCurrent
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                    color: isCurrent
                                        ? AppColors.primary
                                        : AppColors.textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (device.serialNumber != null)
                                  Text(
                                    device.serialNumber!,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (newId) {
                    if (newId != null && newId != selectedId) {
                      ref
                          .read(selectedDeviceIdProvider.notifier)
                          .selectDevice(newId);
                      ref.read(hardwareSensorServiceProvider).fetchLatest();
                    }
                  },
                ),
              );
            },
            loading: () => const SizedBox(
              height: 38,
              child: Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            error: (_, _) => const Text(
              'Failed to load devices',
              style: TextStyle(fontSize: 12, color: AppColors.statusCritical),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
