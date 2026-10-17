import 'package:flutter_test/flutter_test.dart';
import 'package:mediguard/data/models/sensor_reading.dart';
import 'package:mediguard/data/services/demo_sensor_service.dart';

void main() {
  group('DemoSensorService Scenario Generation Tests', () {
    late DemoSensorService service;

    setUp(() {
      service = DemoSensorService();
    });

    tearDown(() {
      service.dispose();
    });

    test('All simulated readings strictly carry DataSourceType.simulated', () {
      service.setScenario(SimulationScenario.normal);
      expect(
        service.latestReading.dataSource,
        equals(DataSourceType.simulated),
      );

      service.setScenario(SimulationScenario.critical);
      expect(
        service.latestReading.dataSource,
        equals(DataSourceType.simulated),
      );

      final history = service.generateSampleHistory();
      for (final pt in history) {
        expect(pt.dataSource, equals(DataSourceType.simulated));
      }
    });

    test(
      'Critical scenario triggers high temperature and inactive cooling',
      () {
        service.setScenario(SimulationScenario.critical);
        final reading = service.latestReading;

        expect(reading.coldTemperatureC, greaterThan(12.0));
        expect(reading.coolingActive, isFalse);
        expect(reading.sensorHealth, equals(SensorHealth.error));
      },
    );

    test('Door open scenario registers cold door open and light detected', () {
      service.setScenario(SimulationScenario.doorOpen);
      final reading = service.latestReading;

      expect(reading.coldDoorOpen, isTrue);
      expect(reading.coldLightDetected, isTrue);
    });

    test(
      'Sensor error scenario produces fault sentinel and sensor health error',
      () {
        service.setScenario(SimulationScenario.sensorError);
        final reading = service.latestReading;

        expect(reading.sensorHealth, equals(SensorHealth.error));
      },
    );
  });
}
