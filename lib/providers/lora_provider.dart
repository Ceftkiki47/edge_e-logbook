import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:uuid/uuid.dart';
import '../database/lora_database.dart';
import '../api/lora_api_server.dart';
import '../models/lora_record.dart';
import '../services/lora_serial_service.dart';
import '../services/elogbook_sync_service.dart';
import '../theme/app_colors.dart';
export '../services/lora_serial_service.dart' show SerialState;
export '../services/elogbook_sync_service.dart' show SyncStatus, SyncResult;

class LoraProvider extends ChangeNotifier {
  final _serial = LoraSerialService();
  final _db = LoraDatabase.instance;
  final _api = LoraApiServer();
  final sync = ElogbookSyncService();

  // ── State ─────────────────────────────────────────────────────────────────
  bool isAuthenticated = false;
  List<LoraRecord> packets = []; // buffer in-memory (UI)
  LoraStats? stats;
  List<String> availPorts = [];
  String? selectedPort;
  int baudRate = 115200;
  int apiPort = LoraApiServer.defaultPort;
  bool autoSave = true; // simpan ke DB otomatis
  bool isDarkMode = false; // State tema
  bool isAutoConnect = true; // Koneksi otomatis ke port serial

  Timer? _autoConnectTimer;

  SerialState get serialState => _serial.state;
  bool get isConnected => serialState == SerialState.connected;
  bool get apiRunning => _api.isRunning;
  int get apiPortActive => _api.port;

  String? dbPath;
  String? savedEcid;
  String? hardwareId;
  List<String> savedLoraNodes = [];

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

    await _loadPreferences();
    sync.startAutoSync(1); // Auto sync otomatis dengan interval 1 menit

