import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart'; // SYNC FEATURE: Import paket konektivitas
import '../database/lora_database.dart';
import '../models/lora_record.dart';

enum SyncStatus { idle, syncing, success, error }

class SyncResult {
  final int pushed;
  final int failed;
  final String? errorMessage;
  final DateTime timestamp;

  SyncResult({
    required this.pushed,
    required this.failed,
    this.errorMessage,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  bool get isSuccess => failed == 0 && errorMessage == null;
}

class ElogbookSyncService {
  static const _batchSize   = 50;   // kirim max 50 record per request
  static const _timeoutSec  = 15;
  static const _maxRetries  = 3;

  final _db = LoraDatabase.instance;

  // ── State ─────────────────────────────────────────────────────────────────
  SyncStatus _status = SyncStatus.idle;
  SyncResult? _lastResult;
  Timer? _autoTimer;
  bool _autoEnabled = false;
  int _autoIntervalMin = 5;

  // SYNC FEATURE: Variabel untuk menyimpan subscription listener koneksi internet
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  SyncStatus get status   => _status;
  SyncResult? get lastResult => _lastResult;
  bool get autoEnabled    => _autoEnabled;
  int get autoIntervalMin => _autoIntervalMin;

  // Stream untuk notifikasi perubahan state ke UI
  final _statusCtrl = StreamController<SyncStatus>.broadcast();
  Stream<SyncStatus> get statusStream => _statusCtrl.stream;

  // ── Konfigurasi ───────────────────────────────────────────────────────────
  String baseUrl   = '';   // contoh: https://elogbook.example.com
  String endpoint  = '/api/edge/sync';
  String apiKey    = '';   // Bearer token / API key

  bool get isConfigured => baseUrl.isNotEmpty;

  String get _cleanBaseUrl {
    var url = baseUrl.stripTrailing('/');
    if (url.endsWith('/api')) {
      url = url.substring(0, url.length - 4);
    }
    return url;
  }

  String get fullUrl => '$_cleanBaseUrl$endpoint';

  // SYNC FEATURE: Inisialisasi listener untuk memantau perubahan status koneksi internet
  void initConnectivityListener() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      // SYNC FEATURE: Memeriksa apakah ada koneksi aktif (mobile, wifi, ethernet, atau vpn)
      final hasInternet = results.any((r) => 
        r == ConnectivityResult.mobile || 
        r == ConnectivityResult.wifi || 
        r == ConnectivityResult.ethernet || 
        r == ConnectivityResult.vpn
      );

      // SYNC FEATURE: Jika internet tersedia dan url api sudah dikonfigurasi, jalankan sync otomatis
      if (hasInternet && isConfigured) {
        debugPrint('[Sync] Koneksi internet pulih, memicu sinkronisasi otomatis...');
        syncNow();
      }
    });
  }

  // ── Sync manual ───────────────────────────────────────────────────────────
  /// Push semua record yang belum di-sync (synced = 0) ke elogbook.
  /// Dikirim per batch, setiap batch di-retry jika gagal.
  Future<SyncResult> syncNow() async {
    if (_status == SyncStatus.syncing) {
      return SyncResult(pushed: 0, failed: 0, errorMessage: 'Sync sedang berjalan');
    }
    if (!isConfigured) {
      return SyncResult(pushed: 0, failed: 0, errorMessage: 'URL elogbook belum dikonfigurasi');
    }

    _setStatus(SyncStatus.syncing);

    int totalPushed = 0;
    int totalFailed = 0;
    String? lastError;

    try {
      // Ambil semua unsynced secara bertahap
      int offset = 0;
      while (true) {
        final batch = await _db.getAll(
          limit: _batchSize,
          offset: offset,
          type: 'rx',
          unsyncedOnly: true,
        );
        if (batch.isEmpty) break;

        final result = await _pushBatch(batch);
        if (result.$1 > 0) {
          // Tandai yang berhasil sebagai synced
          final synced = batch.take(result.$1).map((r) => r.uuid).toList();
          await _db.markSynced(synced);
          totalPushed += result.$1;
        }
        totalFailed += result.$2;
        if (result.$3 != null) lastError = result.$3;

        if (result.$2 > 0) break; // stop jika ada batch yang gagal
        offset += _batchSize;
      }

      _lastResult = SyncResult(pushed: totalPushed, failed: totalFailed, errorMessage: lastError);
      _setStatus(totalFailed == 0 ? SyncStatus.success : SyncStatus.error);
    } catch (e) {
      _lastResult = SyncResult(pushed: totalPushed, failed: totalFailed, errorMessage: e.toString());
      _setStatus(SyncStatus.error);
    }

    return _lastResult!;
  }

  /// Push satu batch, return (pushed, failed, errorMsg)
  Future<(int, int, String?)> _pushBatch(List<LoraRecord> batch) async {
    for (int attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        final body = jsonEncode({
          'source':    'lora_edge',
          'timestamp': DateTime.now().toIso8601String(),
          'count':     batch.length,
          'packets':   batch.map((r) => r.toJson()).toList(),
        });

        final headers = {
          'Content-Type':  'application/json; charset=utf-8',
          'Accept':        'application/json',
          if (apiKey.isNotEmpty) 'Authorization': 'Bearer $apiKey',
          'X-Edge-Source': 'lora-receiver-desktop',
        };

        final response = await http
            .post(Uri.parse(fullUrl), headers: headers, body: body)
            .timeout(const Duration(seconds: _timeoutSec));

        if (response.statusCode == 200 || response.statusCode == 201) {
          return (batch.length, 0, null);
        }

        // 4xx — jangan retry, data bermasalah
        if (response.statusCode >= 400 && response.statusCode < 500) {
          final msg = 'HTTP ${response.statusCode}: ${response.body}';
          return (0, batch.length, msg);
        }

        // 5xx — retry
        if (attempt < _maxRetries) {
          await Future.delayed(Duration(seconds: attempt * 2)); // backoff
        }
      } on TimeoutException {
        if (attempt == _maxRetries) {
          return (0, batch.length, 'Timeout setelah ${_timeoutSec}s');
        }
        await Future.delayed(Duration(seconds: attempt * 2));
      } catch (e) {
        if (attempt == _maxRetries) {
          return (0, batch.length, e.toString());
        }
        await Future.delayed(Duration(seconds: attempt * 2));
      }
    }
    return (0, batch.length, 'Gagal setelah $_maxRetries percobaan');
  }

  // ── Forward raw JSON ke elogbook (dari Postman via /api/push/batch) ────────
  Future<int> forwardRaw(String jsonBody) async {
    final headers = {
      'Content-Type':  'application/json; charset=utf-8',
      'Accept':        'application/json',
      if (apiKey.isNotEmpty) 'Authorization': 'Bearer $apiKey',
      'X-Edge-Source': 'lora-receiver-desktop',
    };
    final res = await http
        .post(Uri.parse(fullUrl), headers: headers, body: jsonBody)
        .timeout(const Duration(seconds: _timeoutSec));
    return res.statusCode;
  }

  // ── Auto-sync ─────────────────────────────────────────────────────────────
  void startAutoSync(int intervalMinutes) {
    _autoIntervalMin = intervalMinutes;
    _autoEnabled = true;
    _autoTimer?.cancel();
    _autoTimer = Timer.periodic(
      Duration(minutes: intervalMinutes),
      (_) => syncNow(),
    );
    debugPrint('[Sync] Auto-sync aktif setiap $intervalMinutes menit');
  }

  void stopAutoSync() {
    _autoTimer?.cancel();
    _autoTimer = null;
    _autoEnabled = false;
  }

  // ── Test koneksi ──────────────────────────────────────────────────────────
  Future<({bool ok, int? statusCode, String message})> testConnection() async {
    if (!isConfigured) {
      return (ok: false, statusCode: null, message: 'URL belum dikonfigurasi');
    }
    try {
      final healthUrl = '$_cleanBaseUrl/api/health';
      final headers = <String, String>{
        if (apiKey.isNotEmpty) 'Authorization': 'Bearer $apiKey',
      };
      final res = await http
          .get(Uri.parse(healthUrl), headers: headers)
          .timeout(const Duration(seconds: 5));
      return (
        ok: res.statusCode < 400,
        statusCode: res.statusCode,
        message: res.statusCode < 400 ? 'Server dapat dijangkau' : 'HTTP ${res.statusCode}',
      );
    } on TimeoutException {
      return (ok: false, statusCode: null, message: 'Timeout — server tidak merespons');
    } catch (e) {
      return (ok: false, statusCode: null, message: e.toString());
    }
  }

  void _setStatus(SyncStatus s) {
    _status = s;
    _statusCtrl.add(s);
  }

  void dispose() {
    stopAutoSync();
    // SYNC FEATURE: Pastikan subscription di-cancel untuk menghindari memory leak
    _connectivitySubscription?.cancel();
    _statusCtrl.close();
  }
}

extension on String {
  String stripTrailing(String char) =>
      endsWith(char) ? substring(0, length - char.length) : this;
}
