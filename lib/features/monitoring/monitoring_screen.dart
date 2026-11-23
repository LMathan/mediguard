import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/device_settings.dart';
import '../../data/models/ml_models.dart';
import '../../data/models/risk_assessment.dart';
import '../../data/models/sensor_reading.dart';
import '../../shared/providers/app_providers.dart';

class MonitoringScreen extends ConsumerStatefulWidget {
  const MonitoringScreen({super.key});

  @override
  ConsumerState<MonitoringScreen> createState() => _MonitoringScreenState();
}

class _MonitoringScreenState extends ConsumerState<MonitoringScreen> {
  Duration _selectedWindow = const Duration(hours: 24);

  @override
  Widget build(BuildContext context) {
    final readingAsync = ref.watch(sensorReadingStreamProvider);
    final dataSource = ref.watch(sensorDataSourceProvider);
    final currentReading = readingAsync.value ?? dataSource.latestReading;
    final historyAsync = ref.watch(sensorHistoryProvider(_selectedWindow));
    final settings = ref.watch(deviceSettingsProvider).value;
    final riskAssessment = ref.watch(riskAssessmentProvider);
    final tempForecast = ref.watch(temperatureForecastProvider);
    final hardwareAnomaly = ref.watch(hardwareAnomalyProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(hardwareSensorServiceProvider).fetchLatest();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(18),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Telemetry Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Environmental Telemetry',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Data Source: ${currentReading.dataSource.label.toUpperCase()}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color:
                            currentReading.dataSource ==
                                DataSourceType.simulated
                            ? AppColors.demoBannerText
                            : AppColors.primary,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: currentReading.sensorHealth == SensorHealth.healthy
                        ? AppColors.statusNormalBg
                        : AppColors.statusWarningBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        currentReading.sensorHealth == SensorHealth.healthy
                            ? Icons.health_and_safety
                            : Icons.warning_amber_rounded,
                        size: 14,
                        color:
                            currentReading.sensorHealth == SensorHealth.healthy
                            ? AppColors.statusNormal
                            : AppColors.statusWarning,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        currentReading.sensorHealth.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color:
                              currentReading.sensorHealth ==
                                  SensorHealth.healthy
                              ? AppColors.statusNormal
                              : AppColors.statusWarning,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Time Window Selector Bar
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  _buildWindowTab(const Duration(hours: 1), '1 Hour'),
                  _buildWindowTab(const Duration(hours: 6), '6 Hours'),
                  _buildWindowTab(const Duration(hours: 24), '24 Hours'),
                  _buildWindowTab(const Duration(days: 7), '7 Days'),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 1. Storage Health & Risk Index (%) Graph
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
              ),
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: riskAssessment.level.bgColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.shield_outlined,
                              size: 16,
                              color: riskAssessment.level.color,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Storage Risk Index (%)',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                'Realtime Risk Calculated from Telemetry',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      // Current Risk Level Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: riskAssessment.level.bgColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: riskAssessment.level.color.withValues(
                              alpha: 0.3,
                            ),
                          ),
                        ),
                        child: Text(
                          '${riskAssessment.score.toStringAsFixed(0)}% • ${riskAssessment.level.label.toUpperCase()}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: riskAssessment.level.color,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Risk Thresholds Legend
                  Row(
                    children: [
                      _buildLegendDot(const Color(0xFF16A34A), 'Low (0-25%)'),
                      const SizedBox(width: 10),
                      _buildLegendDot(const Color(0xFFD97706), 'Med (26-60%)'),
                      const SizedBox(width: 10),
                      _buildLegendDot(const Color(0xFFDC2626), 'High (61-100%)'),
                    ],
                  ),
                  const SizedBox(height: 18),

                  SizedBox(
                    height: 190,
                    child: historyAsync.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Center(child: Text('Chart error: $e')),
                      data: (history) {
                        if (history.isEmpty) {
                          return const Center(
                            child: Text('No telemetry available for window.'),
                          );
                        }
                        return _buildRiskChart(history, settings);
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Temperature Time-Series Chart
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
              ),
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Temperature Profiles (°C)',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Row(
                        children: [
                          _buildLegendDot(
                            AppColors.coldCompartment,
                            'Cold (2-8°C)',
                          ),
                          const SizedBox(width: 12),
                          _buildLegendDot(
                            AppColors.normalCompartment,
                            'Room (15-25°C)',
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 200,
                    child: historyAsync.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Center(child: Text('Chart error: $e')),
                      data: (history) {
                        if (history.isEmpty) {
                          return const Center(
                            child: Text('No telemetry available for window.'),
                          );
                        }
                        return _buildTemperatureChart(history);
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Relative Humidity Chart
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
              ),
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Relative Humidity (%)',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Row(
                        children: [
                          _buildLegendDot(Colors.blueAccent, 'Cold Zone'),
                          const SizedBox(width: 12),
                          _buildLegendDot(Colors.teal, 'Room Zone'),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 180,
                    child: historyAsync.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Center(child: Text('Chart error: $e')),
                      data: (history) {
                        if (history.isEmpty) {
                          return const Center(
                            child: Text('No telemetry available for window.'),
                          );
                        }
                        return _buildHumidityChart(history);
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Actuator and Sensor Diagnostics Card
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
                    'Hardware & Actuator Diagnostics',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDiagnosticTile(
                          title: 'Peltier Cooler',
                          status: currentReading.coolingActive
                              ? 'Active Cooling'
                              : 'Standby',
                          isActive: currentReading.coolingActive,
                          icon: Icons.ac_unit,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildDiagnosticTile(
                          title: 'Circulation Fan',
                          status: currentReading.normalFanActive
                              ? 'Circulating'
                              : 'Off',
                          isActive: currentReading.normalFanActive,
                          icon: Icons.air,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDiagnosticTile(
                          title: 'Cold Reed Switch',
                          status: currentReading.coldDoorOpen
                              ? 'DOOR OPEN'
                              : 'Door Sealed',
                          isActive: !currentReading.coldDoorOpen,
                          icon: Icons.door_front_door_outlined,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildDiagnosticTile(
                          title: 'Room Reed Switch',
                          status: currentReading.normalDoorOpen
                              ? 'DOOR OPEN'
                              : 'Door Sealed',
                          isActive: !currentReading.normalDoorOpen,
                          icon: Icons.door_front_door_outlined,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDiagnosticTile(
                          title: 'Cold LDR Sensor',
                          status: currentReading.coldLightDetected
                              ? 'LIGHT DETECTED'
                              : 'Dark (Protected)',
                          isActive: !currentReading.coldLightDetected,
                          icon: currentReading.coldLightDetected
                              ? Icons.wb_sunny_rounded
                              : Icons.nightlight_round,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildDiagnosticTile(
                          title: 'Room LDR Sensor',
                          status: currentReading.normalLightDetected
                              ? 'LIGHT DETECTED'
                              : 'Dark (Protected)',
                          isActive: !currentReading.normalLightDetected,
                          icon: currentReading.normalLightDetected
                              ? Icons.wb_sunny_rounded
                              : Icons.nightlight_round,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 5. ML Model 1: Predictive Temperature Excursion Forecasting
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
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
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3E8FF),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.auto_graph_rounded,
                              size: 18,
                              color: Color(0xFF7E22CE),
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Predictive Temperature Excursion',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                'ML Linear Regression Trend Model',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3E8FF),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFF7E22CE).withValues(alpha: 0.3),
                          ),
                        ),
                        child: const Text(
                          'ML MODEL 1',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF7E22CE),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Forecast comparison cards (+15m & +30m)
                  Row(
                    children: [
                      // 15 Min Forecast
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.schedule, size: 12, color: AppColors.textSecondary),
                                  SizedBox(width: 4),
                                  Text(
                                    '+15 MIN FORECAST',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textSecondary,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Cold Chamber',
                                        style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
                                      ),
                                      Text(
                                        '${tempForecast.predictedCold15m.toStringAsFixed(1)}°C',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: tempForecast.predictedCold15m > 20.0
                                              ? const Color(0xFFDC2626)
                                              : AppColors.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      const Text(
                                        'Room Chamber',
                                        style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
                                      ),
                                      Text(
                                        '${tempForecast.predictedNormal15m.toStringAsFixed(1)}°C',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: tempForecast.predictedNormal15m > 28.0
                                              ? const Color(0xFFDC2626)
                                              : AppColors.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // 30 Min Forecast
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.schedule, size: 12, color: AppColors.textSecondary),
                                  SizedBox(width: 4),
                                  Text(
                                    '+30 MIN FORECAST',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textSecondary,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Cold Chamber',
                                        style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
                                      ),
                                      Text(
                                        '${tempForecast.predictedCold30m.toStringAsFixed(1)}°C',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: tempForecast.predictedCold30m > 20.0
                                              ? const Color(0xFFDC2626)
                                              : AppColors.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      const Text(
                                        'Room Chamber',
                                        style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
                                      ),
                                      Text(
                                        '${tempForecast.predictedNormal30m.toStringAsFixed(1)}°C',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: tempForecast.predictedNormal30m > 28.0
                                              ? const Color(0xFFDC2626)
                                              : AppColors.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Model Summary & Confidence Bar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: tempForecast.coldRisk == ExcursionRiskLevel.imminent
                          ? const Color(0xFFFEE2E2)
                          : const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: tempForecast.coldRisk == ExcursionRiskLevel.imminent
                            ? const Color(0xFFFCA5A5)
                            : const Color(0xFFBBF7D0),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          tempForecast.coldRisk == ExcursionRiskLevel.imminent
                              ? Icons.warning_rounded
                              : Icons.check_circle_rounded,
                          size: 16,
                          color: tempForecast.coldRisk == ExcursionRiskLevel.imminent
                              ? const Color(0xFFDC2626)
                              : const Color(0xFF16A34A),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            tempForecast.forecastSummary,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: tempForecast.coldRisk == ExcursionRiskLevel.imminent
                                  ? const Color(0xFFB91C1C)
                                  : const Color(0xFF15803D),
                            ),
                          ),
                        ),
                        Text(
                          'R² ${(tempForecast.confidenceScore * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 6. ML Model 2: Predictive Hardware Anomaly Detection
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
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
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE0F2FE),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.psychology_alt_rounded,
                              size: 18,
                              color: Color(0xFF0284C7),
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Hardware Anomaly Detection',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                'Multivariate Actuator & Peltier Analysis',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0F2FE),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFF0284C7).withValues(alpha: 0.3),
                          ),
                        ),
                        child: const Text(
                          'ML MODEL 2',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0284C7),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Health meter & Status
                  Row(
                    children: [
                      // Peltier Health
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'PELTIER COOLER HEALTH',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textSecondary,
                                  letterSpacing: 0.4,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Text(
                                    '${hardwareAnomaly.peltierHealthScore.toStringAsFixed(0)}%',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      color: hardwareAnomaly.peltierHealthScore >= 80.0
                                          ? const Color(0xFF16A34A)
                                          : const Color(0xFFD97706),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    hardwareAnomaly.peltierHealthScore >= 80.0
                                        ? 'Optimal'
                                        : 'Degraded',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: hardwareAnomaly.peltierHealthScore >= 80.0
                                          ? const Color(0xFF16A34A)
                                          : const Color(0xFFD97706),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Fan Circulation Health
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'CIRCULATION FAN HEALTH',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textSecondary,
                                  letterSpacing: 0.4,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Text(
                                    '${hardwareAnomaly.fanHealthScore.toStringAsFixed(0)}%',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      color: hardwareAnomaly.fanHealthScore >= 80.0
                                          ? const Color(0xFF16A34A)
                                          : const Color(0xFFD97706),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    hardwareAnomaly.fanHealthScore >= 80.0
                                        ? 'Nominal'
                                        : 'Restricted',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: hardwareAnomaly.fanHealthScore >= 80.0
                                          ? const Color(0xFF16A34A)
                                          : const Color(0xFFD97706),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Diagnostics Insight Box
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: hardwareAnomaly.isAnomalyDetected
                          ? const Color(0xFFFFFBEB)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: hardwareAnomaly.isAnomalyDetected
                            ? const Color(0xFFFDE68A)
                            : AppColors.border,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          hardwareAnomaly.isAnomalyDetected
                              ? Icons.warning_amber_rounded
                              : Icons.verified_rounded,
                          size: 16,
                          color: hardwareAnomaly.isAnomalyDetected
                              ? const Color(0xFFD97706)
                              : const Color(0xFF0284C7),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                hardwareAnomaly.anomalyType.label,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: hardwareAnomaly.isAnomalyDetected
                                      ? const Color(0xFFB45309)
                                      : AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                hardwareAnomaly.diagnosticMessage,
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  color: AppColors.textSecondary,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildWindowTab(Duration duration, String label) {
    final isSelected = _selectedWindow == duration;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedWindow = duration;
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildDiagnosticTile({
    required String title,
    required String status,
    required bool isActive,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: isActive ? AppColors.primary : AppColors.statusWarning,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  status,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isActive
                        ? AppColors.textPrimary
                        : AppColors.statusWarning,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRiskChart(List<SensorReading> history, DeviceSettings? settings) {
    final spots = <FlSpot>[];

    for (int i = 0; i < history.length; i++) {
      final assessment = RiskAssessment.fromReading(history[i], settings);
      spots.add(FlSpot(i.toDouble(), assessment.score));
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 25,
          getDrawingHorizontalLine: (value) {
            if (value == 25) {
              return FlLine(
                color: const Color(0xFF16A34A).withValues(alpha: 0.35),
                strokeWidth: 1,
                dashArray: [4, 4],
              );
            }
            if (value == 60) {
              return FlLine(
                color: const Color(0xFFDC2626).withValues(alpha: 0.35),
                strokeWidth: 1,
                dashArray: [4, 4],
              );
            }
            return const FlLine(color: AppColors.border, strokeWidth: 0.8);
          },
        ),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: (history.length / 4).clamp(1, 10).toDouble(),
              getTitlesWidget: (val, meta) {
                final idx = val.toInt();
                if (idx < 0 || idx >= history.length) {
                  return const SizedBox.shrink();
                }
                return Text(
                  Formatters.shortTime(history[idx].recordedAt),
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textMuted,
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 34,
              interval: 25,
              getTitlesWidget: (val, meta) => Text(
                '${val.toInt()}%',
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minY: 0,
        maxY: 100,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: const Color(0xFFD97706),
            barWidth: 2.5,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  const Color(0xFF16A34A).withValues(alpha: 0.05),
                  const Color(0xFFD97706).withValues(alpha: 0.15),
                  const Color(0xFFDC2626).withValues(alpha: 0.25),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTemperatureChart(List<SensorReading> history) {
    final coldSpots = <FlSpot>[];
    final normalSpots = <FlSpot>[];

    for (int i = 0; i < history.length; i++) {
      coldSpots.add(FlSpot(i.toDouble(), history[i].coldTemperatureC));
      normalSpots.add(FlSpot(i.toDouble(), history[i].normalTemperatureC));
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 5,
          getDrawingHorizontalLine: (value) =>
              const FlLine(color: AppColors.border, strokeWidth: 0.8),
        ),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: (history.length / 4).clamp(1, 10).toDouble(),
              getTitlesWidget: (val, meta) {
                final idx = val.toInt();
                if (idx < 0 || idx >= history.length) {
                  return const SizedBox.shrink();
                }
                return Text(
                  Formatters.shortTime(history[idx].recordedAt),
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textMuted,
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (val, meta) => Text(
                '${val.toInt()}°',
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minY: 0,
        maxY: 35,
        lineBarsData: [
          // Cold Compartment Line
          LineChartBarData(
            spots: coldSpots,
            isCurved: true,
            color: AppColors.coldCompartment,
            barWidth: 2.5,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.coldCompartment.withValues(alpha: 0.08),
            ),
          ),
          // Normal Compartment Line
          LineChartBarData(
            spots: normalSpots,
            isCurved: true,
            color: AppColors.normalCompartment,
            barWidth: 2.5,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.normalCompartment.withValues(alpha: 0.08),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHumidityChart(List<SensorReading> history) {
    final coldHumSpots = <FlSpot>[];
    final normalHumSpots = <FlSpot>[];

    for (int i = 0; i < history.length; i++) {
      coldHumSpots.add(FlSpot(i.toDouble(), history[i].coldHumidityPct));
      normalHumSpots.add(FlSpot(i.toDouble(), history[i].normalHumidityPct));
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 20,
          getDrawingHorizontalLine: (value) =>
              const FlLine(color: AppColors.border, strokeWidth: 0.8),
        ),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: (history.length / 4).clamp(1, 10).toDouble(),
              getTitlesWidget: (val, meta) {
                final idx = val.toInt();
                if (idx < 0 || idx >= history.length) {
                  return const SizedBox.shrink();
                }
                return Text(
                  Formatters.shortTime(history[idx].recordedAt),
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textMuted,
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (val, meta) => Text(
                '${val.toInt()}%',
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minY: 10,
        maxY: 90,
        lineBarsData: [
          LineChartBarData(
            spots: coldHumSpots,
            isCurved: true,
            color: Colors.blueAccent,
            barWidth: 2,
            dotData: const FlDotData(show: false),
          ),
          LineChartBarData(
            spots: normalHumSpots,
            isCurved: true,
            color: Colors.teal,
            barWidth: 2,
            dotData: const FlDotData(show: false),
          ),
        ],
      ),
    );
  }
}
