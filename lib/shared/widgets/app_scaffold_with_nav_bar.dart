import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../providers/app_providers.dart';
import 'demo_mode_banner.dart';
import 'notification_permission_sheet.dart';

class AppScaffoldWithNavBar extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;

  const AppScaffoldWithNavBar({super.key, required this.navigationShell});

  @override
  ConsumerState<AppScaffoldWithNavBar> createState() =>
      _AppScaffoldWithNavBarState();
}

class _AppScaffoldWithNavBarState extends ConsumerState<AppScaffoldWithNavBar>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Check notification permission whenever screen mounts
      _checkNotificationPermission();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkNotificationPermission();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _checkNotificationPermission() {
    if (!mounted) return;
    NotificationPermissionSheet.showIfNeeded(context);
  }

  void _onItemTapped(int index) {
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeAlerts = ref.watch(activeAlertsProvider);
    final isSimulated = ref.watch(sensorDataSourceProvider).isSimulated;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.medical_services_outlined,
                size: 18,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MediGuard',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  'Smart Storage System',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Alerts Badge Button
          IconButton(
            tooltip: 'Active Alerts',
            icon: Badge(
              isLabelVisible: activeAlerts.isNotEmpty,
              label: Text('${activeAlerts.length}'),
              backgroundColor: AppColors.statusCritical,
              child: const Icon(Icons.notifications_outlined),
            ),
            onPressed: () {
              context.push('/alerts');
            },
          ),
          // Settings / Profile Button
          IconButton(
            tooltip: 'Settings & Device',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              context.push('/settings');
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (isSimulated) const DemoModeBanner(),
            Expanded(child: widget.navigationShell),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: widget.navigationShell.currentIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2_outlined),
            activeIcon: Icon(Icons.inventory_2_rounded),
            label: 'Inventory',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.show_chart_rounded),
            activeIcon: Icon(Icons.stacked_line_chart_rounded),
            label: 'Monitoring',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history_rounded),
            activeIcon: Icon(Icons.manage_history_rounded),
            label: 'History',
          ),
        ],
      ),
    );
  }
}