    refreshPorts();
    _startAutoConnectTimer();
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
    bool ascending = false,
    bool unsyncedOnly = false,
    String? searchQuery,
    String? sourceFilter,
  }) => _db.getAll(
    limit: limit,
    offset: offset,
    type: type,
    from: from,
    to: to,
    ascending: ascending,
    unsyncedOnly: unsyncedOnly,
    searchQuery: searchQuery,
    sourceFilter: sourceFilter,
  );

  Future<void> clearDb({String? source}) async {
    if (source != null && source != 'all') {
      await _db.clearBySource(source);
    } else {
      await _db.clearAll();
    }
    await _refreshStats();
    notifyListeners();
  }

  Future<int> deleteOldData(int days, {String? source}) async {
    final n = await _db.deleteOlderThan(days, source: source);
    await _refreshStats();
    notifyListeners();
    return n;
  }

  Future<bool> deleteRecord(int id) async {
    final count = await _db.deleteById(id);
    if (count > 0) {
      await _refreshStats();
      notifyListeners();
      return true;
    }
    return false;
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

  // ── Pairing API ───────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> fetchAvailableDevices() async {
    if (isAuthenticated) {
      await _fetchLatestProfile();
    }

    final baseUrl = sync.baseUrl;
    if (baseUrl.isEmpty) throw Exception('URL Elogbook belum diatur.');

    final uri = Uri.parse(
      '$baseUrl/api/edge/available-devices${savedEcid != null ? '?ecid=$savedEcid' : ''}',
    );
    debugPrint('Meminta daftar perangkat dari: $uri');
    final response = await http.get(
      uri,
      headers: {
        'Accept': 'application/json',
        if (sync.apiKey.isNotEmpty) 'Authorization': 'Bearer ${sync.apiKey}',
      },
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      if (json['success'] == true) {
        return json['data'];
      } else {
        throw Exception(json['message'] ?? 'Gagal mengambil data perangkat');
      }
    } else {
      throw Exception('Server error: ${response.statusCode}');
    }
  }

  Future<void> lockDevices(String ecid, List<String> loraNodes) async {
    final baseUrl = sync.baseUrl;
    if (baseUrl.isEmpty) throw Exception('URL Elogbook belum diatur.');

    final uri = Uri.parse('$baseUrl/api/edge/lock-devices');
    debugPrint(
      'Mencoba mengunci perangkat ke ECID: $ecid dengan ${loraNodes.length} node(s)',
    );
    final response = await http
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            if (sync.apiKey.isNotEmpty) 'Authorization': 'Bearer ${sync.apiKey}',
          },
          body: jsonEncode({'ecid': ecid, 'lora_nodes': loraNodes}),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      if (json['success'] == true) {
        savedEcid = ecid;
        savedLoraNodes = loraNodes;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('elogbook_ecid', ecid);
        await prefs.setStringList('elogbook_lora_nodes', loraNodes);

        sync.edgeEcid = savedEcid;
        sync.edgeLoraNodes = savedLoraNodes;
        notifyListeners();
      } else {
        throw Exception(json['message'] ?? 'Gagal mengunci perangkat');
      }
    } else {
      throw Exception(
        'Server error: ${response.statusCode} - ${response.body}',
      );
    }
  }

  Future<void> clearSavedEcid() async {
    final oldEcid = savedEcid;
    if (oldEcid != null) {
      final baseUrl = sync.baseUrl;
      if (baseUrl.isNotEmpty) {
        try {
          final uri = Uri.parse('$baseUrl/api/edge/lock-devices');
          await http
              .post(
                uri,
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({'ecid': oldEcid, 'lora_nodes': []}),
              )
              .timeout(const Duration(seconds: 5));
          debugPrint('Berhasil melepas kuncian di server untuk ECID: $oldEcid');
        } catch (e) {
          debugPrint('Gagal melepas kuncian di server: $e');
        }
      }
    }

    savedEcid = null;
    savedLoraNodes = [];
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('elogbook_ecid');
    await prefs.remove('elogbook_lora_nodes');

    sync.edgeEcid = null;
    sync.edgeLoraNodes = [];
    notifyListeners();
  }

  void setAutoSave(bool v) {
    autoSave = v;
    notifyListeners();
  }

  void setAutoConnect(bool v) {
    isAutoConnect = v;
    notifyListeners();
    if (v) {
      _checkAndAutoConnect();
    }
  }

  void _startAutoConnectTimer() {
    _autoConnectTimer?.cancel();
    _autoConnectTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _checkAndAutoConnect();
    });
  }

  Future<void> _checkAndAutoConnect() async {
    if (!isAutoConnect || isConnected || serialState == SerialState.connecting)
      return;

    final oldPorts = List<String>.from(availPorts);
    availPorts = LoraSerialService.availablePorts();

    // Jangan notifyListeners jika port list sama agar tidak merefresh UI terus menerus
    if (!listEquals(oldPorts, availPorts)) {
      notifyListeners();
    }

    if (availPorts.isNotEmpty) {
      // Prioritaskan selectedPort, jika tidak ada, ambil port pertama
      if (selectedPort == null || !availPorts.contains(selectedPort)) {
        selectedPort = availPorts.first;
      }
      await connect();
    }
  }

  void toggleTheme(bool dark) {
    isDarkMode = dark;
    AppColors.isDarkMode = dark;
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

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    sync.baseUrl = dotenv.env['API_URL'] ?? '';
    sync.endpoint =
        prefs.getString('elogbook_endpoint') ?? '/api/edge/sync/data';
    sync.apiKey = prefs.getString('elogbook_key') ?? '';
    savedEcid = prefs.getString('elogbook_ecid');
    
    hardwareId = prefs.getString('hardware_id');
    if (hardwareId == null) {
      hardwareId = const Uuid().v4();
      await prefs.setString('hardware_id', hardwareId!);
      debugPrint('Generated new Hardware ID: $hardwareId');
    }

    savedLoraNodes = prefs.getStringList('elogbook_lora_nodes') ?? [];

    sync.edgeEcid = savedEcid;
    sync.edgeLoraNodes = savedLoraNodes;

    isAuthenticated = prefs.getBool('is_authenticated') ?? false;
    notifyListeners();
    
    if (isAuthenticated) {
      _fetchLatestProfile(); // run in background
    }
  }

  Future<void> _fetchLatestProfile() async {
    if (sync.apiKey.isEmpty || sync.baseUrl.isEmpty) return;
    try {
      final uri = Uri.parse('${sync.baseUrl}/api/edge/auth/me');
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${sync.apiKey}'
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final assignedEcid = data['user']?['assigned_ec_id'];
          final prefs = await SharedPreferences.getInstance();
          
          if (assignedEcid != null && assignedEcid.toString().isNotEmpty) {
            final newEcid = assignedEcid.toString();
            if (newEcid != savedEcid) {
              savedEcid = newEcid;
              await prefs.setString('elogbook_ecid', savedEcid!);
              sync.edgeEcid = savedEcid;
              notifyListeners();
            }
          } else {
             if (savedEcid != null) {
                savedEcid = null;
                await prefs.remove('elogbook_ecid');
                sync.edgeEcid = null;
                notifyListeners();
             }
          }
        }
      }
    } catch (e) {
      debugPrint('Gagal mengambil profil terbaru: $e');
    }
  }

  Future<SyncResult> syncToElogbook() async {
    final result = await sync.syncNow();
    await _refreshStats();
    notifyListeners();
    return result;
  }

  Future<SyncResult> forceSyncByDate(DateTime date) async {
    final result = await sync.forceSyncByDate(date);
    await _refreshStats();
    notifyListeners();
    return result;
  }

  Future<void> setElogbookUrl(String url) async {
    sync.baseUrl = url;
    notifyListeners();
    try {
      final file = File('.env');
      if (await file.exists()) {
        final lines = await file.readAsLines();
        final newLines = <String>[];
        bool found = false;
        for (var line in lines) {
          if (line.trim().startsWith('API_URL=')) {
            newLines.add('API_URL=$url');
            found = true;
          } else {
            newLines.add(line);
          }
        }
        if (!found) {
          newLines.add('API_URL=$url');
        }
        await file.writeAsString(newLines.join('\n') + '\n');
      } else {
        await file.writeAsString('API_URL=$url\n');
      }
      dotenv.env['API_URL'] = url;
    } catch (e) {
      debugPrint('Gagal menyimpan ke .env: $e');
    }
  }

  Future<void> setElogbookEndpoint(String ep) async {
    sync.endpoint = ep;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('elogbook_endpoint', ep);
  }

  Future<void> setElogbookApiKey(String key) async {
    sync.apiKey = key;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('elogbook_key', key);
  }

  void startAutoSync(int minutes) {
    sync.startAutoSync(minutes);
    notifyListeners();
  }

  void stopAutoSync() {
    sync.stopAutoSync();
    notifyListeners();
  }

  // ── Authentication ────────────────────────────────────────────────────────
  Future<String?> login(String username, String password) async {
    try {
      final url = Uri.parse('${sync.baseUrl}/api/edge/auth/login');
      debugPrint('Mencoba login ke: $url');
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'username': username,
              'password': password,
              'platform': 'desktop',
              'hardware_id': hardwareId
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final token = data['token'] ?? data['data']?['token'];
          isAuthenticated = true;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('is_authenticated', true);
          if (token != null) {
            await setElogbookApiKey(token);
          }
          
          // Tangkap assigned_ec_id jika ada, lalu kunci secara otomatis
          final assignedEcid = data['user']?['assigned_ec_id'];
          if (assignedEcid != null && assignedEcid.toString().isNotEmpty) {
            savedEcid = assignedEcid.toString();
            await prefs.setString('elogbook_ecid', savedEcid!);
            sync.edgeEcid = savedEcid;
          }
          
          notifyListeners();
          return null; // Sukses
        } else {
          debugPrint('Login gagal: ${response.body}');
          return data['message'] ?? 'Login gagal. Coba lagi.';
        }
      } else {
        debugPrint(
          'Login HTTP Error: ${response.statusCode} - ${response.body}',
        );
        try {
          final data = jsonDecode(response.body);
          if (data['message'] != null) {
            return data['message'];
          }
        } catch (_) {}
        
        if (response.statusCode == 401) {
          return 'Username atau password salah';
        } else if (response.statusCode == 403) {
          return 'Akses ditolak oleh server.';
        }
        return 'Server error HTTP ${response.statusCode}';
      }
    } catch (e) {
      debugPrint('Login Exception: $e');
      return 'Gagal: $e';
    }
  }

  Future<void> logout() async {
    isAuthenticated = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_authenticated', false);
    notifyListeners();
  }

  @override
  void dispose() {
    _autoConnectTimer?.cancel();
    _serial.dispose();
    _api.stop();
    sync.dispose();
    super.dispose();
  }
}
