import 'dart:async';
import 'dart:math';
import '../models/sensor_reading.dart';
import 'sensor_data_source.dart';

enum SimulationScenario {
  normal,
  warning,
  critical,
  doorOpen,
  sensorError,
  staleData,
  offline,
  recovery;

  String get label {
    switch (this) {
      case SimulationScenario.normal:
        return 'Normal Baseline (4.2°C / 21.5°C)';
      case SimulationScenario.warning:
        return 'Warning Condition (Cold 8.8°C)';
      case SimulationScenario.critical:
        return 'Critical Condition (Cold 14.5°C / Normal 33°C)';
      case SimulationScenario.doorOpen:
        return 'Cold Door Open Event (Light Detected)';
      case SimulationScenario.sensorError:
        return 'Sensor Checksum Error Fault';
      case SimulationScenario.staleData:
        return 'Stale Telemetry (>60s Inactive)';
      case SimulationScenario.offline:
        return 'Device Completely Offline';
      case SimulationScenario.recovery:
        return 'Recovery to Nominal Temperature';
    }
  }
}

class DemoSensorService implements SensorDataSource {
  final _random = Random();
  final StreamController<SensorReading> _streamController =
      StreamController<SensorReading>.broadcast();
  Timer? _ticker;

  SimulationScenario _currentScenario = SimulationScenario.normal;
  SimulationScenario get currentScenario => _currentScenario;

  int _simulationIntervalSeconds = 3;
  bool _isOffline = false;
  bool get isOffline => _isOffline;

  late SensorReading _latestReading;

  DemoSensorService({int intervalSeconds = 3})
    : _simulationIntervalSeconds = intervalSeconds {
    _latestReading = _generateReading(DateTime.now());
  }

  @override
  Stream<SensorReading> get readingStream => _streamController.stream;

  @override
  SensorReading get latestReading => _latestReading;

  @override
  bool get isSimulated => true;

  @override
  Future<void> initialize() async {
    _startTimer();
    _streamController.add(_latestReading);
  }

  void _startTimer() {
    _ticker?.cancel();
    _ticker = Timer.periodic(Duration(seconds: _simulationIntervalSeconds), (
      _,
    ) {
      _onTick();
    });
  }

  void updateInterval(int seconds) {
    if (seconds > 0 && seconds != _simulationIntervalSeconds) {
      _simulationIntervalSeconds = seconds;
      _startTimer();
    }
  }

  void setScenario(SimulationScenario scenario) {
    _currentScenario = scenario;
    _isOffline = (scenario == SimulationScenario.offline);
    _onTick();
  }

  void _onTick() {
    if (_streamController.isClosed) return;

    if (_currentScenario == SimulationScenario.offline) {
      // Offline scenario: do not emit fresh telemetry or emit marked offline
      return;
    }

    if (_currentScenario == SimulationScenario.staleData) {
      // Keep emitting with a fixed old timestamp (>120s ago)
      _latestReading = _latestReading.copyWith(
        recordedAt: DateTime.now().subtract(const Duration(minutes: 3)),
      );
      _streamController.add(_latestReading);
      return;
    }

    final newReading = _generateReading(DateTime.now());
    _latestReading = newReading;
    _streamController.add(newReading);
  }

