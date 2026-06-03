import 'dart:async';
import 'package:flutter/foundation.dart';

import '../database/lora_database.dart';
import '../api/lora_api_server.dart';
import '../models/lora_record.dart';
import '../services/lora_serial_service.dart';
import '../services/elogbook_sync_service.dart';

export '../services/lora_serial_service.dart' show SerialState;
export '../services/elogbook_sync_service.dart' show SyncStatus, SyncResult;

class LoraProvider extends ChangeNotifier {
  final _serial = LoraSerialService();
  final _db     = LoraDatabase.instance;
  final _api    = LoraApiServer();
  final sync    = ElogbookSyncService();

  // ── State ─────────────────────────────────────────────────────────────────
  List<LoraRecord> packets = []; // buffer in-memory (UI)
  LoraStats? stats;
  List<String> availPorts = [];
  String? selectedPort;
  int baudRate = 115200;
  int apiPort = LoraApiServer.defaultPort;
  bool autoSave = true; // simpan ke DB otomatis

  SerialState get serialState => _serial.state;
  bool get isConnected => serialState == SerialState.connected;
  bool get apiRunning => _api.isRunning;
  int get apiPortActive => _api.port;

  String? dbPath;

  // ── Init ──────────────────────────────────────────────────────────────────
  LoraProvider() {
    _init();
  }

  Future<void> _init() async {
    // initFfi sudah dipanggil di main() sebelum runApp
    dbPath = await _db.getDatabasePath();
    await _refreshStats();

    _serial.stateStream.listen((_) => notifyListeners());
    sync.statusStream.listen((_) => notifyListeners());
    _serial.packetStream.listen(_onPacketReceived);

    // SYNC FEATURE: Inisialisasi listener koneksi internet untuk auto-sync
    sync.initConnectivityListener();

    refreshPorts();
    notifyListeners();
  }

  // ── Terima paket, simpan ke DB ────────────────────────────────────────────
  Future<void> _onPacketReceived(LoraRecord record) async {
    // Tambah ke buffer UI (max 500)
    packets.insert(0, record);
    if (packets.length > 500) packets.removeLast();
    notifyListeners(); // update UI segera

    // Simpan ke SQLite jika autoSave aktif
    if (autoSave && record.packetType != 'system') {
      try {
        await _db.insert(record);
        await _refreshStats();
        notifyListeners(); // update stats setelah insert
      } catch (e) {
        debugPrint('[DB] Gagal insert: $e');
      }
    }
  }

  // ── Serial ────────────────────────────────────────────────────────────────
  void refreshPorts() {
    availPorts = LoraSerialService.availablePorts();
    if (availPorts.isNotEmpty && selectedPort == null) {
      selectedPort = availPorts.first;
    }
    notifyListeners();
  }

  Future<void> connect() async {
    if (selectedPort == null) return;
    await _serial.connect(portName: selectedPort!, baudRate: baudRate);
  }

  void disconnect() => _serial.disconnect();

  // ── API Server ────────────────────────────────────────────────────────────
  Future<bool> startApiServer({int? port}) async {
    final ok = await _api.start(port: port ?? apiPort, sync: sync);
    notifyListeners();
    return ok;
  }

  Future<void> stopApiServer() async {
    await _api.stop();
    notifyListeners();
  }

  // ── Database ──────────────────────────────────────────────────────────────
  Future<List<LoraRecord>> queryDb({
    int limit = 100,
    int offset = 0,
    String? type,
    DateTime? from,
    DateTime? to,
  }) =>
      _db.getAll(limit: limit, offset: offset, type: type, from: from, to: to);

  Future<void> clearDb() async {
    await _db.clearAll();
    await _refreshStats();
    notifyListeners();
  }

  Future<int> deleteOldData(int days) async {
    final n = await _db.deleteOlderThan(days);
    await _refreshStats();
    notifyListeners();
    return n;
  }

  Future<void> _refreshStats() async {
    stats = await _db.getStats();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  void clearBuffer() {
    packets.clear();
    notifyListeners();
  }

  void setPort(String p) {
    selectedPort = p;
    notifyListeners();
  }

  void setBaud(int b) {
    baudRate = b;
    notifyListeners();
  }

  void setApiPort(int p) {
    apiPort = p;
    notifyListeners();
  }

  void setAutoSave(bool v) {
    autoSave = v;
    notifyListeners();
  }

  // Stat shortcuts
  int get rxCount => packets.where((p) => p.packetType == 'rx').length;
  int get errCount => packets.where((p) => p.packetType == 'error').length;
  int? get lastRssi {
    try {
      return packets.firstWhere((p) => p.rssi != null).rssi;
    } catch (_) {
      return null;
    }
  }

  double? get lastSnr {
    try {
      return packets.firstWhere((p) => p.snr != null).snr;
    } catch (_) {
      return null;
    }
  }

  int get signalScore {
    final r = lastRssi;
    final s = lastSnr;
    if (r == null || s == null) return 0;
    final rp = ((r + 120) / 70 * 100).clamp(0, 100);
    final sp = ((s + 5) / 25 * 100).clamp(0, 100);
    return ((rp + sp) / 2).round();
  }

  String get signalTitle {
    if (!isConnected) return 'Menunggu Koneksi';
    final s = signalScore;
    if (s == 0) return 'Menunggu Paket';
    if (s > 70) return 'Sinyal Baik';
    if (s > 40) return 'Sinyal Sedang';
    return 'Sinyal Lemah';
  }

  String get signalSub {
    if (!isConnected) return 'Hubungkan port serial ESP32';
    final s = signalScore;
    if (s == 0) return 'Siap menerima data LoRa 433MHz';
    if (s > 70) return 'Penerimaan optimal';
    if (s > 40) return 'Jangkauan cukup';
    return 'Periksa posisi antena';
  }

  // ── Elogbook Sync ─────────────────────────────────────────────────────────
  SyncStatus get syncStatus => sync.status;
  SyncResult? get lastSyncResult => sync.lastResult;

  Future<SyncResult> syncToElogbook() async {
    final result = await sync.syncNow();
    await _refreshStats();
    notifyListeners();
    return result;
  }

  void setElogbookUrl(String url) {
    sync.baseUrl = url;
    notifyListeners();
  }

  void setElogbookApiKey(String key) {
    sync.apiKey = key;
    notifyListeners();
  }

  void setElogbookEndpoint(String ep) {
    sync.endpoint = ep;
    notifyListeners();
  }

  void startAutoSync(int minutes) {
    sync.startAutoSync(minutes);
    notifyListeners();
  }

  void stopAutoSync() {
    sync.stopAutoSync();
    notifyListeners();
  }

  @override
  void dispose() {
    _serial.dispose();
    _api.stop();
    sync.dispose();
    super.dispose();
  }
}
