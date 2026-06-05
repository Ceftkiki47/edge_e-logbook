import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/lora_record.dart';
import '../providers/lora_provider.dart';
import '../theme/app_colors.dart';
import 'confirm_dialog.dart';
import '../screens/packets_screen.dart';

class PacketLogCard extends StatelessWidget {
  const PacketLogCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 280,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border, width: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
          ),
          child: Row(children: [
            const Icon(Icons.terminal, size: 14, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            const Text('Log Paket Masuk',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                )),
            const Spacer(),
            Builder(
              builder: (ctx) => OutlinedButton(
                onPressed: () {
                  Navigator.push(
                    ctx,
                    MaterialPageRoute(builder: (_) => const PacketsScreen()),
                  );
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                  minimumSize: const Size(0, 24),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  side: const BorderSide(color: AppColors.border, width: 0.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                child: const Text('Selengkapnya', style: TextStyle(fontSize: 10.5, color: AppColors.textSecondary)),
              ),
            ),
            const SizedBox(width: 8),
            Consumer<LoraProvider>(
              builder: (ctx, prov, child) => Tooltip(
                message: 'Hapus log tampilan',
                child: InkWell(
                  onTap: prov.packets.isEmpty
                      ? null
                      : () async {
                          final ok = await showConfirmDialog(
                            ctx,
                            title: 'Hapus Log Tampilan',
                            message:
                                'Menghapus log dari tampilan ini. '
                                'Data yang sudah tersimpan di database tidak ikut terhapus.',
                            confirmLabel: 'Hapus Log',
                            level: ConfirmLevel.warning,
                            countLabel: '${prov.packets.length} baris log akan dihapus dari tampilan',
                          );
                          if (ok) prov.clearBuffer();
                        },
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.delete_outline,
                      size: 14,
                      color: prov.packets.isEmpty
                          ? AppColors.textMuted.withValues(alpha: 0.4)
                          : AppColors.textMuted,
                    ),
                  ),
                ),
              ),
            ),
          ]),
        ),
        Expanded(
          child: Consumer<LoraProvider>(
            builder: (_, prov, __) {
              if (prov.packets.isEmpty) {
                return const Center(
                  child: Text('Menunggu data...',
                      style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                );
              }
              final fmt = DateFormat('HH:mm:ss.SSS');
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                itemCount: prov.packets.length,
                itemBuilder: (_, i) => _LogRow(record: prov.packets[i], fmt: fmt),
              );
            },
          ),
        ),
      ]),
    );
  }
}

class _LogRow extends StatelessWidget {
  final LoraRecord record;
  final DateFormat fmt;
  const _LogRow({required this.record, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final (tagBg, tagFg, tagLabel) = switch (record.packetType) {
      'rx'    => (AppColors.tagRxBg,  AppColors.tagRxText,  'RX'),
      'error' => (AppColors.tagErrBg, AppColors.tagErrText, 'ERR'),
      _       => (AppColors.tagSysBg, AppColors.tagSysText, 'SYS'),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 90,
          child: Text(fmt.format(record.receivedAt),
              style: const TextStyle(
                fontSize: 10.5,
                color: AppColors.textMuted,
                fontFamily: 'monospace',
              )),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          margin: const EdgeInsets.only(right: 8, top: 1),
          decoration: BoxDecoration(color: tagBg, borderRadius: BorderRadius.circular(99)),
          child: Text(tagLabel,
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: tagFg)),
        ),
        Expanded(
          child: Text(
            record.parsedData ?? record.rawData,
            style: const TextStyle(
              fontSize: 11.5,
              color: AppColors.textPrimary,
              fontFamily: 'monospace',
            ),
          ),
        ),
        if (record.rssi != null)
          Text('${record.rssi}dBm',
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.blue,
                fontFamily: 'monospace',
              )),
      ]),
    );
  }
}
