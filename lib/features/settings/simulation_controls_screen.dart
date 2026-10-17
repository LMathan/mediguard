import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/alert_item.dart';
import '../../data/services/demo_sensor_service.dart';
import '../../shared/providers/app_providers.dart';

class SimulationControlsScreen extends ConsumerWidget {
  const SimulationControlsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final demoService = ref.watch(demoSensorServiceProvider);
    final activeScenario = demoService.currentScenario;

    return Scaffold(
      appBar: AppBar(title: const Text('Simulation Control Panel')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.demoBannerBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.demoBannerBorder),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.science,
                    color: AppColors.demoBannerText,
                    size: 28,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Developer Simulation Controls',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.demoBannerText,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Trigger environmental faults, door cycles, and sensor anomalies to test app resilience and UI states.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.demoBannerText,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            const Text(
              'Select Simulation Scenario',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),

            // Scenario Cards
            _buildScenarioTile(
              ref: ref,
              scenario: SimulationScenario.normal,
              title: '1. Nominal Stable Operation',
              desc:
                  'Cold: 4.2°C, Room: 21.5°C, Cooling: Active, Doors: Sealed.',
              isActive: activeScenario == SimulationScenario.normal,
              color: AppColors.statusNormal,
              icon: Icons.check_circle_outline,
            ),
            const SizedBox(height: 10),

            _buildScenarioTile(
              ref: ref,
              scenario: SimulationScenario.warning,
              title: '2. Environmental Warning (Cold 8.8°C)',
              desc:
                  'Cold compartment temp exceeds configured 8.0°C upper boundary.',
              isActive: activeScenario == SimulationScenario.warning,
              color: AppColors.statusWarning,
              icon: Icons.warning_amber_rounded,
            ),
            const SizedBox(height: 10),

            _buildScenarioTile(
              ref: ref,
              scenario: SimulationScenario.critical,
              title: '3. Critical Condition (Cold 14.5°C)',
              desc:
                  'Peltier failure simulated; temperatures skyrocket dangerously.',
              isActive: activeScenario == SimulationScenario.critical,
              color: AppColors.statusCritical,
              icon: Icons.dangerous_outlined,
            ),
            const SizedBox(height: 10),

            _buildScenarioTile(
              ref: ref,
              scenario: SimulationScenario.doorOpen,
              title: '4. Compartment Door Left Open',
              desc: 'Cold reed switch open, light detected, temp slowly warms.',
              isActive: activeScenario == SimulationScenario.doorOpen,
              color: const Color(0xFF0284C7),
              icon: Icons.sensor_door_outlined,
            ),
            const SizedBox(height: 10),

            _buildScenarioTile(
              ref: ref,
              scenario: SimulationScenario.sensorError,
              title: '5. Sensor Checksum Error Fault',
              desc: 'DHT22 CRC failure; sensor health changes to Error.',
              isActive: activeScenario == SimulationScenario.sensorError,
              color: Colors.deepPurple,
              icon: Icons.build_circle_outlined,
            ),
            const SizedBox(height: 10),

            _buildScenarioTile(
              ref: ref,
              scenario: SimulationScenario.staleData,
              title: '6. Stale Telemetry (>60s Inactive)',
              desc:
                  'Readings stop refreshing; tests Unknown/Stale fallback state.',
              isActive: activeScenario == SimulationScenario.staleData,
              color: Colors.brown,
              icon: Icons.timer_off_outlined,
            ),
            const SizedBox(height: 10),

            _buildScenarioTile(
              ref: ref,
              scenario: SimulationScenario.offline,
              title: '7. Hardware Completely Offline',
              desc: 'No telemetry emitted; device connection marked offline.',
              isActive: activeScenario == SimulationScenario.offline,
              color: Colors.blueGrey,
              icon: Icons.wifi_off_rounded,
            ),
            const SizedBox(height: 10),

            _buildScenarioTile(
              ref: ref,
              scenario: SimulationScenario.recovery,
              title: '8. Recovery Back to Nominal',
              desc:
                  'Glides temperatures back into safe range; resolves warnings.',
              isActive: activeScenario == SimulationScenario.recovery,
              color: AppColors.statusNormal,
              icon: Icons.restart_alt_rounded,
            ),
            const SizedBox(height: 24),

            // Test Alert Trigger Button
            const Text(
              'Alert Engine Test Trigger',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () async {
                await ref
                    .read(alertsProvider.notifier)
                    .createAlertIfNew(
                      AlertItem(
                        id: '',
                        type: AlertType.highTemp,
                        title: 'Test Triggered Alert: High Cold Temp',
                        message:
                            'Simulated high temperature spike detected at 11.2°C.',
                        severity: AlertSeverity.critical,
                        status: AlertStatus.active,
                        createdAt: DateTime.now(),
                      ),
                    );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Test alert dispatched & deduplicated.'),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.notification_add_outlined),
              label: const Text('Dispatch Test Critical Alert'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScenarioTile({
    required WidgetRef ref,
    required SimulationScenario scenario,
    required String title,
    required String desc,
    required bool isActive,
    required Color color,
    required IconData icon,
  }) {
    return InkWell(
      onTap: () {
        ref.read(demoSensorServiceProvider).setScenario(scenario);
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive ? color : AppColors.border,
            width: isActive ? 2 : 1,
          ),
          boxShadow: [
            if (isActive)
              BoxShadow(
                color: color.withValues(alpha: 0.15),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isActive ? color : AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (isActive)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'ACTIVE',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    desc,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
