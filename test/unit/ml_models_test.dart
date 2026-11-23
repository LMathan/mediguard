import 'package:flutter_test/flutter_test.dart';
import 'package:mediguard/data/models/ml_models.dart';
import 'package:mediguard/data/models/sensor_reading.dart';

void main() {
  group('ML Model 1: Predictive Temperature Excursion Tests', () {
    test('Predicts steady-state temperature when readings are stable', () {
      final now = DateTime.now();
      final history = List.generate(10, (i) {
        return SensorReading(
          normalTemperatureC: 22.0,
          normalHumidityPct: 50.0,
          coldTemperatureC: 5.0,
          coldHumidityPct: 55.0,
          recordedAt: now.subtract(Duration(minutes: 10 - i)),
        );
      });

      final current = history.last;
      final forecast = TemperatureForecast.predict(
        history: history,
        currentReading: current,
        coldThreshold: 20.0,
        normalThreshold: 28.0,
      );

      expect(forecast.coldSlopePerMin.abs(), lessThan(0.01));
      expect(forecast.predictedCold15m, closeTo(5.0, 0.5));
      expect(forecast.predictedCold30m, closeTo(5.0, 0.5));
      expect(forecast.coldRisk, equals(ExcursionRiskLevel.safe));
    });

    test('Predicts excursion breach when temperature trends rapidly upwards', () {
      final now = DateTime.now();
      // Temperature climbing from 14°C to 19°C over 10 minutes (+0.5°C/min)
      final history = List.generate(10, (i) {
        return SensorReading(
          normalTemperatureC: 24.0,
          normalHumidityPct: 50.0,
          coldTemperatureC: 14.0 + (i * 0.5),
          coldHumidityPct: 55.0,
          recordedAt: now.subtract(Duration(minutes: 10 - i)),
        );
      });

      final current = history.last; // ~18.5°C
      final forecast = TemperatureForecast.predict(
        history: history,
        currentReading: current,
        coldThreshold: 20.0,
        normalThreshold: 28.0,
      );

      expect(forecast.coldSlopePerMin, greaterThan(0.3));
      // Projected to exceed 20.0°C within 15 minutes
      expect(forecast.predictedCold15m, greaterThanOrEqualTo(20.0));
      expect(forecast.coldRisk, equals(ExcursionRiskLevel.imminent));
      expect(forecast.timeToColdBreachMins, isNotNull);
      expect(forecast.timeToColdBreachMins!, lessThan(15.0));
    });
  });

  group('ML Model 2: Predictive Hardware Anomaly Detection Tests', () {
    test('Identifies nominal actuator state under normal conditions', () {
      final now = DateTime.now();
      final history = List.generate(8, (i) {
        return SensorReading(
          normalTemperatureC: 22.0,
          normalHumidityPct: 50.0,
          coldTemperatureC: 10.0 - (i * 0.2), // Cooling down
          coldHumidityPct: 55.0,
          coolingActive: true,
          coldDoorOpen: false,
          recordedAt: now.subtract(Duration(minutes: 8 - i)),
        );
      });

      final current = history.last;
      final assessment = HardwareAnomalyAssessment.detect(
        history: history,
        currentReading: current,
      );

      expect(assessment.isAnomalyDetected, isFalse);
      expect(assessment.anomalyType, equals(HardwareAnomalyType.none));
      expect(assessment.peltierHealthScore, greaterThanOrEqualTo(90.0));
    });

    test('Detects thermal runaway when cooling is active but chamber is heating up', () {
      final now = DateTime.now();
      // Cooling is active, door is closed, but cold chamber rises from 10°C to 16°C
      final history = List.generate(8, (i) {
        return SensorReading(
          normalTemperatureC: 22.0,
          normalHumidityPct: 50.0,
          coldTemperatureC: 10.0 + (i * 0.8), // Temperature climbing!
          coldHumidityPct: 55.0,
          coolingActive: true,
          coldDoorOpen: false,
          recordedAt: now.subtract(Duration(minutes: 8 - i)),
        );
      });

      final current = history.last;
      final assessment = HardwareAnomalyAssessment.detect(
        history: history,
        currentReading: current,
      );

      expect(assessment.isAnomalyDetected, isTrue);
      expect(assessment.anomalyType, equals(HardwareAnomalyType.thermalRunaway));
      expect(assessment.overallActuatorHealth, lessThan(60.0));
    });
  });
}
