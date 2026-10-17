import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
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

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
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
                ],
              ),
            ),
          ],
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
