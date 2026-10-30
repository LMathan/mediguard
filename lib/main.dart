import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/config/supabase_config.dart';
import 'data/services/notification_service.dart';
import 'data/services/onesignal_service.dart';
import 'data/services/supabase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Print startup environment status
  SupabaseConfig.printStatus();

  // Initialize Local Notifications
  await NotificationService().initialize();

  // Initialize OneSignal Push Notifications
  await OneSignalService().initialize();

  // Initialize Supabase if configured with valid credentials
  await SupabaseService().initialize();

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const ProviderScope(child: MediGuardApp()));
}
