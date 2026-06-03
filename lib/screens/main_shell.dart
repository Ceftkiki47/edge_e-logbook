import 'package:flutter/material.dart';
import '../screens/dashboard_screen.dart';
import '../screens/packets_screen.dart';
import '../screens/database_screen.dart';
import '../screens/api_screen.dart';
import '../screens/port_screen.dart';
import '../screens/placeholder_screen.dart';
import '../widgets/app_sidebar.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;

  static const _screens = [
    DashboardScreen(),       // 0
    PacketsScreen(),         // 1
    PlaceholderScreen(       // 2
      title: 'Kualitas Sinyal',
      icon: Icons.signal_cellular_alt,
      description: 'Grafik kualitas sinyal RSSI & SNR real-time.',
    ),
    DatabaseScreen(),        // 3
    ApiScreen(),             // 4
    PortScreen(),            // 5
    PlaceholderScreen(       // 6
      title: 'Konfigurasi',
      icon: Icons.settings_outlined,
      description: 'Pengaturan parameter LoRa (SF, BW, CR).',
    ),
    PlaceholderScreen(       // 7
      title: 'Notifikasi',
      icon: Icons.notifications_outlined,
      description: 'Aturan notifikasi berdasarkan nilai sensor.',
    ),
    PlaceholderScreen(       // 8
      title: 'Pengaturan',
      icon: Icons.tune_outlined,
      description: 'Preferensi tampilan dan aplikasi.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(children: [
        AppSidebar(
          selectedIndex: _selectedIndex,
          onSelect: (i) => setState(() => _selectedIndex = i),
        ),
        Expanded(child: _screens[_selectedIndex]),
      ]),
    );
  }
}
