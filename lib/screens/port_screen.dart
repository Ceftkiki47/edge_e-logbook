import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/lora_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/app_topbar.dart';

class PortScreen extends StatelessWidget {
  const PortScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      const AppTopbar(title: 'Koneksi Port'),
      Expanded(
        child: Consumer<LoraProvider>(
          builder: (_, prov, __) => SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionCard(
                  title: 'Konfigurasi Serial Port',
                  icon: Icons.cable_outlined,
                  child: _portConfig(context, prov),
                ),
                const SizedBox(height: 16),
                _sectionCard(
                  title: 'Status Koneksi',
                  icon: Icons.info_outline,
                  child: _connStatus(prov),
                ),
                const SizedBox(height: 16),
                _sectionCard(
                  title: 'Panduan Koneksi ESP32',
                  icon: Icons.help_outline,
                  child: _guide(),
                ),
              ],
            ),
          ),
        ),
      ),
    ]);
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) =>
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border, width: 0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  )),
            ]),
            const SizedBox(height: 14),
            child,
          ],
        ),
      );

  Widget _portConfig(BuildContext ctx, LoraProvider prov) => Column(children: [
        _labeledField(
          label: 'Port Serial',
          child: Row(children: [
            Expanded(
              child: prov.availPorts.isEmpty
                  ? _emptyPortField()
                  : _dropdownField<String>(
                      value: prov.selectedPort,
                      items: prov.availPorts,
                      label: (p) => p,
                      hint: 'Pilih port...',
                      enabled: !prov.isConnected,
                      onChanged: prov.isConnected ? null : (v) { if (v != null) prov.setPort(v); },
                    ),
            ),
            const SizedBox(width: 8),
            _smallBtn(
              icon: Icons.refresh,
              onTap: prov.refreshPorts,
              tooltip: 'Refresh daftar port',
            ),
          ]),
        ),
        const SizedBox(height: 12),
        _labeledField(
          label: 'Baud Rate',
          child: _dropdownField<int>(
            value: prov.baudRate,
            items: const [9600, 19200, 38400, 57600, 115200],
            label: (b) => '$b bps',
            enabled: !prov.isConnected,
            onChanged: prov.isConnected ? null : (v) => prov.setBaud(v!),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  prov.isConnected ? AppColors.dangerText : AppColors.blue,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 40),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            onPressed: prov.serialState == SerialState.connecting
                ? null
                : (prov.isConnected ? prov.disconnect : prov.connect),
            icon: Icon(prov.isConnected ? Icons.link_off : Icons.link, size: 16),
            label: Text(
              prov.serialState == SerialState.connecting
                  ? 'Menghubungkan...'
                  : prov.isConnected
                      ? 'Putuskan Koneksi'
                      : 'Hubungkan',
            ),
          ),
        ),
      ]);

  Widget _connStatus(LoraProvider prov) {
    final (dot, label, desc) = switch (prov.serialState) {
      SerialState.connected => (
        AppColors.online,
        'Terhubung',
        'Port ${prov.selectedPort ?? '-'} aktif @ ${prov.baudRate} baud',
      ),
      SerialState.connecting => (
        AppColors.warning,
        'Menghubungkan',
        'Membuka port ${prov.selectedPort ?? '-'}...',
      ),
      SerialState.error => (
        AppColors.danger,
        'Error',
        'Gagal membuka port. Periksa koneksi USB.',
      ),
      _ => (
        AppColors.textMuted,
        'Terputus',
        'Tidak ada koneksi aktif',
      ),
    };

    return Row(children: [
      Container(
        width: 10, height: 10,
        decoration: BoxDecoration(shape: BoxShape.circle, color: dot),
      ),
      const SizedBox(width: 10),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            )),
        Text(desc,
            style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
      ]),
    ]);
  }

  Widget _guide() => const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _GuideStep(no: '1', text: 'Hubungkan ESP32 ke komputer via kabel USB'),
          SizedBox(height: 8),
          _GuideStep(no: '2', text: 'Pastikan driver USB sudah terinstall (CP2102 atau CH340)'),
          SizedBox(height: 8),
          _GuideStep(
              no: '3',
              text: 'Pilih port serial yang sesuai (biasanya /dev/ttyUSB0 di Linux, COM3 di Windows)'),
          SizedBox(height: 8),
          _GuideStep(
              no: '4',
              text: 'Pastikan baud rate sama dengan firmware ESP32 (default: 115200)'),
          SizedBox(height: 8),
          _GuideStep(
              no: '5',
              text: 'Klik Hubungkan — data LoRa 433MHz akan otomatis tampil di Dashboard'),
          SizedBox(height: 12),
          Divider(color: AppColors.border, thickness: 0.5),
          SizedBox(height: 10),
          Text(
            'Catatan: Aplikasi ini hanya menerima data (Read-Only). '
            'Tidak ada data yang dikirim ke ESP32.',
            style: TextStyle(
              fontSize: 11.5,
              color: AppColors.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      );

  Widget _emptyPortField() => Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          border: Border.all(color: AppColors.border, width: 0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(children: [
          Icon(Icons.usb_off, size: 14, color: AppColors.textMuted),
          SizedBox(width: 8),
          Text('Tidak ada port terdeteksi',
              style: TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
        ]),
      );

  Widget _labeledField({required String label, required Widget child}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            )),
        const SizedBox(height: 6),
        child,
      ]);

  Widget _dropdownField<T>({
    required T? value,
    required List<T> items,
    required String Function(T) label,
    String? hint,
    required bool enabled,
    required ValueChanged<T?>? onChanged,
  }) =>
      Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: enabled ? AppColors.surface : AppColors.surfaceAlt,
          border: Border.all(color: AppColors.border, width: 0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: value,
            hint: hint != null
                ? Text(hint,
                    style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted))
                : null,
            style: const TextStyle(fontSize: 12.5, color: AppColors.textPrimary),
            dropdownColor: AppColors.surface,
            isExpanded: true,
            isDense: true,
            onChanged: onChanged,
            items: items
                .map((i) => DropdownMenuItem(value: i, child: Text(label(i))))
                .toList(),
          ),
        ),
      );

  Widget _smallBtn({
    required IconData icon,
    required VoidCallback onTap,
    required String tooltip,
  }) =>
      Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border, width: 0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: AppColors.textSecondary),
          ),
        ),
      );
}

class _GuideStep extends StatelessWidget {
  final String no;
  final String text;
  const _GuideStep({required this.no, required this.text});

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20, height: 20,
            decoration: const BoxDecoration(
              color: AppColors.blueBg,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(no,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.blue,
                  )),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textPrimary,
                  height: 1.4,
                )),
          ),
        ],
      );
}
