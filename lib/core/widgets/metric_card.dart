import 'package:flutter/material.dart';
import '../../data/models/risk_assessment.dart';
import '../theme/app_colors.dart';

class CompartmentMetricCard extends StatelessWidget {
  final String title;
  final String targetRange;
  final double temperature;
  final double humidity;
  final bool isDoorOpen;
  final bool isCoolingActive;
  final bool isFanActive;
  final bool isCold;
  final bool isWithinRange;
  final bool isLightDetected;
  final RiskLevel? riskLevel;
  final double? riskScore;

  const CompartmentMetricCard({
    super.key,
    required this.title,
    required this.targetRange,
    required this.temperature,
    required this.humidity,
    required this.isDoorOpen,
    this.isCoolingActive = false,
    this.isFanActive = false,
    required this.isCold,
    required this.isWithinRange,
    this.isLightDetected = false,
    this.riskLevel,
    this.riskScore,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor = isCold
        ? AppColors.coldCompartment
        : AppColors.normalCompartment;
    final accentBg = isCold
        ? AppColors.coldCompartmentBg
        : AppColors.normalCompartmentBg;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isWithinRange ? AppColors.border : AppColors.statusWarning,
          width: isWithinRange ? 1 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isCold ? Icons.ac_unit_rounded : Icons.thermostat_outlined,
                  size: 20,
                  color: accentColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Target: $targetRange',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),

              // Compartment Risk Badge
              if (riskLevel != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: riskLevel!.bgColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: riskLevel!.color.withValues(alpha: 0.3),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: riskLevel!.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        riskLevel == RiskLevel.medium
                            ? 'MED RISK'
                            : riskLevel!.label.toUpperCase(),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: riskLevel!.color,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
              ],

              // Door Status Chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDoorOpen
                      ? AppColors.statusWarningBg
                      : AppColors.statusNormalBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isDoorOpen
                          ? Icons.sensor_door_outlined
                          : Icons.door_front_door_outlined,
                      size: 13,
                      color: isDoorOpen
                          ? AppColors.statusWarning
                          : AppColors.statusNormal,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isDoorOpen ? 'DOOR OPEN' : 'CLOSED',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: isDoorOpen
                            ? AppColors.statusWarning
                            : AppColors.statusNormal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Primary Readings Row (Temperature, Humidity, LDR Light Sensor)
          Row(
            children: [
              // 1. Temperature
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'TEMPERATURE',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            temperature.toStringAsFixed(1),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: isWithinRange
                                  ? AppColors.textPrimary
                                  : AppColors.statusWarning,
                            ),
                          ),
                          const Text(
                            ' °C',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // 2. Humidity
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'HUMIDITY',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            humidity.toStringAsFixed(0),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const Text(
                            ' %',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // 3. Light Sensor (LDR Module)
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: isLightDetected
                        ? const Color(0xFFFEF3C7)
                        : AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                    border: isLightDetected
                        ? Border.all(color: const Color(0xFFF59E0B), width: 1)
                        : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isLightDetected
                                ? Icons.wb_sunny_rounded
                                : Icons.nightlight_round,
                            size: 11,
                            color: isLightDetected
                                ? const Color(0xFFD97706)
                                : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          const Expanded(
                            child: Text(
                              'LIGHT (LDR)',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary,
                                letterSpacing: 0.4,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isLightDetected ? 'EXPOSED' : 'DARK',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: isLightDetected
                              ? const Color(0xFFB45309)
                              : const Color(0xFF16A34A),
                        ),
                      ),
                      Text(
                        isLightDetected ? 'Light Alert' : 'Safe / Sealed',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isLightDetected
                              ? const Color(0xFFD97706)
                              : AppColors.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Actuator status indicators (Peltier cooling & Fan) & Range
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isCold) ...[
                    _buildActuatorChip(
                      icon: Icons.ac_unit,
                      label: 'Peltier',
                      isActive: isCoolingActive,
                    ),
                    const SizedBox(width: 6),
                  ],
                  _buildActuatorChip(
                    icon: Icons.air,
                    label: 'Fan',
                    isActive: isFanActive,
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isLightDetected) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.warning_amber_rounded, size: 10, color: Color(0xFFD97706)),
                          SizedBox(width: 3),
                          Text(
                            'Photo-risk',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFB45309),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    isWithinRange ? 'Within Limits' : 'Out of Bounds',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isWithinRange
                          ? AppColors.statusNormal
                          : AppColors.statusWarning,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActuatorChip({
    required IconData icon,
    required String label,
    required bool isActive,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: isActive ? AppColors.mintSurface : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isActive ? AppColors.mintAccent : AppColors.border,
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 11,
            color: isActive ? AppColors.primary : AppColors.textMuted,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isActive ? AppColors.primary : AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
