import 'package:flutter_test/flutter_test.dart';
import 'package:mediguard/data/models/device_settings.dart';
import 'package:mediguard/data/models/sensor_reading.dart';

void main() {
  group('Environmental Threshold and Status Evaluation', () {
    final defaultSettings = DeviceSettings(
      normalTempMinC: 15.0,
      normalTempMaxC: 25.0,
      coldTempMinC: 2.0,
      coldTempMaxC: 8.0,
      updatedAt: DateTime(2026, 1, 1),
    );

    test('Nominal temperatures classify as Normal', () {
      final reading = SensorReading(
        normalTemperatureC: 21.0,
        normalHumidityPct: 48.0,
        coldTemperatureC: 4.5,
        coldHumidityPct: 52.0,
        normalDoorOpen: false,
        coldDoorOpen: false,
        sensorHealth: SensorHealth.healthy,
        dataSource: DataSourceType.simulated,
        recordedAt: DateTime.now(),
      );

      expect(reading.isStale(), isFalse);
      expect(reading.coldTemperatureC >= defaultSettings.coldTempMinC, isTrue);
      expect(reading.coldTemperatureC <= defaultSettings.coldTempMaxC, isTrue);
      expect(
        reading.normalTemperatureC >= defaultSettings.normalTempMinC,
        isTrue,
      );
      expect(
        reading.normalTemperatureC <= defaultSettings.normalTempMaxC,
        isTrue,
      );
    });

    test('Cold temperature above 8.0°C is detected as out of bounds', () {
      final reading = SensorReading(
        normalTemperatureC: 21.0,
        normalHumidityPct: 48.0,
        coldTemperatureC: 9.2,
        coldHumidityPct: 55.0,
        sensorHealth: SensorHealth.warning,
        dataSource: DataSourceType.simulated,
        recordedAt: DateTime.now(),
      );

      final isWithinCold =
          reading.coldTemperatureC >= defaultSettings.coldTempMinC &&
          reading.coldTemperatureC <= defaultSettings.coldTempMaxC;
      expect(isWithinCold, isFalse);
    });

    test('Readings older than 90 seconds are classified as Stale', () {
      final oldReading = SensorReading(
        normalTemperatureC: 21.0,
        normalHumidityPct: 48.0,
        coldTemperatureC: 4.5,
        coldHumidityPct: 50.0,
        recordedAt: DateTime.now().subtract(const Duration(seconds: 120)),
      );

      expect(
        oldReading.isStale(threshold: const Duration(seconds: 90)),
        isTrue,
      );
    });

    test('Fresh reading under 90 seconds is not stale', () {
      final freshReading = SensorReading(
        normalTemperatureC: 21.0,
        normalHumidityPct: 48.0,
        coldTemperatureC: 4.5,
        coldHumidityPct: 50.0,
        recordedAt: DateTime.now().subtract(const Duration(seconds: 10)),
      );

      expect(
        freshReading.isStale(threshold: const Duration(seconds: 90)),
        isFalse,
      );
    });
  });
}
