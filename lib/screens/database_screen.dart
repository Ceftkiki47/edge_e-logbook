import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/lora_record.dart';
import '../providers/lora_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/app_topbar.dart';
import '../widgets/confirm_dialog.dart';

class DatabaseScreen extends StatefulWidget {
  const DatabaseScreen({super.key});

  @override
  State<DatabaseScreen> createState() => _DatabaseScreenState();
}

class _DatabaseScreenState extends State<DatabaseScreen> {
  List<LoraRecord> _records = [];
  bool _loading = false;
  int _offset = 0;
  static const _pageSize = 50;
  String? _dbPath;
  int _lastTotal = -1; // track perubahan total untuk auto-refresh

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Auto-refresh tabel saat data baru masuk ke DB
    final total = context.watch<LoraProvider>().stats?.totalPackets ?? 0;
    if (total != _lastTotal && _lastTotal != -1) {
      _lastTotal = total;
      _load(offset: _offset);
    } else {
      _lastTotal = total;
    }
  }

  Future<void> _load({int offset = 0}) async {
    setState(() { _loading = true; _offset = offset; });
    final prov = context.read<LoraProvider>();
    final rows = await prov.queryDb(limit: _pageSize, offset: offset);
    _dbPath ??= prov.dbPath;
    setState(() { _records = rows; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      const AppTopbar(title: 'Database Lokal'),
      Expanded(
        child: Consumer<LoraProvider>(
          builder: (_, prov, __) => Column(children: [
            _toolbar(prov),
            _statsRow(prov),
            Expanded(child: _loading ? _loadingWidget() : _table()),
            _pagination(prov),
          ]),
        ),
      ),
    ]);
  }

  Widget _toolbar(LoraProvider prov) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: AppColors.surface,
        child: Row(children: [
          // Auto-save toggle
          _badge(
            prov.autoSave ? Icons.save : Icons.save_outlined,
            'Auto-Save: ${prov.autoSave ? "ON" : "OFF"}',
            prov.autoSave ? AppColors.onlineBg : AppColors.surfaceAlt,
            prov.autoSave ? AppColors.onlineSub : AppColors.textMuted,
          ),
          const SizedBox(width: 8),
          Switch(
            value: prov.autoSave,
            onChanged: (v) {
              prov.setAutoSave(v);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('Auto-save ${v ? "diaktifkan" : "dimatikan"}'),
                duration: const Duration(seconds: 1),
              ));
            },
            activeThumbColor: AppColors.online,
          ),
          const Spacer(),
          // Hapus data lama
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: (prov.stats?.totalPackets ?? 0) == 0
                  ? AppColors.textMuted
                  : AppColors.amber,
              side: BorderSide(
                color: (prov.stats?.totalPackets ?? 0) == 0
                    ? AppColors.border
                    : AppColors.amber,
                width: 0.5,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: (prov.stats?.totalPackets ?? 0) == 0
                ? null
                : () => _confirmDeleteOld(context, prov),
            icon: const Icon(Icons.history, size: 14),
            label: const Text('Hapus Data Lama', style: TextStyle(fontSize: 11)),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: (prov.stats?.totalPackets ?? 0) == 0
                  ? AppColors.textMuted
                  : AppColors.danger,
              side: BorderSide(
                color: (prov.stats?.totalPackets ?? 0) == 0
                    ? AppColors.border
                    : AppColors.danger,
                width: 0.5,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: (prov.stats?.totalPackets ?? 0) == 0
                ? null
                : () => _confirmClearAll(context, prov),
            icon: const Icon(Icons.delete_forever, size: 14),
            label: const Text('Hapus Semua', style: TextStyle(fontSize: 11)),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => _load(offset: _offset),
            icon: const Icon(Icons.refresh, size: 16, color: AppColors.textMuted),
            tooltip: 'Refresh',
          ),
        ]),
      );

  Widget _statsRow(LoraProvider prov) {
    final s = prov.stats;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.surfaceAlt,
      child: Row(children: [
        _statChip('Total', '${s?.totalPackets ?? 0}', AppColors.textSecondary),
        const SizedBox(width: 16),
        _statChip('RX', '${s?.rxPackets ?? 0}', AppColors.onlineSub),
        const SizedBox(width: 16),
        _statChip('Error', '${s?.errorPackets ?? 0}', AppColors.danger),
        const SizedBox(width: 16),
        _statChip('Unsynced', '${s?.unsyncedCount ?? 0}', AppColors.amber),
        const Spacer(),
        if (_dbPath != null)
          Row(children: [
            const Icon(Icons.folder_outlined, size: 12, color: AppColors.textMuted),
            const SizedBox(width: 4),
            Text(_dbPath!,
                style: const TextStyle(fontSize: 10, color: AppColors.textMuted, fontFamily: 'monospace')),
          ]),
      ]),
    );
  }

  Widget _table() {
    if (_records.isEmpty) {
      return const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.storage_outlined, size: 40, color: AppColors.textMuted),
          SizedBox(height: 12),
          Text('Database kosong', style: TextStyle(fontSize: 14, color: AppColors.textMuted)),
          SizedBox(height: 4),
          Text('Aktifkan Auto-Save lalu hubungkan ESP32',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
        ]),
      );
    }

    final fmt = DateFormat('dd/MM HH:mm:ss');
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: 1160,
        child: Column(children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: AppColors.surfaceAlt,
            child: const Row(children: [
              SizedBox(width: 45,  child: _Th('ID')),
              SizedBox(width: 70,  child: _Th('Tipe')),
              SizedBox(width: 150, child: _Th('Trail')),
              SizedBox(width: 90,  child: _Th('Lat')),
              SizedBox(width: 90,  child: _Th('Lng')),
              SizedBox(width: 80,  child: _Th('Suhu Air')),
              SizedBox(width: 90,  child: _Th('Kelembapan')),
              SizedBox(width: 70,  child: _Th('Berat')),
              SizedBox(width: 60,  child: _Th('Interval')),
              SizedBox(width: 75,  child: _Th('RSSI')),
              SizedBox(width: 65,  child: _Th('SNR')),
              SizedBox(width: 130, child: _Th('Waktu')),
              SizedBox(width: 45,  child: _Th('Sync')),
            ]),
          ),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: _records.length,
              itemBuilder: (_, i) {
                final r      = _records[i];
                final isEven = i % 2 == 0;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  color: isEven ? AppColors.surface : AppColors.surfaceAlt,
                  child: Row(children: [
                    SizedBox(width: 45,  child: _Td('${r.id ?? '-'}')),
                    SizedBox(width: 70,  child: _TypeBadge(r.packetType)),
                    SizedBox(width: 150, child: _Td(r.trail ?? '—', mono: true)),
                    SizedBox(width: 90,  child: _Td(r.lat  != null ? r.lat!.toStringAsFixed(4) : '—', color: AppColors.purple)),
                    SizedBox(width: 90,  child: _Td(r.lng  != null ? r.lng!.toStringAsFixed(4) : '—', color: AppColors.purple)),
                    SizedBox(width: 80,  child: _Td(r.suhuAir        != null ? '${r.suhuAir!.toStringAsFixed(1)} °C' : '—', color: AppColors.amber)),
                    SizedBox(width: 90,  child: _Td(r.suhuKelembaban != null ? '${r.suhuKelembaban!.toStringAsFixed(1)} %' : '—', color: AppColors.blue)),
                    SizedBox(width: 70,  child: _Td(r.berat    != null ? '${r.berat!.toStringAsFixed(1)} kg' : '—', color: AppColors.onlineSub)),
                    SizedBox(width: 60,  child: _Td(r.interval != null ? '${r.interval}s' : '—')),
                    SizedBox(width: 75,  child: _Td(r.rssi != null ? '${r.rssi} dBm' : '—', color: AppColors.blue)),
                    SizedBox(width: 65,  child: _Td(r.snr  != null ? '${r.snr!.toStringAsFixed(1)} dB' : '—')),
                    SizedBox(width: 130, child: _Td(fmt.format(r.receivedAt), mono: true)),
                    SizedBox(width: 45,  child: Icon(
                      r.syncedToApi ? Icons.check_circle_outline : Icons.radio_button_unchecked,
                      size: 14,
                      color: r.syncedToApi ? AppColors.online : AppColors.textMuted,
                    )),
                  ]),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }

  Widget _pagination(LoraProvider prov) {
    final total = prov.stats?.totalPackets ?? 0;
    final page  = _offset ~/ _pageSize + 1;
    final pages = (total / _pageSize).ceil().clamp(1, 9999);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.surface,
      child: Row(children: [
        Text('${_offset + 1}–${(_offset + _records.length)} dari $total',
            style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
        const Spacer(),
        _pageBtn(Icons.first_page, _offset > 0, () => _load(offset: 0)),
        _pageBtn(Icons.chevron_left, _offset > 0, () => _load(offset: (_offset - _pageSize).clamp(0, 99999))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text('$page / $pages',
              style: const TextStyle(fontSize: 11.5, color: AppColors.textPrimary)),
        ),
        _pageBtn(Icons.chevron_right, _offset + _pageSize < total, () => _load(offset: _offset + _pageSize)),
        _pageBtn(Icons.last_page, _offset + _pageSize < total, () => _load(offset: ((pages - 1) * _pageSize))),
      ]),
    );
  }

  Widget _pageBtn(IconData icon, bool enabled, VoidCallback onTap) => InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: 16, color: enabled ? AppColors.textSecondary : AppColors.textMuted),
        ),
      );

  Widget _loadingWidget() => const Center(
        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.blue),
      );

  Widget _badge(IconData icon, String label, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 11, color: fg),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: fg)),
        ]),
      );

  Widget _statChip(String label, String value, Color color) => Row(children: [
        Text('$label: ', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
        Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
      ]);

  Future<void> _confirmDeleteOld(BuildContext ctx, LoraProvider prov) async {
    int days = 30;
    final total = prov.stats?.totalPackets ?? 0;

    final ok = await showConfirmDialog(
      ctx,
      title: 'Hapus Data Lama',
      message: 'Pilih rentang waktu. Data yang lebih lama dari batas yang dipilih akan dihapus permanen dari database.',
      confirmLabel: 'Hapus',
      level: ConfirmLevel.warning,
      countLabel: '$total total data tersimpan di database',
      detail: StatefulBuilder(
        builder: (_, setSt) => Wrap(
          spacing: 8,
          children: [7, 14, 30, 90].map((d) => ChoiceChip(
            label: Text('$d hari'),
            selected: days == d,
            onSelected: (_) => setSt(() => days = d),
            selectedColor: AppColors.blueBg,
            backgroundColor: AppColors.surfaceAlt,
            labelStyle: TextStyle(
              fontSize: 12,
              color: days == d ? AppColors.blue : AppColors.textSecondary,
              fontWeight: days == d ? FontWeight.w600 : FontWeight.normal,
            ),
            side: BorderSide(
              color: days == d ? AppColors.blue : AppColors.border,
              width: 0.5,
            ),
          )).toList(),
        ),
      ),
    );

    if (ok && ctx.mounted) {
      final n = await prov.deleteOldData(days);
      await _load(offset: 0);
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
          backgroundColor: AppColors.onlineBg,
          content: Row(children: [
            const Icon(Icons.check_circle_outline, size: 16, color: AppColors.onlineSub),
            const SizedBox(width: 8),
            Text('$n baris dihapus',
                style: const TextStyle(color: AppColors.onlineSub)),
          ]),
          duration: const Duration(seconds: 2),
        ));
      }
    }
  }

  Future<void> _confirmClearAll(BuildContext ctx, LoraProvider prov) async {
    final total = prov.stats?.totalPackets ?? 0;
    final ok = await showConfirmDialog(
      ctx,
      title: 'Hapus Semua Data',
      message: 'Seluruh data di database lokal akan dihapus secara permanen dan tidak dapat dikembalikan.',
      confirmLabel: 'Hapus Semua',
      level: ConfirmLevel.danger,
      countLabel: '$total paket akan dihapus permanen',
    );

    if (ok) {
      await prov.clearDb();
      await _load(offset: 0);
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
          backgroundColor: AppColors.dangerBg,
          content: Row(children: [
            Icon(Icons.delete_forever, size: 16, color: AppColors.danger),
            SizedBox(width: 8),
            Text('Semua data berhasil dihapus',
                style: TextStyle(color: AppColors.danger)),
          ]),
          duration: Duration(seconds: 2),
        ));
      }
    }
  }
}

class _Th extends StatelessWidget {
  final String text;
  const _Th(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.textMuted));
}

class _Td extends StatelessWidget {
  final String text;
  final bool mono;
  final Color? color;
  const _Td(this.text, {this.mono = false, this.color});
  @override
  Widget build(BuildContext context) => Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11.5,
          color: color ?? AppColors.textPrimary,
          fontFamily: mono ? 'monospace' : null,
        ),
      );
}

class _TypeBadge extends StatelessWidget {
  final String type;
  const _TypeBadge(this.type);
  @override
  Widget build(BuildContext context) {
    final (bg, fg, label) = switch (type) {
      'rx'    => (AppColors.tagRxBg,  AppColors.tagRxText,  'RX'),
      'error' => (AppColors.tagErrBg, AppColors.tagErrText, 'ERR'),
      _       => (AppColors.tagSysBg, AppColors.tagSysText, 'SYS'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
      child: Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: fg)),
    );
  }
}