  SensorReading _generateReading(DateTime timestamp) {
    // Small random jitter
    final jitterTemp = (_random.nextDouble() - 0.5) * 0.4;
    final jitterHum = (_random.nextDouble() - 0.5) * 1.0;

    switch (_currentScenario) {
      case SimulationScenario.normal:
        return SensorReading(
          normalTemperatureC: 21.5 + jitterTemp,
          normalHumidityPct: 48.0 + jitterHum,
          coldTemperatureC: 4.5 + jitterTemp,
          coldHumidityPct: 52.0 + jitterHum,
          normalDoorOpen: false,
          coldDoorOpen: false,
          normalLightDetected: false,
          coldLightDetected: false,
          coolingActive: true,
          normalFanActive: true,
          sensorHealth: SensorHealth.healthy,
          dataSource: DataSourceType.simulated,
          recordedAt: timestamp,
        );

      case SimulationScenario.warning:
        // Cold temp approaching/above 8°C or normal temp high
        return SensorReading(
          normalTemperatureC: 26.2 + jitterTemp,
          normalHumidityPct: 62.0 + jitterHum,
          coldTemperatureC: 8.8 + jitterTemp,
          coldHumidityPct: 68.0 + jitterHum,
          normalDoorOpen: false,
          coldDoorOpen: false,
          normalLightDetected: false,
          coldLightDetected: false,
          coolingActive: true,
          normalFanActive: true,
          sensorHealth: SensorHealth.warning,
          dataSource: DataSourceType.simulated,
          recordedAt: timestamp,
        );

      case SimulationScenario.critical:
        // Cold temp way above safe zone (e.g. 14.5°C)
        return SensorReading(
          normalTemperatureC: 33.5 + jitterTemp,
          normalHumidityPct: 75.0 + jitterHum,
          coldTemperatureC: 14.2 + jitterTemp,
          coldHumidityPct: 74.0 + jitterHum,
          normalDoorOpen: false,
          coldDoorOpen: false,
          normalLightDetected: false,
          coldLightDetected: false,
          coolingActive: false, // Cooling failed
          normalFanActive: true,
          sensorHealth: SensorHealth.error,
          dataSource: DataSourceType.simulated,
          recordedAt: timestamp,
        );

      case SimulationScenario.doorOpen:
        return SensorReading(
          normalTemperatureC: 22.0 + jitterTemp,
          normalHumidityPct: 50.0 + jitterHum,
          coldTemperatureC: 9.4 + jitterTemp, // Warming up due to open door
          coldHumidityPct: 60.0 + jitterHum,
          normalDoorOpen: false,
          coldDoorOpen: true, // Cold door is open!
          normalLightDetected: false,
          coldLightDetected: true, // Light detected inside!
          coolingActive: true,
          normalFanActive: true,
          sensorHealth: SensorHealth.healthy,
          dataSource: DataSourceType.simulated,
          recordedAt: timestamp,
        );

      case SimulationScenario.sensorError:
        return SensorReading(
          normalTemperatureC: 21.0 + jitterTemp,
          normalHumidityPct: 49.0 + jitterHum,
          coldTemperatureC: -99.9, // Error sentinel
          coldHumidityPct: 0.0,
          normalDoorOpen: false,
          coldDoorOpen: false,
          normalLightDetected: false,
          coldLightDetected: false,
          coolingActive: false,
          normalFanActive: false,
          sensorHealth: SensorHealth.error,
          dataSource: DataSourceType.simulated,
          recordedAt: timestamp,
        );

      case SimulationScenario.recovery:
        return SensorReading(
          normalTemperatureC: 21.8 + jitterTemp,
          normalHumidityPct: 49.0 + jitterHum,
          coldTemperatureC: 4.8 + jitterTemp, // Back to safe nominal
          coldHumidityPct: 50.0 + jitterHum,
          normalDoorOpen: false,
          coldDoorOpen: false,
          normalLightDetected: false,
          coldLightDetected: false,
          coolingActive: true,
          normalFanActive: true,
          sensorHealth: SensorHealth.healthy,
          dataSource: DataSourceType.simulated,
          recordedAt: timestamp,
        );

      case SimulationScenario.staleData:
      case SimulationScenario.offline:
        return _latestReading;
    }
  }

  /// Generates deterministic historical readings for charts (1h, 6h, 24h, 7d)
  List<SensorReading> generateSampleHistory({
    Duration span = const Duration(hours: 24),
    int pointCount = 30,
  }) {
    final List<SensorReading> list = [];
    final now = DateTime.now();
    final interval = span.inSeconds ~/ pointCount;

    for (int i = pointCount; i >= 0; i--) {
      final pointTime = now.subtract(Duration(seconds: i * interval));
      final progress = (pointCount - i) / pointCount;
      // Realistic sinusoidal variation
      final normalTemp =
          21.0 +
          sin(progress * 2 * pi) * 1.8 +
          (_random.nextDouble() - 0.5) * 0.4;
      final coldTemp =
          4.3 +
          sin((progress + 0.2) * 2 * pi) * 0.8 +
          (_random.nextDouble() - 0.5) * 0.3;
      final normalHum = 48.0 + cos(progress * 2 * pi) * 5.0;
      final coldHum = 52.0 + sin(progress * pi) * 4.0;

      list.add(
        SensorReading(
          normalTemperatureC: normalTemp,
          normalHumidityPct: normalHum,
          coldTemperatureC: coldTemp,
          coldHumidityPct: coldHum,
          normalDoorOpen: false,
          coldDoorOpen: false,
          normalLightDetected: false,
          coldLightDetected: false,
          coolingActive: true,
          normalFanActive: true,
          sensorHealth: SensorHealth.healthy,
          dataSource: DataSourceType.simulated,
          recordedAt: pointTime,
        ),
      );
    }
    return list;
  }

  @override
  Future<void> dispose() async {
    _ticker?.cancel();
    await _streamController.close();
  }
}
