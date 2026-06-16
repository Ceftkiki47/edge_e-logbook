import 'package:flutter/material.dart';
import 'dashboard_screen.dart';
import 'packets_screen.dart';
import 'database_screen.dart';
import 'api_screen.dart';
import 'port_screen.dart';
import 'settings_screen.dart';
import '../widgets/app_sidebar.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;

  late final List<Widget> _screens = [
    DashboardScreen(onNavigateToPackets: () {
      setState(() => _selectedIndex = 1);
    }),                      // 0
    const PacketsScreen(),         // 1
    const DatabaseScreen(),        // 2
    const ApiScreen(),             // 3
    const PortScreen(),            // 4
    const SettingsScreen(),        // 5
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(children: [
        AppSidebar(
          selectedIndex: _selectedIndex,
          onSelect: (i) => setState(() => _selectedIndex = i),
        ),
        Expanded(
          child: IndexedStack(
            index: _selectedIndex,
            children: _screens,
          ),
        ),
      ]),
    );
  }
}
