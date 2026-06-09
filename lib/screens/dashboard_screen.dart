import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/lora_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/app_topbar.dart';
import '../widgets/status_card.dart';
import '../widgets/packet_log_card.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      const AppTopbar(title: 'Dashboard'),
      Expanded(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(children: [
            // Row 1: Status + Sinyal
            const IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: StatusCard()),
                  SizedBox(width: 14),
                  Expanded(child: SignalCard()),
                ],
              ),
            ),
            SizedBox(height: 14),

            // Row 2: Error + 4 mini stats
            Consumer<LoraProvider>(
              builder: (context, prov, child) => Row(children: [
                Expanded(child: ErrorCountCard()),
                SizedBox(width: 14),
                Expanded(
                  child: MiniStatCard(
                    iconBg: AppColors.blueBg,
                    iconColor: AppColors.blue,
                    icon: Icons.arrow_downward,
                    label: 'Total RX',
                    value: '${prov.rxCount}',
                    sub: 'Paket diterima',
                  ),
                ),
                SizedBox(width: 14),
                Expanded(
                  child: MiniStatCard(
                    iconBg: AppColors.onlineBg,
                    iconColor: AppColors.onlineSub,
                    icon: Icons.show_chart,
                    label: 'Sesi Ini',
                    value: '${prov.rxCount}',
                    sub: 'Live',
                  ),
                ),
                SizedBox(width: 14),
                Expanded(
                  child: MiniStatCard(
                    iconBg: AppColors.amberBg,
                    iconColor: AppColors.amber,
                    icon: Icons.radio,
                    label: 'Frekuensi',
                    value: '433',
                    sub: 'MHz',
                  ),
                ),
                SizedBox(width: 14),
                Expanded(
                  child: MiniStatCard(
                    iconBg: AppColors.purpleBg,
                    iconColor: AppColors.purple,
                    icon: Icons.cell_tower,
                    label: 'Spreading',
                    value: 'SF7',
                    sub: 'Factor',
                  ),
                ),
              ]),
            ),
            SizedBox(height: 14),

            // Row 3: Log paket
            const PacketLogCard(),
            SizedBox(height: 14),

            // Row 4: Footer info
            Container(
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: AppColors.border, width: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                Icon(Icons.info_outline, size: 14, color: AppColors.textMuted),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Aplikasi ini menerima dan mengirimkan data LoRa dari ESP32 via USB Serial. ',
                    style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ),
    ]);
  }
}
