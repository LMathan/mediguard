import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/device_settings.dart';
import '../../shared/providers/app_providers.dart';

class ThresholdSettingsScreen extends ConsumerStatefulWidget {
  const ThresholdSettingsScreen({super.key});

  @override
  ConsumerState<ThresholdSettingsScreen> createState() =>
      _ThresholdSettingsScreenState();
}

class _ThresholdSettingsScreenState
    extends ConsumerState<ThresholdSettingsScreen> {
  late RangeValues _normalTempRange;
  late RangeValues _coldTempRange;
  late RangeValues _normalHumRange;
  late RangeValues _coldHumRange;
  late double _doorWarningSeconds;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final settings =
        ref.read(deviceSettingsProvider).value ??
        DeviceSettings.defaultSettings();
    _normalTempRange = RangeValues(
      settings.normalTempMinC,
      settings.normalTempMaxC,
    );
    _coldTempRange = RangeValues(settings.coldTempMinC, settings.coldTempMaxC);
    _normalHumRange = RangeValues(
      settings.normalHumidityMinPct,
      settings.normalHumidityMaxPct,
    );
    _coldHumRange = RangeValues(
      settings.coldHumidityMinPct,
      settings.coldHumidityMaxPct,
    );
    _doorWarningSeconds = settings.doorOpenWarningSeconds.toDouble();
  }

  Future<void> _saveThresholds() async {
    setState(() {
      _isSaving = true;
    });

    final current =
        ref.read(deviceSettingsProvider).value ??
        DeviceSettings.defaultSettings();
    final updated = current.copyWith(
      normalTempMinC: _normalTempRange.start,
      normalTempMaxC: _normalTempRange.end,
      normalHumidityMinPct: _normalHumRange.start,
      normalHumidityMaxPct: _normalHumRange.end,
      coldTempMinC: _coldTempRange.start,
      coldTempMaxC: _coldTempRange.end,
      coldHumidityMinPct: _coldHumRange.start,
      coldHumidityMaxPct: _coldHumRange.end,
      doorOpenWarningSeconds: _doorWarningSeconds.round(),
    );

    await ref.read(deviceSettingsProvider.notifier).updateSettings(updated);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.statusNormal,
          content: Text('Threshold configurations saved successfully.'),
        ),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Environmental Thresholds')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Important Advisory Banner
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.demoBannerBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.demoBannerBorder),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 20,
                    color: AppColors.demoBannerText,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Hardware Advisory: Configuring thresholds sets monitoring and alert boundaries. It does not control physical Peltier or fan duty cycles until hardware firmware integration is deployed.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.demoBannerText,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Cold Compartment Temperature
            _buildThresholdCard(
              title: '❄️ Cold Compartment Target Range',
              subtitle: 'Recommended prototype default: 2.0°C - 8.0°C',
              currentDisplay:
                  '${_coldTempRange.start.toStringAsFixed(1)}°C - ${_coldTempRange.end.toStringAsFixed(1)}°C',
              slider: RangeSlider(
                values: _coldTempRange,
                min: 0.0,
                max: 15.0,
                divisions: 30,
                activeColor: AppColors.coldCompartment,
                labels: RangeLabels(
                  '${_coldTempRange.start.toStringAsFixed(1)}°C',
                  '${_coldTempRange.end.toStringAsFixed(1)}°C',
                ),
                onChanged: (values) {
                  setState(() {
                    _coldTempRange = values;
                  });
                },
              ),
            ),
            const SizedBox(height: 16),

            // Normal Compartment Temperature
            _buildThresholdCard(
              title: '🌿 Normal Compartment Target Range',
              subtitle: 'Ambient medication range: 15.0°C - 25.0°C',
              currentDisplay:
                  '${_normalTempRange.start.toStringAsFixed(1)}°C - ${_normalTempRange.end.toStringAsFixed(1)}°C',
              slider: RangeSlider(
                values: _normalTempRange,
                min: 10.0,
                max: 35.0,
                divisions: 50,
                activeColor: AppColors.normalCompartment,
                labels: RangeLabels(
                  '${_normalTempRange.start.toStringAsFixed(1)}°C',
                  '${_normalTempRange.end.toStringAsFixed(1)}°C',
                ),
                onChanged: (values) {
                  setState(() {
                    _normalTempRange = values;
                  });
                },
              ),
            ),
            const SizedBox(height: 16),

            // Door Left Open Warning Duration
            _buildThresholdCard(
              title: '🚪 Door-Open Warning Trigger Delay',
              subtitle: 'Sound alarm when a door remains open continuously',
              currentDisplay: '${_doorWarningSeconds.round()} seconds',
              slider: Slider(
                value: _doorWarningSeconds,
                min: 15.0,
                max: 180.0,
                divisions: 11,
                activeColor: AppColors.primary,
                label: '${_doorWarningSeconds.round()}s',
                onChanged: (val) {
                  setState(() {
                    _doorWarningSeconds = val;
                  });
                },
              ),
            ),
            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: _isSaving ? null : _saveThresholds,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Save Threshold Settings'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThresholdCard({
    required String title,
    required String subtitle,
    required String currentDisplay,
    required Widget slider,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  currentDisplay,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          slider,
        ],
      ),
    );
  }
}
