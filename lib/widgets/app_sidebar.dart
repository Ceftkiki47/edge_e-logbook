import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem(this.icon, this.label);
}

const _navItems = [
  _NavItem(Icons.dashboard_outlined,      'Dashboard'),
  _NavItem(Icons.inbox_outlined,          'Paket Masuk'),
  _NavItem(Icons.signal_cellular_alt,     'Kualitas Sinyal'),
  _NavItem(Icons.storage_outlined,        'Database Lokal'),
  _NavItem(Icons.dns_outlined,            'API Server'),
  _NavItem(Icons.cable_outlined,          'Koneksi Port'),
  _NavItem(Icons.settings_outlined,       'Konfigurasi'),
  _NavItem(Icons.notifications_outlined,  'Notifikasi'),
  _NavItem(Icons.tune_outlined,           'Pengaturan'),
];

class AppSidebar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  const AppSidebar({
    super.key,
    required this.selectedIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      color: AppColors.sidebarBg,
      child: Column(
        children: [
          // Logo
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
            ),
            child: Row(children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: AppColors.blue,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.router, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('LoRa Monitor',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      )),
                  Text('433 MHz Receiver',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.textMuted,
                      )),
                ],
              ),
            ]),
          ),

          // Nav items
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              itemCount: _navItems.length,
              itemBuilder: (_, i) {
                final item    = _navItems[i];
                final active  = i == selectedIndex;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: InkWell(
                    onTap: () => onSelect(i),
                    borderRadius: BorderRadius.circular(8),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                      decoration: BoxDecoration(
                        color: active ? AppColors.sidebarActive : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(children: [
                        Icon(item.icon,
                            size: 17,
                            color: active ? AppColors.blue : AppColors.textMuted),
                        const SizedBox(width: 10),
                        Text(item.label,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                              color: active ? AppColors.textPrimary : AppColors.textSecondary,
                            )),
                      ]),
                    ),
                  ),
                );
              },
            ),
          ),

          // Footer
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
            ),
            child: const Row(children: [
              Icon(Icons.lock_outline, size: 12, color: AppColors.textMuted),
              SizedBox(width: 6),
              Text('Read-Only Mode',
                  style: TextStyle(fontSize: 10.5, color: AppColors.textMuted)),
            ]),
          ),
        ],
      ),
    );
  }
}
