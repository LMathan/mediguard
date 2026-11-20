import 'dart:math';
import 'package:flutter/material.dart';
import 'device_settings.dart';
import 'sensor_reading.dart';

enum RiskLevel {
  low,
  medium,
  high;

  String get label {
    switch (this) {
      case RiskLevel.low:
        return 'Low Risk';
      case RiskLevel.medium:
        return 'Medium Risk';
      case RiskLevel.high:
        return 'High Risk';
    }
  }

  Color get color {
    switch (this) {
      case RiskLevel.low:
        return const Color(0xFF16A34A); // Green
      case RiskLevel.medium:
        return const Color(0xFFD97706); // Amber / Orange
      case RiskLevel.high:
        return const Color(0xFFDC2626); // Red
    }
  }

  Color get bgColor {
    switch (this) {
      case RiskLevel.low:
        return const Color(0xFFDCFCE7);
      case RiskLevel.medium:
        return const Color(0xFFFEF3C7);
      case RiskLevel.high:
        return const Color(0xFFFEE2E2);
    }
  }
}

enum HealthCondition {
  healthy,
  atRisk,
  critical,
  offline;

  String get label {
    switch (this) {
      case HealthCondition.healthy:
        return 'Healthy';
      case HealthCondition.atRisk:
        return 'At Risk';
      case HealthCondition.critical:
        return 'Critical';
      case HealthCondition.offline:
        return 'Device Offline';
    }
  }

  Color get color {
    switch (this) {
      case HealthCondition.healthy:
        return const Color(0xFF16A34A);
      case HealthCondition.atRisk:
        return const Color(0xFFD97706);
      case HealthCondition.critical:
        return const Color(0xFFDC2626);
      case HealthCondition.offline:
        return Colors.grey;
    }
  }

  Color get bgColor {
    switch (this) {
      case HealthCondition.healthy:
        return const Color(0xFFDCFCE7);
      case HealthCondition.atRisk:
        return const Color(0xFFFEF3C7);
      case HealthCondition.critical:
        return const Color(0xFFFEE2E2);
      case HealthCondition.offline:
        return const Color(0xFFF1F5F9);
    }
  }

  IconData get icon {
    switch (this) {
      case HealthCondition.healthy:
        return Icons.health_and_safety_rounded;
      case HealthCondition.atRisk:
        return Icons.warning_amber_rounded;
      case HealthCondition.critical:
        return Icons.gpp_bad_rounded;
      case HealthCondition.offline:
        return Icons.cloud_off_rounded;
    }
  }
}

class RiskAssessment {
  final double score; // 0.0 to 100.0
  final RiskLevel level;
  final HealthCondition condition;
  final double coldScore;
  final RiskLevel coldLevel;
  final double normalScore;
  final RiskLevel normalLevel;
  final List<String> riskFactors;

  const RiskAssessment({
    required this.score,
    required this.level,
    required this.condition,
    required this.coldScore,
    required this.coldLevel,
    required this.normalScore,
    required this.normalLevel,
    required this.riskFactors,
  });

