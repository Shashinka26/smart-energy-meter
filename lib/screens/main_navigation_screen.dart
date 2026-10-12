import 'package:flutter/material.dart';

import '../services/usage_notification_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_snackbar.dart';
import 'ai_screen.dart';
import 'analytics_screen.dart';
import 'dashboard_screen.dart';
import 'profile_screen.dart';
import 'schedule_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key, required this.isOwner});

  final bool isOwner;

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();

    _pages = [
      DashboardScreen(isOwner: widget.isOwner),
      const AnalyticsScreen(),
      const AiScreen(),
      ScheduleScreen(isOwner: widget.isOwner),
      ProfileScreen(isOwner: widget.isOwner),
    ];

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkMonthlyUsageAlert();
    });
  }

  Future<void> _checkMonthlyUsageAlert() async {
    final message = await UsageNotificationService.instance.checkAndNotify();
    if (!mounted || message == null) {
      return;
    }

    AppSnackbar.show(
      context,
      message: message,
      duration: const Duration(seconds: 6),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: IndexedStack(
          key: ValueKey(_selectedIndex),
          index: _selectedIndex,
          children: _pages,
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border(0.06))),
        ),
        child: NavigationBar(
          selectedIndex: _selectedIndex,
          height: 68,
          onDestinationSelected: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard_rounded),
              label: 'Dashboard',
            ),
            NavigationDestination(
              icon: Icon(Icons.analytics_outlined),
              selectedIcon: Icon(Icons.analytics_rounded),
              label: 'Analytics',
            ),
            NavigationDestination(
              icon: Icon(Icons.psychology_outlined),
              selectedIcon: Icon(Icons.psychology_rounded),
              label: 'AI',
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined),
              selectedIcon: Icon(Icons.calendar_month_rounded),
              label: 'Schedule',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
