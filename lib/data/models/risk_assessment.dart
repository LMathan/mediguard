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

class DoorAndLightExposureTracker {
  static final DoorAndLightExposureTracker instance =
      DoorAndLightExposureTracker._internal();

  DoorAndLightExposureTracker._internal();

  DateTime? coldDoorOpenedAt;
  DateTime? normalDoorOpenedAt;
  DateTime? coldLightDetectedAt;
  DateTime? normalLightDetectedAt;

  void record({
    required bool coldDoorOpen,
    required bool normalDoorOpen,
    required bool coldLightDetected,
    required bool normalLightDetected,
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();

    if (coldDoorOpen) {
      coldDoorOpenedAt ??= current;
    } else {
      coldDoorOpenedAt = null;
    }

    if (normalDoorOpen) {
      normalDoorOpenedAt ??= current;
    } else {
      normalDoorOpenedAt = null;
    }

    if (coldLightDetected) {
      coldLightDetectedAt ??= current;
    } else {
      coldLightDetectedAt = null;
    }

    if (normalLightDetected) {
      normalLightDetectedAt ??= current;
    } else {
      normalLightDetectedAt = null;
    }
  }

  bool isColdDoorExceeded({DateTime? now, int thresholdSeconds = 60}) {
    if (coldDoorOpenedAt == null) return false;
    return (now ?? DateTime.now()).difference(coldDoorOpenedAt!).inSeconds >=
        thresholdSeconds;
  }

  bool isNormalDoorExceeded({DateTime? now, int thresholdSeconds = 60}) {
    if (normalDoorOpenedAt == null) return false;
    return (now ?? DateTime.now()).difference(normalDoorOpenedAt!).inSeconds >=
        thresholdSeconds;
  }

  bool isColdLightExceeded({DateTime? now, int thresholdSeconds = 60}) {
    if (coldLightDetectedAt == null) return false;
    return (now ?? DateTime.now())
            .difference(coldLightDetectedAt!)
            .inSeconds >=
        thresholdSeconds;
  }

  bool isNormalLightExceeded({DateTime? now, int thresholdSeconds = 60}) {
    if (normalLightDetectedAt == null) return false;
    return (now ?? DateTime.now())
            .difference(normalLightDetectedAt!)
            .inSeconds >=
        thresholdSeconds;
  }

  void reset() {
    coldDoorOpenedAt = null;
    normalDoorOpenedAt = null;
    coldLightDetectedAt = null;
    normalLightDetectedAt = null;
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
    DoorAndLightExposureTracker? tracker,
    DateTime? now,
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

    // If telemetry is older than 60s (device offline mark as high risk)
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

    final effectiveTracker = tracker ?? DoorAndLightExposureTracker.instance;
    final evalTime = now ?? DateTime.now();

    effectiveTracker.record(
      coldDoorOpen: reading.coldDoorOpen,
      normalDoorOpen: reading.normalDoorOpen,
      coldLightDetected: reading.isColdExposed,
      normalLightDetected: reading.isNormalExposed,
      now: evalTime,
    );

    // Prototype thresholds:
    // Cold storage is normal up to 20°C. Points calculated above 20°C.
    // Room storage is normal up to 28°C. Points calculated above 28°C.
    // Cold & room humidity normal up to 70%. Points calculated above 70%.
    const prototypeColdMax = 20.0;
    const prototypeNormalMax = 28.0;
    const prototypeHumidityMax = 70.0;

    double coldPoints = 0.0;
    double normalPoints = 0.0;
    final factors = <String>[];

    // 1. Cold Zone Temp (Normal up to 20°C in prototype)
    if (reading.coldTemperatureC > prototypeColdMax) {
      final diff = reading.coldTemperatureC - prototypeColdMax;
      if (diff <= 3.0) {
        coldPoints += 20.0;
      } else if (diff <= 6.0) {
        coldPoints += 38.0;
      } else {
        coldPoints += 55.0;
      }
      factors.add(
        'Cold Temp High (${reading.coldTemperatureC.toStringAsFixed(1)}°C > 20°C)',
      );
    } else if (reading.coldTemperatureC < 0.0) {
      coldPoints += 30.0;
      factors.add(
        'Cold Temp Sub-zero Freezing (${reading.coldTemperatureC.toStringAsFixed(1)}°C)',
      );
    }

    // 2. Normal Zone Temp (Normal up to 28°C in prototype)
    if (reading.normalTemperatureC > prototypeNormalMax) {
      final diff = reading.normalTemperatureC - prototypeNormalMax;
      if (diff <= 3.0) {
        normalPoints += 15.0;
      } else {
        normalPoints += 30.0;
      }
      factors.add(
        'Room Temp High (${reading.normalTemperatureC.toStringAsFixed(1)}°C > 28°C)',
      );
    } else if (reading.normalTemperatureC < 10.0) {
      normalPoints += 20.0;
      factors.add(
        'Room Temp Low (${reading.normalTemperatureC.toStringAsFixed(1)}°C)',
      );
    }

    // 3. Humidity (Normal up to 70% in prototype)
    if (reading.coldHumidityPct > prototypeHumidityMax) {
      coldPoints += 10.0;
      factors.add(
        'Cold Humidity (${reading.coldHumidityPct.toStringAsFixed(0)}% > 70%)',
      );
    }
    if (reading.normalHumidityPct > prototypeHumidityMax) {
      normalPoints += 10.0;
      factors.add(
        'Room Humidity (${reading.normalHumidityPct.toStringAsFixed(0)}% > 70%)',
      );
    }

    // 4. Door Open (Reed Switches: risk only if open > 1 minute)
    if (reading.coldDoorOpen &&
        effectiveTracker.isColdDoorExceeded(now: evalTime)) {
      coldPoints += 25.0;
      factors.add('Cold Door Open (>1 min)');
    }
    if (reading.normalDoorOpen &&
        effectiveTracker.isNormalDoorExceeded(now: evalTime)) {
      normalPoints += 15.0;
      factors.add('Room Door Open (>1 min)');
    }

    // 5. Light Sensor (LDR Module: risk only if exposed > 1 minute, where false = exposed)
    if (reading.isColdExposed &&
        effectiveTracker.isColdLightExceeded(now: evalTime)) {
      coldPoints += 20.0;
      factors.add('Cold LDR: Light Exposed (>1 min)');
    }
    if (reading.isNormalExposed &&
        effectiveTracker.isNormalLightExceeded(now: evalTime)) {
      normalPoints += 12.0;
      factors.add('Room LDR: Light Exposed (>1 min)');
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
