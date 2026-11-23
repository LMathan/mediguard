import 'package:flutter_test/flutter_test.dart';
import 'package:mediguard/data/models/risk_assessment.dart';
import 'package:mediguard/data/models/sensor_reading.dart';

void main() {
  group('Risk Assessment Prototype Logic Tests', () {
    test('Cold temp up to 20°C and Room temp up to 28°C are Low Risk', () {
      final tracker = DoorAndLightExposureTracker.instance..reset();
      final now = DateTime.now();

      final reading = SensorReading(
        normalTemperatureC: 27.5,
        normalHumidityPct: 65.0,
        coldTemperatureC: 19.5,
        coldHumidityPct: 68.0,
        normalDoorOpen: false,
        coldDoorOpen: false,
        normalLightDetected: true,
        coldLightDetected: true,
        sensorHealth: SensorHealth.healthy,
        dataSource: DataSourceType.hardware,
        recordedAt: now,
      );

      final assessment = RiskAssessment.fromReading(
        reading,
        null,
        tracker,
        now,
      );

      expect(assessment.level, equals(RiskLevel.low));
      expect(assessment.condition, equals(HealthCondition.healthy));
      expect(assessment.score, equals(0.0));
      expect(assessment.riskFactors, isEmpty);
    });

    test('Cold temp above 20°C calculates excursion risk points', () {
      final tracker = DoorAndLightExposureTracker.instance..reset();
      final now = DateTime.now();

      final reading = SensorReading(
        normalTemperatureC: 24.0,
        normalHumidityPct: 55.0,
        coldTemperatureC: 22.0, // Excursion > 20°C
        coldHumidityPct: 50.0,
        recordedAt: now,
      );

      final assessment = RiskAssessment.fromReading(
        reading,
        null,
        tracker,
        now,
      );

      expect(assessment.coldScore, greaterThan(0.0));
      expect(assessment.riskFactors.any((f) => f.contains('Cold Temp High')), isTrue);
    });

    test('Room temp above 28°C calculates excursion risk points', () {
      final tracker = DoorAndLightExposureTracker.instance..reset();
      final now = DateTime.now();

      final reading = SensorReading(
        normalTemperatureC: 29.5, // Excursion > 28°C
        normalHumidityPct: 55.0,
        coldTemperatureC: 15.0,
        coldHumidityPct: 50.0,
        recordedAt: now,
      );

      final assessment = RiskAssessment.fromReading(
        reading,
        null,
        tracker,
        now,
      );

      expect(assessment.normalScore, greaterThan(0.0));
      expect(assessment.riskFactors.any((f) => f.contains('Room Temp High')), isTrue);
    });

    test('Cold humidity up to 70% is normal, >70% adds penalty points', () {
      final tracker = DoorAndLightExposureTracker.instance..reset();
      final now = DateTime.now();

      final normalHumidityReading = SensorReading(
        normalTemperatureC: 25.0,
        normalHumidityPct: 60.0,
        coldTemperatureC: 15.0,
        coldHumidityPct: 69.0, // <= 70% is normal
        recordedAt: now,
      );

      final normalAssessment = RiskAssessment.fromReading(
        normalHumidityReading,
        null,
        tracker,
        now,
      );
      expect(normalAssessment.coldScore, equals(0.0));

      final highHumidityReading = SensorReading(
        normalTemperatureC: 25.0,
        normalHumidityPct: 60.0,
        coldTemperatureC: 15.0,
        coldHumidityPct: 75.0, // > 70% adds points
        recordedAt: now,
      );

      final highAssessment = RiskAssessment.fromReading(
        highHumidityReading,
        null,
        tracker,
        now,
      );
      expect(highAssessment.coldScore, equals(10.0));
      expect(highAssessment.riskFactors.any((f) => f.contains('Cold Humidity')), isTrue);
    });

    test('Door open under 1 minute does NOT calculate risk points', () {
      final tracker = DoorAndLightExposureTracker.instance..reset();
      final startTime = DateTime.now();

      final reading = SensorReading(
        normalTemperatureC: 25.0,
        normalHumidityPct: 50.0,
        coldTemperatureC: 15.0,
        coldHumidityPct: 50.0,
        coldDoorOpen: true, // Just opened
        recordedAt: startTime,
      );

      final assessment = RiskAssessment.fromReading(
        reading,
        null,
        tracker,
        startTime,
      );

      expect(assessment.coldScore, equals(0.0));
      expect(assessment.riskFactors, isEmpty);
    });

    test('Door open for more than 1 minute DOES calculate risk points', () {
      final tracker = DoorAndLightExposureTracker.instance..reset();
      final startTime = DateTime.now();

      final reading = SensorReading(
        normalTemperatureC: 25.0,
        normalHumidityPct: 50.0,
        coldTemperatureC: 15.0,
        coldHumidityPct: 50.0,
        coldDoorOpen: true,
        recordedAt: startTime,
      );

      // Record first opening
      RiskAssessment.fromReading(reading, null, tracker, startTime);

      // Simulate 65 seconds later with door still open
      final laterTime = startTime.add(const Duration(seconds: 65));
      final prolongedAssessment = RiskAssessment.fromReading(
        reading,
        null,
        tracker,
        laterTime,
      );

      expect(prolongedAssessment.coldScore, equals(25.0));
      expect(
        prolongedAssessment.riskFactors.any((f) => f.contains('Cold Door Open (>1 min)')),
        isTrue,
      );
    });

    test('Light exposed under 1 minute does NOT calculate risk points', () {
      final tracker = DoorAndLightExposureTracker.instance..reset();
      final startTime = DateTime.now();

      final reading = SensorReading(
        normalTemperatureC: 25.0,
        normalHumidityPct: 50.0,
        coldTemperatureC: 15.0,
        coldHumidityPct: 50.0,
        coldLightDetected: false, // Inverted: false = light exposed
        recordedAt: startTime,
      );

      final assessment = RiskAssessment.fromReading(
        reading,
        null,
        tracker,
        startTime,
      );

      expect(assessment.coldScore, equals(0.0));
      expect(assessment.riskFactors, isEmpty);
    });

    test('Light exposed for more than 1 minute DOES calculate risk points', () {
      final tracker = DoorAndLightExposureTracker.instance..reset();
      final startTime = DateTime.now();

      final reading = SensorReading(
        normalTemperatureC: 25.0,
        normalHumidityPct: 50.0,
        coldTemperatureC: 15.0,
        coldHumidityPct: 50.0,
        coldLightDetected: false, // Inverted: false = light exposed
        recordedAt: startTime,
      );

      // Record first light detection
      RiskAssessment.fromReading(reading, null, tracker, startTime);

      // Simulate 65 seconds later
      final laterTime = startTime.add(const Duration(seconds: 65));
      final prolongedAssessment = RiskAssessment.fromReading(
        reading,
        null,
        tracker,
        laterTime,
      );

      expect(prolongedAssessment.coldScore, equals(20.0));
      expect(
        prolongedAssessment.riskFactors.any((f) => f.contains('Cold LDR: Light Exposed (>1 min)')),
        isTrue,
      );
    });

    test('Device offline (>60s inactivity) marks 100% High Risk and offline condition', () {
      final oldReading = SensorReading(
        normalTemperatureC: 24.0,
        normalHumidityPct: 50.0,
        coldTemperatureC: 15.0,
        coldHumidityPct: 50.0,
        recordedAt: DateTime.now().subtract(const Duration(seconds: 75)),
      );

      final assessment = RiskAssessment.fromReading(oldReading);

      expect(assessment.score, equals(100.0));
      expect(assessment.level, equals(RiskLevel.high));
      expect(assessment.condition, equals(HealthCondition.offline));
      expect(assessment.riskFactors.any((f) => f.contains('Device offline')), isTrue);
    });
  });
}
