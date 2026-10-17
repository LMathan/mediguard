import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediguard/app.dart';

void main() {
  testWidgets('MediGuard App smoke test & Dashboard rendering', (
    WidgetTester tester,
  ) async {
    // Set surface size for mobile viewport
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(const ProviderScope(child: MediGuardApp()));

    await tester.pumpAndSettle();

    // Verify MediGuard App title and subtitle on Login Screen
    expect(find.text('MediGuard'), findsOneWidget);
    expect(find.text('Smart Medicine Storage & Monitoring'), findsOneWidget);

    // Verify Sign In form elements
    expect(find.text('Clinician Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Sign In to MediGuard'), findsOneWidget);
    expect(find.text('Register Here'), findsOneWidget);
  });
}
