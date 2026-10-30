import 'package:flutter_test/flutter_test.dart';
import 'package:mediguard/data/models/alert_item.dart';
import 'package:mediguard/data/repositories/alert_repository.dart';

void main() {
  group('Alert Deduplication and Resolution Tests', () {
    late AlertRepository alertRepo;

    setUp(() {
      alertRepo = AlertRepository();
    });

    test(
      'Creating an alert when one already active suppresses duplicate',
      () async {
        final initialAlert = AlertItem(
          id: 'dup-1',
          type: AlertType.highTemp,
          title: 'High Temp Detected',
          message: 'Cold temp rose to 9.2°C',
          severity: AlertSeverity.critical,
          status: AlertStatus.active,
          createdAt: DateTime.now(),
        );

        final createdFirst = await alertRepo.createAlertIfNew(initialAlert);
        expect(createdFirst, isNotNull);

        // Attempt second alert of same type while first is active
        final secondAlert = AlertItem(
          id: 'dup-2',
          type: AlertType.highTemp,
          title: 'High Temp Detected Tick 2',
          message: 'Cold temp rose to 9.4°C',
          severity: AlertSeverity.critical,
          status: AlertStatus.active,
          createdAt: DateTime.now().add(const Duration(seconds: 3)),
        );

        final createdSecond = await alertRepo.createAlertIfNew(secondAlert);
        expect(
          createdSecond,
          isNull,
        ); // Deduplication successfully suppressed duplicate!
      },
    );

    test('Acknowledging an alert updates status', () async {
      final created = await alertRepo.createAlertIfNew(AlertItem(
        id: 'test-ack-1',
        type: AlertType.highTemp,
        title: 'Temp Warning',
        message: 'Normal temp reading out of range',
        severity: AlertSeverity.warning,
        status: AlertStatus.active,
        createdAt: DateTime.now(),
      ));
      expect(created, isNotNull);

      await alertRepo.acknowledgeAlert(created!.id);

      final updatedAlerts = await alertRepo.getAlerts();
      final updated = updatedAlerts.firstWhere((a) => a.id == created.id);
      expect(updated.status, equals(AlertStatus.acknowledged));
      expect(updated.acknowledgedAt, isNotNull);
    });

    test('Resolving an alert updates status to resolved', () async {
      final created = await alertRepo.createAlertIfNew(AlertItem(
        id: 'test-res-1',
        type: AlertType.doorLeftOpen,
        title: 'Door Open Warning',
        message: 'Cold door open for over 60 seconds',
        severity: AlertSeverity.warning,
        status: AlertStatus.active,
        createdAt: DateTime.now(),
      ));
      expect(created, isNotNull);

      await alertRepo.resolveAlert(created!.id);

      final updatedAlerts = await alertRepo.getAlerts();
      final resolved = updatedAlerts.firstWhere((a) => a.id == created.id);
      expect(resolved.status, equals(AlertStatus.resolved));
      expect(resolved.resolvedAt, isNotNull);
    });

    test('AlertType.fromString maps backend alert aliases correctly', () {
      expect(AlertType.fromString('cold_temp_high'), AlertType.highTemp);
      expect(AlertType.fromString('temperature_critical'), AlertType.highTemp);
      expect(AlertType.fromString('cold_temp_low'), AlertType.lowTemp);
      expect(AlertType.fromString('door_open'), AlertType.doorLeftOpen);
      expect(AlertType.fromString('sensor_fault'), AlertType.sensorError);
    });
  });
}
