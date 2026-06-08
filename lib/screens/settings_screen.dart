import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/lora_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/app_topbar.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final prov = context.watch<LoraProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppTopbar(title: 'Pengaturan Aplikasi'),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader(Icons.color_lens, 'Tampilan Aplikasi'),
                _buildCard([
                  SwitchListTile(
                    title: Text('Mode Gelap (Dark Mode)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    subtitle: Text('Gunakan tema warna gelap untuk kenyamanan mata', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    value: prov.isDarkMode,
                    activeColor: AppColors.blue,
                    onChanged: (val) => prov.toggleTheme(val),
                  ),
                ]),
                SizedBox(height: 24),

                _buildSectionHeader(Icons.storage, 'Database & Penyimpanan Lokal'),
                _buildCard([
                  SwitchListTile(
                    title: Text('Auto-Save Data ke SQLite', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    subtitle: Text('Simpan otomatis setiap paket LoRa yang masuk', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    value: prov.autoSave,
                    activeColor: AppColors.blue,
                    onChanged: (val) => prov.setAutoSave(val),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12, left: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.blue),
          SizedBox(width: 8),
          Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        ],
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}
