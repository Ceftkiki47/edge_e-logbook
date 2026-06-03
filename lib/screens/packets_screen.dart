import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/lora_record.dart';
import '../providers/lora_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/app_topbar.dart';
import '../widgets/confirm_dialog.dart';

class PacketsScreen extends StatelessWidget {
  const PacketsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      const AppTopbar(title: 'Paket Masuk'),
      Expanded(
        child: Consumer<LoraProvider>(
          builder: (_, prov, __) => Column(children: [
            _toolbar(prov),
            Expanded(child: _packetList(context, prov.packets)),
          ]),
        ),
      ),
    ]);
  }

  Widget _toolbar(LoraProvider prov) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        color: AppColors.surface,
        child: Row(children: [
          Text('${prov.rxCount} paket diterima',
              style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: AppColors.blueBg, borderRadius: BorderRadius.circular(99)),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.lock_outline, size: 11, color: AppColors.blue),
              SizedBox(width: 4),
              Text('Read-Only',
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.blue)),
            ]),
          ),
          const Spacer(),
          Builder(
            builder: (ctx) => OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: prov.packets.isEmpty
                    ? AppColors.textMuted
                    : AppColors.danger,
                side: BorderSide(
                  color: prov.packets.isEmpty ? AppColors.border : AppColors.danger,
                  width: 0.5,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: prov.packets.isEmpty
                  ? null
                  : () async {
                      final ok = await showConfirmDialog(
                        ctx,
                        title: 'Hapus Buffer Tampilan',
                        message:
                            'Menghapus semua data dari tampilan sesi ini. '
                            'Data yang sudah tersimpan di database tidak terpengaruh.',
                        confirmLabel: 'Hapus Buffer',
                        level: ConfirmLevel.warning,
                        countLabel: '${prov.packets.length} paket akan dihapus dari tampilan',
                      );
                      if (ok) prov.clearBuffer();
                    },
              icon: const Icon(Icons.delete_outline, size: 14),
              label: const Text('Hapus Buffer', style: TextStyle(fontSize: 11)),
            ),
          ),
        ]),
      );

  Widget _packetList(BuildContext context, List<LoraRecord> records) {
    if (records.isEmpty) {
      return const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.inbox_outlined, size: 40, color: AppColors.textMuted),
          SizedBox(height: 12),
          Text('Belum ada paket masuk',
              style: TextStyle(fontSize: 14, color: AppColors.textMuted)),
          SizedBox(height: 4),
          Text('Hubungkan ESP32 untuk mulai menerima data LoRa',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
        ]),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: records.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (ctx, i) => _RecordTile(record: records[i]),
    );
  }
}

class _RecordTile extends StatelessWidget {
  final LoraRecord record;
  const _RecordTile({required this.record});

  @override
  Widget build(BuildContext context) {
    final (tagBg, tagFg, tagLabel) = switch (record.packetType) {
      'rx'    => (AppColors.tagRxBg,  AppColors.tagRxText,  'RX'),
      'error' => (AppColors.tagErrBg, AppColors.tagErrText, 'ERR'),
      _       => (AppColors.tagSysBg, AppColors.tagSysText, 'SYS'),
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border, width: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(color: tagBg, borderRadius: BorderRadius.circular(99)),
          child: Text(tagLabel,
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: tagFg)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(record.parsedData ?? record.rawData,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textPrimary,
                  fontFamily: 'monospace',
                )),
            if (record.rssi != null) ...[
              const SizedBox(height: 4),
              Row(children: [
                _chip(Icons.signal_cellular_alt,
                    'RSSI: ${record.rssi}dBm', AppColors.blueBg, AppColors.blue),
                const SizedBox(width: 6),
                if (record.snr != null)
                  _chip(Icons.waves,
                      'SNR: ${record.snr!.toStringAsFixed(1)}dB',
                      AppColors.onlineBg, AppColors.onlineSub),
              ]),
            ],
          ]),
        ),
        Row(mainAxisSize: MainAxisSize.min, children: [
          Text(DateFormat('HH:mm:ss.SSS').format(record.receivedAt),
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textMuted,
                fontFamily: 'monospace',
              )),
          const SizedBox(width: 8),
          InkWell(
            onTap: () {
              Clipboard.setData(ClipboardData(text: record.rawData));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Data disalin ke clipboard'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
            borderRadius: BorderRadius.circular(6),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.copy_outlined, size: 14, color: AppColors.textMuted),
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _chip(IconData icon, String label, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 10, color: fg),
          const SizedBox(width: 3),
          Text(label, style: TextStyle(fontSize: 10, color: fg, fontWeight: FontWeight.w500)),
        ]),
      );
}
