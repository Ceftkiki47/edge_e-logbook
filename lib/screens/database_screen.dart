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

  String _searchQuery = '';
  String _filterType = 'all';
  bool _unsyncedOnly = false;
  bool _showFilter = false;

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
    setState(() {
      _loading = true;
      _offset = offset;
    });
    final prov = context.read<LoraProvider>();
    final rows = await prov.queryDb(
      limit: _pageSize,
      offset: offset,
      searchQuery: _searchQuery,
      type: _filterType,
      unsyncedOnly: _unsyncedOnly,
    );
    _dbPath ??= prov.dbPath;
    setState(() {
      _records = rows;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const AppTopbar(title: 'Database Lokal'),
        Expanded(
          child: Consumer<LoraProvider>(
            builder: (_, prov, __) => Column(
              children: [
                _toolbar(prov),
                if (_showFilter) _filterPanel(),
                _statsRow(prov),
                Expanded(child: _loading ? _loadingWidget() : _table()),
                _pagination(prov),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _toolbar(LoraProvider prov) => Container(
    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    color: AppColors.surface,
    child: Row(
      children: [
        // Auto-save toggle
        _badge(
          prov.autoSave ? Icons.save : Icons.save_outlined,
          'Auto-Save: ${prov.autoSave ? "ON" : "OFF"}',
          prov.autoSave ? AppColors.onlineBg : AppColors.surfaceAlt,
          prov.autoSave ? AppColors.onlineSub : AppColors.textMuted,
        ),
        SizedBox(width: 8),
        Switch(
          value: prov.autoSave,
          onChanged: (v) {
            prov.setAutoSave(v);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Auto-save ${v ? "diaktifkan" : "dimatikan"}'),
                duration: const Duration(seconds: 1),
              ),
            );
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
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: (prov.stats?.totalPackets ?? 0) == 0
              ? null
              : () => _confirmDeleteOld(context, prov),
          icon: Icon(Icons.history, size: 14),
          label: Text('Hapus Data Lama', style: TextStyle(fontSize: 11)),
        ),
        SizedBox(width: 8),
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
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: (prov.stats?.totalPackets ?? 0) == 0
              ? null
              : () => _confirmClearAll(context, prov),
          icon: Icon(Icons.delete_forever, size: 14),
          label: Text('Hapus Semua', style: TextStyle(fontSize: 11)),
        ),
        SizedBox(width: 8),
        IconButton(
          onPressed: () => setState(() => _showFilter = !_showFilter),
          icon: Icon(
            Icons.filter_list,
            size: 16,
            color: _showFilter ? AppColors.blue : AppColors.textMuted,
          ),
          tooltip: 'Filter & Cari',
        ),
        IconButton(
          onPressed: () => _load(offset: _offset),
          icon: Icon(Icons.refresh, size: 16, color: AppColors.textMuted),
          tooltip: 'Refresh',
        ),
      ],
    ),
  );

  Widget _filterPanel() => Container(
    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    color: AppColors.surface,
    child: Row(
      children: [
        // Search Box
        Expanded(
          flex: 2,
          child: SizedBox(
            height: 32,
            child: TextField(
              style: TextStyle(fontSize: 12),
              decoration: InputDecoration(
                hintText: 'Cari trail, uuid, data...',
                hintStyle: TextStyle(fontSize: 12, color: AppColors.textMuted),
                prefixIcon: Icon(
                  Icons.search,
                  size: 14,
                  color: AppColors.textMuted,
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 0,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: AppColors.blue),
                ),
              ),
              onChanged: (val) {
                _searchQuery = val;
                _load(offset: 0);
              },
            ),
          ),
        ),
        SizedBox(width: 12),
        // Filter Type Dropdown
        Text(
          'Tipe: ',
          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
        SizedBox(
          height: 32,
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _filterType,
              style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
              dropdownColor: AppColors.surfaceAlt,
              icon: Icon(
                Icons.arrow_drop_down,
                size: 16,
                color: AppColors.textSecondary,
              ),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('Semua')),
                DropdownMenuItem(value: 'rx', child: Text('RX (Diterima)')),
                DropdownMenuItem(value: 'error', child: Text('Error')),
                DropdownMenuItem(value: 'system', child: Text('System')),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() => _filterType = val);
                  _load(offset: 0);
                }
              },
            ),
          ),
        ),
        SizedBox(width: 12),
        // Unsynced Only Checkbox
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 24,
              width: 24,
              child: Checkbox(
                value: _unsyncedOnly,
                activeColor: AppColors.blue,
                side: BorderSide(color: AppColors.border, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                onChanged: (val) {
                  setState(() => _unsyncedOnly = val ?? false);
                  _load(offset: 0);
                },
              ),
            ),
            SizedBox(width: 4),
            Text(
              'Belum Sync',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _statsRow(LoraProvider prov) {
    final s = prov.stats;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.surfaceAlt,
      child: Row(
        children: [
          _statChip(
            'Total',
            '${s?.totalPackets ?? 0}',
            AppColors.textSecondary,
          ),
          SizedBox(width: 16),
          _statChip('RX', '${s?.rxPackets ?? 0}', AppColors.onlineSub),
          SizedBox(width: 16),
          _statChip('Error', '${s?.errorPackets ?? 0}', AppColors.danger),
          SizedBox(width: 16),
          _statChip('Unsynced', '${s?.unsyncedCount ?? 0}', AppColors.amber),
          const Spacer(),
          if (_dbPath != null)
            Row(
              children: [
                Icon(
                  Icons.folder_outlined,
                  size: 12,
                  color: AppColors.textMuted,
                ),
                SizedBox(width: 4),
                Text(
                  _dbPath!,
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.textMuted,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _table() {
    if (_records.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.storage_outlined, size: 40, color: AppColors.textMuted),
            SizedBox(height: 12),
            Text(
              'Database kosong',
              style: TextStyle(fontSize: 14, color: AppColors.textMuted),
            ),
            SizedBox(height: 4),
            Text(
              'Aktifkan Auto-Save lalu hubungkan ESP32',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ],
        ),
      );
    }

    final fmt = DateFormat('dd/MM HH:mm:ss');
    return Column(
      children: [
        // Header
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: AppColors.surfaceAlt,
              child: Row(
                children: [
                  Expanded(flex: 45, child: _Th('ID')),
                  Expanded(flex: 60, child: _Th('Tipe')),
                  Expanded(flex: 120, child: _Th('Trail')),
                  Expanded(flex: 60, child: _Th('ID Ikan')),
                  Expanded(flex: 80, child: _Th('Jenis Ikan')),
                  Expanded(flex: 75, child: _Th('Lat')),
                  Expanded(flex: 75, child: _Th('Lng')),
                  Expanded(flex: 75, child: _Th('Suhu Air')),
                  Expanded(flex: 85, child: _Th('Kelembapan')),
                  Expanded(flex: 70, child: _Th('Berat')),
                  Expanded(flex: 60, child: _Th('Interval')),
                  Expanded(flex: 120, child: _Th('Waktu')),
                  Expanded(flex: 40, child: _Th('Sync', center: true)),
                  Expanded(flex: 35, child: _Th('Aksi', center: true)),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: _records.length,
                itemBuilder: (_, i) {
                  final r = _records[i];
                  final isEven = i % 2 == 0;
                  return Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    color: isEven ? AppColors.surface : AppColors.surfaceAlt,
                    child: Row(
                      children: [
                        Expanded(flex: 45, child: _Td('${r.id ?? '-'}')),
                        Expanded(flex: 60, child: _TypeBadge(r.packetType)),
                        Expanded(
                          flex: 120,
                          child: _Td(r.trail ?? '—', mono: true),
                        ),
                        Expanded(
                          flex: 60,
                          child: _Td(
                            '${r.idIkan ?? '—'}',
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Expanded(
                          flex: 80,
                          child: _Td(
                            r.jenisIkan ?? '—',
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Expanded(
                          flex: 75,
                          child: _Td(
                            r.lat != null ? r.lat!.toStringAsFixed(4) : '—',
                            color: AppColors.purple,
                          ),
                        ),
                        Expanded(
                          flex: 75,
                          child: _Td(
                            r.lng != null ? r.lng!.toStringAsFixed(4) : '—',
                            color: AppColors.purple,
                          ),
                        ),
                        Expanded(
                          flex: 75,
                          child: _Td(
                            r.suhuAir != null
                                ? '${r.suhuAir!.toStringAsFixed(1)} °C'
                                : '—',
                            color: AppColors.amber,
                          ),
                        ),
                        Expanded(
                          flex: 85,
                          child: _Td(
                            r.suhuKelembaban != null
                                ? '${r.suhuKelembaban!.toStringAsFixed(1)} %'
                                : '—',
                            color: AppColors.blue,
                          ),
                        ),
                        Expanded(
                          flex: 70,
                          child: _Td(
                            r.berat != null
                                ? '${r.berat!.toStringAsFixed(1)} kg'
                                : '—',
                            color: AppColors.onlineSub,
                          ),
                        ),
                        Expanded(
                          flex: 60,
                          child: _Td(
                            r.interval != null ? '${r.interval}s' : '—',
                          ),
                        ),
                        Expanded(
                          flex: 120,
                          child: _Td(fmt.format(r.receivedAt), mono: true),
                        ),
                        Expanded(
                          flex: 40,
                          child: Align(
                            alignment: Alignment.center,
                            child: Icon(
                              r.syncedToApi
                                  ? Icons.check_circle_outline
                                  : Icons.radio_button_unchecked,
                              size: 14,
                              color: r.syncedToApi
                                  ? AppColors.online
                                  : AppColors.textMuted,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 35,
                          child: Align(
                            alignment: Alignment.center,
                            child: IconButton(
                              icon: Icon(
                                Icons.remove_red_eye_outlined,
                                size: 16,
                                color: AppColors.blue,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              tooltip: 'Detail & Hapus',
                              onPressed: () => _showDetailCard(
                                context,
                                context.read<LoraProvider>(),
                                r,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
  }

  Widget _pagination(LoraProvider prov) {
    final total = prov.stats?.totalPackets ?? 0;
    if (total == 0) return SizedBox.shrink();

    final page = _offset ~/ _pageSize + 1;
    final pages = (total / _pageSize).ceil().clamp(1, 9999);
    final currentStart = _records.isEmpty ? 0 : total - _offset;
    final currentEnd = _records.isEmpty
        ? 0
        : total - _offset - _records.length + 1;

    int startPage = (page - 2).clamp(1, pages);
    int endPage = (page + 2).clamp(1, pages);

    if (endPage - startPage < 4) {
      if (startPage == 1) {
        endPage = (startPage + 4).clamp(1, pages);
      } else if (endPage == pages) {
        startPage = (endPage - 4).clamp(1, pages);
      }
    }

    List<Widget> pageButtons = [];
    for (int p = startPage; p <= endPage; p++) {
      pageButtons.add(_pageNumberBtn(p, p == page));
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.surface,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Page $page ($currentStart–$currentEnd) dari $total',
              style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _pageBtn(Icons.first_page, _offset > 0, () => _load(offset: 0)),
              _pageBtn(
                Icons.chevron_left,
                _offset > 0,
                () => _load(offset: (_offset - _pageSize).clamp(0, 99999)),
              ),
              SizedBox(width: 4),
              ...pageButtons,
              SizedBox(width: 4),
              _pageBtn(
                Icons.chevron_right,
                _offset + _pageSize < total,
                () => _load(offset: _offset + _pageSize),
              ),
              _pageBtn(
                Icons.last_page,
                _offset + _pageSize < total,
                () => _load(offset: ((pages - 1) * _pageSize)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pageBtn(IconData icon, bool enabled, VoidCallback onTap) => _HoverBtn(
    onTap: enabled ? onTap : null,
    padding: EdgeInsets.all(4),
    child: Icon(
      icon,
      size: 16,
      color: enabled ? AppColors.textSecondary : AppColors.textMuted,
    ),
  );

  Widget _pageNumberBtn(int p, bool isActive) => _HoverBtn(
    isActive: isActive,
    onTap: isActive ? null : () => _load(offset: (p - 1) * _pageSize),
    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    child: Text(
      '$p',
      style: TextStyle(
        fontSize: 11.5,
        fontWeight: isActive ? FontWeight.w700 : FontWeight.normal,
        color: isActive ? AppColors.blue : AppColors.textPrimary,
      ),
    ),
  );

  Widget _loadingWidget() => Center(
    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.blue),
  );

  Widget _badge(IconData icon, String label, Color bg, Color fg) => Container(
    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(99),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: fg),
        SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: fg,
          ),
        ),
      ],
    ),
  );

  Widget _statChip(String label, String value, Color color) => Row(
    children: [
      Text(
        '$label: ',
        style: TextStyle(fontSize: 11, color: AppColors.textMuted),
      ),
      Text(
        value,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    ],
  );

  Future<void> _confirmDeleteOld(BuildContext ctx, LoraProvider prov) async {
    int days = 30;
    final total = prov.stats?.totalPackets ?? 0;

    final ok = await showConfirmDialog(
      ctx,
      title: 'Hapus Data Lama',
      message:
          'Pilih rentang waktu. Data yang lebih lama dari batas yang dipilih akan dihapus permanen dari database.',
      confirmLabel: 'Hapus',
      level: ConfirmLevel.warning,
      countLabel: '$total total data tersimpan di database',
      detail: StatefulBuilder(
        builder: (_, setSt) => Wrap(
          spacing: 8,
          children: [7, 14, 30, 90]
              .map(
                (d) => ChoiceChip(
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
                ),
              )
              .toList(),
        ),
      ),
    );

    if (ok && ctx.mounted) {
      final n = await prov.deleteOldData(days);
      await _load(offset: 0);
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.onlineBg,
            content: Row(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 16,
                  color: AppColors.onlineSub,
                ),
                SizedBox(width: 8),
                Text(
                  '$n baris dihapus',
                  style: TextStyle(color: AppColors.onlineSub),
                ),
              ],
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _confirmClearAll(BuildContext ctx, LoraProvider prov) async {
    final total = prov.stats?.totalPackets ?? 0;
    final ok = await showConfirmDialog(
      ctx,
      title: 'Hapus Semua Data',
      message:
          'Seluruh data di database lokal akan dihapus secara permanen dan tidak dapat dikembalikan.',
      confirmLabel: 'Hapus Semua',
      level: ConfirmLevel.danger,
      countLabel: '$total paket akan dihapus permanen',
    );

    if (ok) {
      await prov.clearDb();
      await _load(offset: 0);
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.dangerBg,
            content: Row(
              children: [
                Icon(Icons.delete_forever, size: 16, color: AppColors.danger),
                SizedBox(width: 8),
                Text(
                  'Semua data berhasil dihapus',
                  style: TextStyle(color: AppColors.danger),
                ),
              ],
            ),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _showDetailCard(BuildContext ctx, LoraProvider prov, LoraRecord record) {
    showDialog(
      context: ctx,
      builder: (dCtx) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.border, width: 1),
        ),
        child: Container(
          width: 400,
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.description_outlined,
                    color: AppColors.textPrimary,
                    size: 20,
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Detail Paket Data',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Spacer(),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      color: AppColors.textMuted,
                      size: 18,
                    ),
                    onPressed: () => Navigator.pop(dCtx),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              Divider(color: AppColors.border, height: 24),
              _detailRow('ID Baris', '${record.id ?? '-'}'),
              _detailRow('Tipe Paket', record.packetType.toUpperCase()),
              _detailRow(
                'Waktu Terima',
                DateFormat('dd/MM/yyyy HH:mm:ss').format(record.receivedAt),
              ),
              _detailRow(
                'Status Sync',
                record.syncedToApi ? 'Sudah Sync' : 'Belum Sync',
              ),
              _detailRow('UUID', record.uuid),
              Divider(color: AppColors.border, height: 24),
              _detailRow('Trail', record.trail ?? '-'),
              _detailRow('ID Ikan', '${record.idIkan ?? '-'}'),
              _detailRow('Jenis Ikan', record.jenisIkan ?? '-'),
              _detailRow(
                'Suhu Air',
                record.suhuAir != null
                    ? '${record.suhuAir!.toStringAsFixed(1)} °C'
                    : '-',
              ),
              _detailRow(
                'Kelembapan',
                record.suhuKelembaban != null
                    ? '${record.suhuKelembaban!.toStringAsFixed(1)} %'
                    : '-',
              ),
              _detailRow(
                'Berat',
                record.berat != null
                    ? '${record.berat!.toStringAsFixed(1)} kg'
                    : '-',
              ),
              _detailRow('Interval (s)', '${record.interval ?? '-'}'),
              _detailRow('Lat', record.lat?.toStringAsFixed(4) ?? '-'),
              _detailRow('Lng', record.lng?.toStringAsFixed(4) ?? '-'),
              if (record.rssi != null || record.snr != null)
                Divider(color: AppColors.border, height: 24),
              if (record.rssi != null) _detailRow('RSSI', '${record.rssi} dBm'),
              if (record.snr != null) _detailRow('SNR', '${record.snr} dB'),
              SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.dangerBg,
                    foregroundColor: AppColors.dangerText,
                    elevation: 0,
                    side: BorderSide(color: AppColors.danger, width: 0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: Icon(Icons.delete_outline, size: 16),
                  label: Text(
                    'Hapus Data Ini',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  onPressed: () async {
                    final ok = await showConfirmDialog(
                      dCtx,
                      title: 'Hapus Data',
                      message:
                          'Data ID ${record.id} ini akan dihapus secara permanen dari database.',
                      confirmLabel: 'Hapus',
                      level: ConfirmLevel.danger,
                    );
                    if (ok && record.id != null) {
                      await prov.deleteRecord(record.id!);
                      if (dCtx.mounted)
                        Navigator.pop(dCtx); // Tutup modal detail
                      _load(offset: _offset); // Refresh tabel
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(
                            backgroundColor: AppColors.onlineBg,
                            content: Row(
                              children: [
                                Icon(
                                  Icons.check_circle_outline,
                                  size: 16,
                                  color: AppColors.onlineSub,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Data berhasil dihapus',
                                  style: TextStyle(color: AppColors.onlineSub),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
          Text(':', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Th extends StatelessWidget {
  final String text;
  final bool center;
  const _Th(this.text, {this.center = false});
  @override
  Widget build(BuildContext context) => Text(
    text,
    textAlign: center ? TextAlign.center : TextAlign.left,
    style: TextStyle(
      fontSize: 10.5,
      fontWeight: FontWeight.w700,
      color: AppColors.textMuted,
    ),
  );
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
      'rx' => (AppColors.tagRxBg, AppColors.tagRxText, 'RX'),
      'error' => (AppColors.tagErrBg, AppColors.tagErrText, 'ERR'),
      _ => (AppColors.tagSysBg, AppColors.tagSysText, 'SYS'),
    };
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: fg),
        ),
      ),
    );
  }
}

class _HoverBtn extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final bool isActive;
  final EdgeInsetsGeometry padding;

  const _HoverBtn({
    required this.child,
    this.onTap,
    this.isActive = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
  });

  @override
  State<_HoverBtn> createState() => _HoverBtnState();
}

class _HoverBtnState extends State<_HoverBtn> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final canTap = widget.onTap != null;
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: canTap ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: EdgeInsets.symmetric(horizontal: 2),
          padding: widget.padding,
          decoration: BoxDecoration(
            color: widget.isActive
                ? AppColors.blueBg
                : (_isHovered && canTap ? AppColors.surfaceAlt : Colors.transparent),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: widget.isActive
                  ? AppColors.blue
                  : (_isHovered && canTap ? AppColors.border : Colors.transparent),
              width: 0.5,
            ),
            boxShadow: (_isHovered && canTap && !widget.isActive)
                ? [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))]
                : null,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
