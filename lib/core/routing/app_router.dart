import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/alerts/alerts_screen.dart';
import '../../features/auth/forgot_password_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/register_screen.dart';
import '../../features/auth/verify_email_screen.dart';
import '../../features/history/history_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/inventory/add_edit_medicine_screen.dart';
import '../../features/inventory/inventory_screen.dart';
import '../../features/inventory/medicine_detail_screen.dart';
import '../../features/inventory/transaction_flow_screen.dart';
import '../../features/monitoring/monitoring_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/settings/simulation_controls_screen.dart';
import '../../features/settings/threshold_settings_screen.dart';
import '../../shared/providers/app_providers.dart';
import '../../shared/widgets/app_scaffold_with_nav_bar.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'rootNav');
final _sectionHomeKey = GlobalKey<NavigatorState>(debugLabel: 'sectionHome');
final _sectionInventoryKey = GlobalKey<NavigatorState>(
  debugLabel: 'sectionInventory',
);
final _sectionMonitoringKey = GlobalKey<NavigatorState>(
  debugLabel: 'sectionMonitoring',
);
final _sectionHistoryKey = GlobalKey<NavigatorState>(
  debugLabel: 'sectionHistory',
);

final appRouterProvider = Provider<GoRouter>((ref) {
  final supabase = ref.watch(supabaseServiceProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: supabase.isAuthenticated ? '/home' : '/login',
    refreshListenable: supabase,
    redirect: (context, state) {
      final isAuth = supabase.isAuthenticated;
      final isLoggingIn =
          state.matchedLocation == '/login' ||
          state.matchedLocation == '/register' ||
          state.matchedLocation == '/forgot-password' ||
          state.matchedLocation == '/verify-email';

      if (!isAuth && !isLoggingIn) {
        return '/login';
      }
      if (isAuth && isLoggingIn) {
        return '/home';
      }
      return null;
    },
    routes: [
      // Auth Routes
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/verify-email',
        builder: (context, state) {
          final email =
              state.uri.queryParameters['email'] ?? state.extra as String?;
          return VerifyEmailScreen(email: email);
        },
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),

      // Standalone Fullscreen Detail & Settings Routes
      GoRoute(
        path: '/alerts',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AlertsScreen(),
      ),
      GoRoute(
        path: '/settings',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/settings/thresholds',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ThresholdSettingsScreen(),
      ),
      GoRoute(
        path: '/settings/simulation-controls',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SimulationControlsScreen(),
      ),
      GoRoute(
        path: '/inventory/add',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AddEditMedicineScreen(),
      ),
      GoRoute(
        path: '/inventory/edit/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id'];
          return AddEditMedicineScreen(medicineId: id);
        },
      ),
      GoRoute(
        path: '/inventory/detail/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return MedicineDetailScreen(medicineId: id);
        },
      ),
      GoRoute(
        path: '/inventory/transaction/flow',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final medId = state.uri.queryParameters['medId'];
          final action = state.uri.queryParameters['action'];
          return TransactionFlowScreen(
            medicineId: medId,
            initialAction: action,
          );
        },
      ),
      GoRoute(
        path: '/inventory/transaction/scan',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) =>
            const TransactionFlowScreen(isScanMode: true),
      ),

      // Stateful Shell Route for Bottom Navigation Tabs
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppScaffoldWithNavBar(navigationShell: navigationShell);
        },
        branches: [
          // Branch 0: Home
          StatefulShellBranch(
            navigatorKey: _sectionHomeKey,
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          // Branch 1: Inventory
          StatefulShellBranch(
            navigatorKey: _sectionInventoryKey,
            routes: [
              GoRoute(
                path: '/inventory',
                builder: (context, state) => const InventoryScreen(),
              ),
            ],
          ),
          // Branch 2: Monitoring
          StatefulShellBranch(
            navigatorKey: _sectionMonitoringKey,
            routes: [
              GoRoute(
                path: '/monitoring',
                builder: (context, state) => const MonitoringScreen(),
              ),
            ],
          ),
          // Branch 3: History
          StatefulShellBranch(
            navigatorKey: _sectionHistoryKey,
            routes: [
              GoRoute(
                path: '/history',
                builder: (context, state) => const HistoryScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
