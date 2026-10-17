import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/sensor_reading.dart';

class StatusBadge extends StatelessWidget {
  final OverallStatus status;
  final bool isCompact;

  const StatusBadge({super.key, required this.status, this.isCompact = false});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color text;
    IconData icon;

    switch (status) {
      case OverallStatus.normal:
        bg = AppColors.statusNormalBg;
        text = AppColors.statusNormal;
        icon = Icons.check_circle_outline;
        break;
      case OverallStatus.warning:
        bg = AppColors.statusWarningBg;
        text = AppColors.statusWarning;
        icon = Icons.warning_amber_rounded;
        break;
      case OverallStatus.critical:
        bg = AppColors.statusCriticalBg;
        text = AppColors.statusCritical;
        icon = Icons.error_outline_rounded;
        break;
      case OverallStatus.unknown:
      case OverallStatus.offline:
        bg = AppColors.statusOfflineBg;
        text = AppColors.statusOffline;
        icon = Icons.cloud_off_outlined;
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 8 : 12,
        vertical: isCompact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: text.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: isCompact ? 14 : 16, color: text),
          const SizedBox(width: 6),
          Text(
            status.label.toUpperCase(),
            style: TextStyle(
              color: text,
              fontSize: isCompact ? 11 : 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}
