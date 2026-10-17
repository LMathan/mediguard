import '../models/sensor_reading.dart';

abstract class SensorDataSource {
  /// Stream of incoming sensor readings
  Stream<SensorReading> get readingStream;

  /// The most recent sensor reading
  SensorReading get latestReading;

  /// Whether this data source is currently simulated
  bool get isSimulated;

  /// Initialize connections or simulation timers
  Future<void> initialize();

  /// Clean up timers, streams, or network subscriptions
  Future<void> dispose();
}
