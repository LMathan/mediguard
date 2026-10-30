import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../data/services/onesignal_service.dart';

class NotificationPermissionSheet extends StatelessWidget {
  const NotificationPermissionSheet({super.key});

  static bool _isShowing = false;

  static Future<void> showIfNeeded(BuildContext context) async {
    if (_isShowing) return;

    final hasPermission = await OneSignalService().checkPermission();
    if (hasPermission) return;

    if (!context.mounted) return;
    _isShowing = true;
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => const NotificationPermissionSheet(),
      );
    } finally {
      _isShowing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Icon header
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.mintAccent, width: 2),
              ),
              child: const Icon(
                Icons.notifications_active_rounded,
                size: 36,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Title
          const Text(
            'Enable Critical Push Alerts',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),

          // Subtitle
          const Text(
            'MediGuard monitors sensitive pharmaceuticals 24/7. Allow notifications to receive instant alerts even when the app is completely closed.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),

          // Benefits bullet list
          _buildBenefitRow(
            icon: Icons.ac_unit_rounded,
            color: Colors.blue,
            title: 'Temperature Breaches',
            desc: 'Immediate warning if cold storage drops <2°C or exceeds 8°C.',
          ),
          const SizedBox(height: 12),
          _buildBenefitRow(
            icon: Icons.door_front_door_outlined,
            color: Colors.amber.shade800,
            title: 'Door Left Open',
            desc: 'Get alerted before room warmth damages medicines.',
          ),
          const SizedBox(height: 12),
          _buildBenefitRow(
            icon: Icons.wifi_off_rounded,
            color: Colors.red.shade700,
            title: 'Device Disconnections',
            desc: 'Server alerts you within 60s if the unit loses Wi-Fi or power.',
          ),
          const SizedBox(height: 24),

          // Enable Button
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await OneSignalService().requestPermission();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Enable Notifications',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 8),

          // Later Button
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Maybe Later',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitRow({
    required IconData icon,
    required Color color,
    required String title,
    required String desc,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
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
    );
  }
}
