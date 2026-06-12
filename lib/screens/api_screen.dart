import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/lora_provider.dart';
import '../services/elogbook_sync_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_topbar.dart';

class ApiScreen extends StatefulWidget {
  const ApiScreen({super.key});

  @override
  State<ApiScreen> createState() => _ApiScreenState();
}

class _ApiScreenState extends State<ApiScreen> {
  String? _localIp;

  // Controller untuk field elogbook — pakai late agar bisa init dari provider
  late final TextEditingController _urlCtrl;
  late final TextEditingController _keyCtrl;
  late final TextEditingController _epCtrl;

  @override
  void initState() {
    super.initState();
    _getLocalIp();
    final sync = context.read<LoraProvider>().sync;
    _urlCtrl = TextEditingController(text: sync.baseUrl);
    _keyCtrl = TextEditingController(text: sync.apiKey);
    _epCtrl  = TextEditingController(text: sync.endpoint);
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _keyCtrl.dispose();
    _epCtrl.dispose();
    super.dispose();
  }

  Future<void> _getLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback) {
            setState(() => _localIp = addr.address);
            return;
          }
        }
      }
    } catch (_) {}
    setState(() => _localIp = '127.0.0.1');
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      const AppTopbar(title: 'API Server'),
      Expanded(
        child: Consumer<LoraProvider>(
          builder: (ctx, prov, child) => SingleChildScrollView(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Elogbook Sync (utama) ──────────────────────────────────
                _elogbookSyncCard(ctx, prov),
                SizedBox(height: 16),

                // ── Local API Server ───────────────────────────────────────
                _controlCard(ctx, prov),
              ],
            ),
          ),
        ),
      ),
    ]);
  }

  // ── Elogbook Sync Card ────────────────────────────────────────────────────
  Widget _elogbookSyncCard(BuildContext ctx, LoraProvider prov) {
    final sync   = prov.sync;
    final status = prov.syncStatus;
    final last   = prov.lastSyncResult;

    return _SectionCard(
      title: 'Kirim Data ke Elogbook / Main Website',
      icon: Icons.cloud_upload_outlined,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Status bar ────────────────────────────────────────────────────
        _syncStatusBar(status, last),
        SizedBox(height: 16),

        // ── Config fields ─────────────────────────────────────────────────
        _labeledField('URL Elogbook',
          hint: 'https://elogbook.example.com',
          ctrl: _urlCtrl,
          onChanged: prov.setElogbookUrl,
        ),
        SizedBox(height: 10),
        _labeledField('Endpoint Path',
          hint: '/api/edge/sync',
          ctrl: _epCtrl,
          onChanged: prov.setElogbookEndpoint,
        ),
        SizedBox(height: 10),
        _labeledField('API Key / Bearer Token',
          hint: 'sk-xxxxxxxxxxxx  (kosongkan jika tidak pakai)',
          ctrl: _keyCtrl,
          onChanged: prov.setElogbookApiKey,
          obscure: true,
        ),
        SizedBox(height: 16),

        // ── Tombol aksi ───────────────────────────────────────────────────
        Row(children: [
          // Test koneksi
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              side: BorderSide(color: AppColors.border, width: 0.5),
              minimumSize: const Size(0, 38),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => _testConnection(ctx, prov),
            icon: Icon(Icons.wifi_tethering, size: 14),
            label: Text('Test Koneksi', style: TextStyle(fontSize: 12)),
          ),
          SizedBox(width: 10),

          // Sync manual
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.blue,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 38),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            onPressed: status == SyncStatus.syncing ? null : () => _doSync(ctx, prov),
            icon: status == SyncStatus.syncing
                ? SizedBox(
                    width: 12, height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Icon(Icons.sync, size: 14),
            label: Text(status == SyncStatus.syncing ? 'Mengirim...' : 'Sync Sekarang',
                style: TextStyle(fontSize: 12)),
          ),
          SizedBox(width: 10),

          // Auto-sync toggle
          Text('Auto:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          SizedBox(width: 4),
          Switch(
            value: sync.autoEnabled,
            onChanged: (v) {
              if (v) {
                prov.startAutoSync(sync.autoIntervalMin);
              } else {
                prov.stopAutoSync();
              }
            },
            activeThumbColor: AppColors.online,
          ),
          if (sync.autoEnabled) ...[
            SizedBox(width: 4),
            _intervalDropdown(prov, sync),
          ],
        ]),
        SizedBox(height: 10),
        Row(children: [
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.blue,
              side: BorderSide(color: AppColors.blue.withValues(alpha: 0.5), width: 0.5),
              minimumSize: const Size(0, 38),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: status == SyncStatus.syncing ? null : () => _doForceSync(ctx, prov),
            icon: Icon(Icons.date_range, size: 14),
            label: Text('Sync Tanggal Tertentu', style: TextStyle(fontSize: 12)),
          ),
        ]),
      ]),
    );
  }

  Widget _syncStatusBar(SyncStatus status, SyncResult? last) {
    final (bg, fg, icon, label) = switch (status) {
      SyncStatus.syncing => (AppColors.blueBg,    AppColors.blue,      Icons.sync,              'Sedang mengirim data...'),
      SyncStatus.success => (AppColors.onlineBg,  AppColors.onlineSub, Icons.check_circle,      'Sukses: ${last?.pushed ?? 0} paket dikirim'),
      SyncStatus.error   => (AppColors.dangerBg,  AppColors.danger,    Icons.error_outline,     _getFriendlyErrorMessage(last?.errorMessage)),
      SyncStatus.idle    => (AppColors.surfaceAlt, AppColors.textMuted, Icons.cloud_off_outlined, 'Belum pernah sync'),
    };

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: fg.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Row(children: [
        Icon(icon, size: 14, color: fg),
        SizedBox(width: 8),
        Expanded(
          child: Text(label, style: TextStyle(fontSize: 12, color: fg, fontWeight: FontWeight.w500)),
        ),
        if (last != null && status != SyncStatus.syncing)
          Text(
            _formatTime(last.timestamp),
            style: TextStyle(fontSize: 10, color: AppColors.textMuted, fontFamily: 'monospace'),
          ),
      ]),
    );
  }

  Widget _labeledField(String label, {
    required String hint,
    required TextEditingController ctrl,
    required ValueChanged<String> onChanged,
    bool obscure = false,
  }) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
        SizedBox(height: 5),
        TextField(
          controller: ctrl,
          obscureText: obscure,
          style: TextStyle(fontSize: 12.5, color: AppColors.textPrimary, fontFamily: 'monospace'),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(fontSize: 12, color: AppColors.textMuted),
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            filled: true,
            fillColor: AppColors.surfaceAlt,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(7),
              borderSide: BorderSide(color: AppColors.border, width: 0.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(7),
              borderSide: BorderSide(color: AppColors.border, width: 0.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(7),
              borderSide: BorderSide(color: AppColors.blue),
            ),
          ),
          onChanged: onChanged,
        ),
      ]);

  Widget _intervalDropdown(LoraProvider prov, ElogbookSyncService sync) =>
      DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: sync.autoIntervalMin,
          dropdownColor: AppColors.surface,
          style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
          isDense: true,
          onChanged: (v) { if (v != null) prov.startAutoSync(v); },
          items: const [
            DropdownMenuItem(value: 1,  child: Text('1 menit')),
            DropdownMenuItem(value: 5,  child: Text('5 menit')),
            DropdownMenuItem(value: 10, child: Text('10 menit')),
            DropdownMenuItem(value: 30, child: Text('30 menit')),
          ],
        ),
      );

  Future<void> _testConnection(BuildContext ctx, LoraProvider prov) async {
    final result = await prov.sync.testConnection();
    if (!ctx.mounted) return;
    
    final friendlyMsg = result.ok ? result.message : _getFriendlyErrorMessage(result.message);
    
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
      backgroundColor: result.ok ? AppColors.onlineBg : AppColors.dangerBg,
      content: Row(children: [
        Icon(result.ok ? Icons.check_circle : Icons.error_outline,
            size: 16, color: result.ok ? AppColors.onlineSub : AppColors.danger),
        SizedBox(width: 8),
        Expanded(
          child: Text(friendlyMsg,
              style: TextStyle(color: result.ok ? AppColors.onlineSub : AppColors.danger)),
        ),
      ]),
      duration: const Duration(seconds: 4),
    ));
  }

  Future<void> _doSync(BuildContext ctx, LoraProvider prov) async {
    if (!prov.sync.isConfigured) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(content: Text('Isi URL Elogbook terlebih dahulu')),
      );
      return;
    }
    final result = await prov.syncToElogbook();
    if (!ctx.mounted) return;
    final msg = result.isSuccess
        ? '${result.pushed} paket berhasil dikirim'
        : 'Gagal: ${_getFriendlyErrorMessage(result.errorMessage)}';
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
      backgroundColor: result.isSuccess ? AppColors.onlineBg : AppColors.dangerBg,
      content: Text(msg,
          style: TextStyle(color: result.isSuccess ? AppColors.onlineSub : AppColors.danger)),
      duration: const Duration(seconds: 3),
    ));
  }

  Future<void> _doForceSync(BuildContext ctx, LoraProvider prov) async {
    if (!prov.sync.isConfigured) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(content: Text('Isi URL Elogbook terlebih dahulu')),
      );
      return;
    }

    final date = await showDatePicker(
      context: ctx,
      initialDate: DateTime.now().subtract(const Duration(days: 1)),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.blue,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (date == null) return;
    if (!ctx.mounted) return;

    final result = await prov.forceSyncByDate(date);
    if (!ctx.mounted) return;
    final msg = result.isSuccess
        ? '${result.pushed} paket tanggal ${date.day}/${date.month}/${date.year} berhasil dikirim'
        : 'Gagal: ${_getFriendlyErrorMessage(result.errorMessage)}';
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
      backgroundColor: result.isSuccess ? AppColors.onlineBg : AppColors.dangerBg,
      content: Text(msg,
          style: TextStyle(color: result.isSuccess ? AppColors.onlineSub : AppColors.danger)),
      duration: const Duration(seconds: 4),
    ));
  }

  String _formatTime(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';

  String _getFriendlyErrorMessage(String? error) {
    if (error == null || error.isEmpty) return 'Terjadi kesalahan sistem.';
    final msg = error.toLowerCase();

    // Pesan-pesan yang sudah cukup jelas dari service
    if (msg.contains('belum dikonfigurasi') || 
        msg.contains('sedang berjalan') || 
        msg.contains('percobaan')) {
      return error;
    }

    // Terjemahan error teknis
    if (msg.contains('socketexception') || msg.contains('connection refused') || msg.contains('network is unreachable')) {
      return 'Gagal terhubung. Pastikan internet lancar dan alamat URL benar.';
    }
    if (msg.contains('timeout') || msg.contains('timed out')) {
      return 'Koneksi terlalu lama. Internet lambat atau server sedang mati.';
    }
    if (msg.contains('401') || msg.contains('unauthorized')) {
      return 'Akses ditolak. Silakan periksa kembali API Key Anda.';
    }
    if (msg.contains('404')) {
      return 'Alamat URL (Endpoint) tidak ditemukan di server.';
    }
    if (msg.contains('500') || msg.contains('502') || msg.contains('503')) {
      return 'Server utama sedang mengalami gangguan. Silakan coba lagi nanti.';
    }
    if (msg.contains('format') || msg.contains('json')) {
      return 'Data yang diterima dari server tidak dapat dibaca.';
    }
    if (msg.contains('xmlhttprequest') || msg.contains('clientexception')) {
      return 'Terjadi masalah pada koneksi internet Anda.';
    }
    if (msg.contains('handshake') || msg.contains('certificate')) {
      return 'Koneksi tidak aman. Pastikan URL menggunakan http atau https.';
    }

    // Default error jika tidak masuk filter
    return 'Terjadi masalah: $error';
  }

  // ── Local API Server card ─────────────────────────────────────────────────
  Widget _controlCard(BuildContext ctx, LoraProvider prov) {
    final running = prov.apiRunning;
    final host = _localIp ?? '...';
    final port = prov.apiPortActive;

    return _SectionCard(
      title: 'Local API Server (Inbound)',
      icon: Icons.dns_outlined,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 10, height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: running ? AppColors.online : AppColors.textMuted,
              boxShadow: running
                  ? [BoxShadow(color: AppColors.online.withValues(alpha: 0.5), blurRadius: 6)]
                  : null,
            ),
          ),
          SizedBox(width: 8),
          Text(running ? 'Server Berjalan' : 'Server Mati',
              style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700,
                color: running ? AppColors.online : AppColors.textMuted,
              )),
          const Spacer(),
          if (running)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.onlineBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.online, width: 0.5),
              ),
              child: Text('http://$host:$port',
                  style: TextStyle(
                    fontSize: 12, color: AppColors.onlineSub,
                    fontFamily: 'monospace', fontWeight: FontWeight.w600,
                  )),
            ),
        ]),
        SizedBox(height: 16),
        Row(children: [
          Text('Port:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          SizedBox(width: 8),
          SizedBox(
            width: 90,
            child: TextField(
              enabled: !running,
              controller: TextEditingController(text: '${prov.apiPort}'),
              keyboardType: TextInputType.number,
              style: TextStyle(fontSize: 12, color: AppColors.textPrimary, fontFamily: 'monospace'),
              decoration: _inputDecor(),
              onChanged: (v) {
                final p = int.tryParse(v);
                if (p != null && p > 1024 && p < 65535) prov.setApiPort(p);
              },
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: running ? AppColors.dangerText : AppColors.blue,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 40),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              onPressed: running
                  ? () async { await prov.stopApiServer(); }
                  : () async {
                      final ok = await prov.startApiServer();
                      if (!ok && ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('Gagal memulai server. Port mungkin sedang digunakan.')),
                        );
                      }
                    },
              icon: Icon(running ? Icons.stop : Icons.play_arrow, size: 16),
              label: Text(running ? 'Stop Server' : 'Start Server'),
            ),
          ),
        ]),
        if (running) ...[
          SizedBox(height: 12),
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border, width: 0.5),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.info_outline, size: 12, color: AppColors.textMuted),
                SizedBox(width: 6),
                Text('Akses dari perangkat lain di jaringan yang sama:',
                    style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
              ]),
              SizedBox(height: 6),
              SelectableText('http://$host:$port/api/packets/latest',
                  style: TextStyle(fontSize: 12, color: AppColors.blue, fontFamily: 'monospace')),
            ]),
          ),
        ],
      ]),
    );
  }



  InputDecoration _inputDecor() => InputDecoration(
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        filled: true, fillColor: AppColors.surfaceAlt,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: AppColors.border, width: 0.5)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: AppColors.border, width: 0.5)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: AppColors.blue)),
        disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: AppColors.border, width: 0.5)),
      );
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  const _SectionCard({required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border, width: 0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 16, color: AppColors.textSecondary),
            SizedBox(width: 8),
            Text(title,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          ]),
          SizedBox(height: 14),
          child,
        ]),
      );
}
