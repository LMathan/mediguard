import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/config/supabase_config.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/providers/app_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final supabase = ref.watch(supabaseServiceProvider);
    final deviceInfo = ref.watch(deviceInfoProvider).value;
    final settings = ref.watch(deviceSettingsProvider).value;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings & Configuration')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // User Profile Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: AppColors.primaryContainer,
                    child: const Icon(
                      Icons.person_rounded,
                      color: AppColors.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          supabase.currentUserName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          supabase.currentUserEmail,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.mintSurface,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.mintAccent),
                          ),
                          child: const Text(
                            'LICENSED CLINICIAN',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Backend Status Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Supabase Cloud Backend',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(
                        SupabaseConfig.isConfigured
                            ? Icons.cloud_done
                            : Icons.cloud_queue,
                        color: SupabaseConfig.isConfigured
                            ? AppColors.statusNormal
                            : AppColors.statusWarning,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          SupabaseConfig.isConfigured
                              ? 'Connected to Project: ${SupabaseConfig.projectRef}'
                              : 'Standalone Demo Mode (Configure SUPABASE_ANON_KEY to sync cloud)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: SupabaseConfig.isConfigured
                                ? AppColors.statusNormal
                                : AppColors.statusWarning,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Hardware Device Specification Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Device Identification',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildSettingRow(
                    'Device Name',
                    deviceInfo?.deviceName ?? 'MediGuard Box Alpha',
                  ),
                  const Divider(height: 18),
                  _buildSettingRow(
                    'Model Version',
                    deviceInfo?.modelVersion ?? 'ESP32-MediGuard-v1',
                  ),
                  const Divider(height: 18),
                  _buildSettingRow(
                    'Serial Number',
                    deviceInfo?.serialNumber ?? 'MG-2026-ESP32-001',
                  ),
                  const Divider(height: 18),
                  _buildSettingRow(
                    'Data Source',
                    ref.watch(sensorDataSourceProvider).isSimulated
                        ? 'Simulated Telemetry'
                        : 'Physical ESP32',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Navigation Sections
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(
                      Icons.thermostat_outlined,
                      color: AppColors.primary,
                    ),
                    title: const Text(
                      'Environmental Thresholds',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text(
                      'Cold, normal and humidity safety boundaries',
                      style: TextStyle(fontSize: 12),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/settings/thresholds'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.tune, color: Color(0xFFD97706)),
                    title: const Text(
                      'Simulation Control Panel',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text(
                      'Trigger test scenarios (warning, door open, fault)',
                      style: TextStyle(fontSize: 12),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/settings/simulation-controls'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Notification Toggles
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Critical Alerts Notification',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: const Text(
                      'Dispatch notification on out-of-range temperatures',
                      style: TextStyle(fontSize: 12),
                    ),
                    value: settings?.notificationsEnabled ?? true,
                    activeThumbColor: AppColors.primary,
                    onChanged: (val) {
                      if (settings != null) {
                        ref
                            .read(deviceSettingsProvider.notifier)
                            .updateSettings(
                              settings.copyWith(notificationsEnabled: val),
                            );
                      }
                    },
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Vibration on Alert',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: const Text(
                      'Vibrate phone on critical alarms',
                      style: TextStyle(fontSize: 12),
                    ),
                    value: settings?.criticalAlertVibrate ?? true,
                    activeThumbColor: AppColors.primary,
                    onChanged: (val) {
                      if (settings != null) {
                        ref
                            .read(deviceSettingsProvider.notifier)
                            .updateSettings(
                              settings.copyWith(criticalAlertVibrate: val),
                            );
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Sign Out Button
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.statusCritical,
                side: const BorderSide(color: AppColors.statusCritical),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () async {
                await ref.read(supabaseServiceProvider).signOut();
                if (context.mounted) {
                  context.go('/login');
                }
              },
              icon: const Icon(Icons.logout),
              label: const Text('Sign Out of MediGuard'),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