  factory RiskAssessment.fromReading(
    SensorReading reading, [
    DeviceSettings? settings,
  ]) {
    // If no readings have been recorded yet
    if (reading.recordedAt.millisecondsSinceEpoch == 0) {
      return const RiskAssessment(
        score: 100.0,
        level: RiskLevel.high,
        condition: HealthCondition.offline,
        coldScore: 100.0,
        coldLevel: RiskLevel.high,
        normalScore: 100.0,
        normalLevel: RiskLevel.high,
        riskFactors: ['Awaiting hardware telemetry in DB'],
      );
    }

    // If telemetry is older than 60s
    if (reading.isStale()) {
      return const RiskAssessment(
        score: 100.0,
        level: RiskLevel.high,
        condition: HealthCondition.offline,
        coldScore: 100.0,
        coldLevel: RiskLevel.high,
        normalScore: 100.0,
        normalLevel: RiskLevel.high,
        riskFactors: ['Device offline (>60s inactivity)'],
      );
    }

    final coldMin = settings?.coldTempMinC ?? 2.0;
    final coldMax = settings?.coldTempMaxC ?? 8.0;
    final normalMin = settings?.normalTempMinC ?? 15.0;
    final normalMax = settings?.normalTempMaxC ?? 25.0;

    double coldPoints = 0.0;
    double normalPoints = 0.0;
    final factors = <String>[];

    // 1. Cold Zone Temp
    if (reading.coldTemperatureC > coldMax) {
      final diff = reading.coldTemperatureC - coldMax;
      if (diff <= 2.0) {
        coldPoints += 20.0;
      } else if (diff <= 5.0) {
        coldPoints += 38.0;
      } else {
        coldPoints += 55.0;
      }
      factors.add('Cold Temp High (${reading.coldTemperatureC.toStringAsFixed(1)}°C)');
    } else if (reading.coldTemperatureC < coldMin) {
      final diff = coldMin - reading.coldTemperatureC;
      if (diff <= 2.0) {
        coldPoints += 22.0;
      } else {
        coldPoints += 50.0;
      }
      factors.add('Cold Temp Low (${reading.coldTemperatureC.toStringAsFixed(1)}°C)');
    }

    // 2. Normal Zone Temp
    if (reading.normalTemperatureC > normalMax) {
      final diff = reading.normalTemperatureC - normalMax;
      if (diff <= 3.0) {
        normalPoints += 15.0;
      } else {
        normalPoints += 30.0;
      }
      factors.add('Room Temp High (${reading.normalTemperatureC.toStringAsFixed(1)}°C)');
    } else if (reading.normalTemperatureC < normalMin) {
      final diff = normalMin - reading.normalTemperatureC;
      if (diff <= 3.0) {
        normalPoints += 12.0;
      } else {
        normalPoints += 28.0;
      }
      factors.add('Room Temp Low (${reading.normalTemperatureC.toStringAsFixed(1)}°C)');
    }

    // 3. Humidity
    if (reading.coldHumidityPct > 68.0 || reading.coldHumidityPct < 32.0) {
      coldPoints += 10.0;
      factors.add('Cold Humidity (${reading.coldHumidityPct.toStringAsFixed(0)}%)');
    }
    if (reading.normalHumidityPct > 65.0 || reading.normalHumidityPct < 28.0) {
      normalPoints += 10.0;
      factors.add('Room Humidity (${reading.normalHumidityPct.toStringAsFixed(0)}%)');
    }

    // 4. Door Open (Reed Switches)
    if (reading.coldDoorOpen) {
      coldPoints += 25.0;
      factors.add('Cold Compartment Door Open');
    }
    if (reading.normalDoorOpen) {
      normalPoints += 15.0;
      factors.add('Room Compartment Door Open');
    }

    // 5. Light Sensor (LDR Module)
    if (reading.coldLightDetected) {
      coldPoints += 20.0;
      factors.add('Cold LDR: Light Exposure Detected');
    }
    if (reading.normalLightDetected) {
      normalPoints += 12.0;
      factors.add('Room LDR: Light Exposure Detected');
    }

    // 6. Sensor Health
    double hardwarePenalty = 0.0;
    if (reading.sensorHealth == SensorHealth.warning) {
      hardwarePenalty += 15.0;
      factors.add('Sensor Diagnostics Warning');
    } else if (reading.sensorHealth == SensorHealth.error) {
      hardwarePenalty += 45.0;
      factors.add('Sensor Hardware Error');
    }

    final totalCold = (coldPoints + hardwarePenalty).clamp(0.0, 100.0);
    final totalNormal = (normalPoints + hardwarePenalty).clamp(0.0, 100.0);
    final totalScore = max(totalCold, totalNormal).clamp(0.0, 100.0);

    RiskLevel getRiskLevel(double score) {
      if (score <= 25.0) return RiskLevel.low;
      if (score <= 60.0) return RiskLevel.medium;
      return RiskLevel.high;
    }

    HealthCondition getCondition(double score, SensorHealth health) {
      if (health == SensorHealth.error || score > 60.0) {
        return HealthCondition.critical;
      }
      if (score > 25.0 || health == SensorHealth.warning) {
        return HealthCondition.atRisk;
      }
      return HealthCondition.healthy;
    }

    return RiskAssessment(
      score: totalScore,
      level: getRiskLevel(totalScore),
      condition: getCondition(totalScore, reading.sensorHealth),
      coldScore: totalCold,
      coldLevel: getRiskLevel(totalCold),
      normalScore: totalNormal,
      normalLevel: getRiskLevel(totalNormal),
      riskFactors: factors,
    );
  }
}
