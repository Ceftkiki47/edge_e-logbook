import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/lora_record.dart';

class LoraDatabase {
  static const _dbName = 'lora_receiver.db';
  static const _dbVersion = 2;
  static const _table = 'lora_packets';

  static LoraDatabase? _instance;
  static Database? _db;

  LoraDatabase._();
  static LoraDatabase get instance => _instance ??= LoraDatabase._();

  // ── Inisialisasi SQLite FFI untuk Desktop ────────────────────────────────
  static Future<void> initFfi() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  }

  Future<Database> get database async {
    _db ??= await _openDatabase();
    return _db!;
  }

  Future<Database> _openDatabase() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'LoRaReceiver', _dbName);

    // Pastikan direktori ada
    await Directory(p.dirname(path)).create(recursive: true);

    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  // ── Buat tabel ─────────────────────────────────────────────────────────────
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_table (
        id               INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid             TEXT    NOT NULL UNIQUE,
        raw_data         TEXT    NOT NULL,
        parsed_data      TEXT,
        rssi             INTEGER,
        snr              REAL,
        packet_type      TEXT    NOT NULL DEFAULT 'rx',
        received_at      TEXT    NOT NULL,
        synced           INTEGER NOT NULL DEFAULT 0,
        trail            TEXT,
        lat              REAL,
        lng              REAL,
        suhu_air         REAL,
        suhu_kelembaban  REAL,
        berat            REAL,
        interval         INTEGER
      )
    ''');
    await db.execute('CREATE INDEX idx_received_at ON $_table (received_at DESC)');
    await db.execute('CREATE INDEX idx_packet_type ON $_table (packet_type)');
    await db.execute('CREATE INDEX idx_synced      ON $_table (synced)');
    await db.execute('CREATE INDEX idx_trail       ON $_table (trail)');
  }

  Future<void> _onUpgrade(Database db, int oldVer, int newVer) async {
    // Migrasi v1 → v2: tambah kolom sensor
    if (oldVer < 2) {
      for (final col in [
        'ALTER TABLE $_table ADD COLUMN trail           TEXT',
        'ALTER TABLE $_table ADD COLUMN lat             REAL',
        'ALTER TABLE $_table ADD COLUMN lng             REAL',
        'ALTER TABLE $_table ADD COLUMN suhu_air        REAL',
        'ALTER TABLE $_table ADD COLUMN suhu_kelembaban REAL',
        'ALTER TABLE $_table ADD COLUMN berat           REAL',
        'ALTER TABLE $_table ADD COLUMN interval        INTEGER',
      ]) {
        await db.execute(col);
      }
      await db.execute('CREATE INDEX IF NOT EXISTS idx_trail ON $_table (trail)');
    }
  }

  // ── CRUD ──────────────────────────────────────────────────────────────────

  /// Simpan satu paket baru
  Future<LoraRecord> insert(LoraRecord record) async {
    final db = await database;
    final id = await db.insert(
      _table,
      record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    return record.copyWith(id: id);
  }

  /// Ambil semua paket (terbaru di atas), dengan filter opsional
  Future<List<LoraRecord>> getAll({
    int limit = 200,
    int offset = 0,
    String? type, // 'rx' | 'error' | 'system'
    DateTime? from,
    DateTime? to,
    bool unsyncedOnly = false,
  }) async {
    final db = await database;

    final where = <String>[];
    final args = <dynamic>[];

    if (type != null) {
      where.add('packet_type = ?');
      args.add(type);
    }
    if (from != null) {
      where.add('received_at >= ?');
      args.add(from.toIso8601String());
    }
    if (to != null) {
      where.add('received_at <= ?');
      args.add(to.toIso8601String());
    }
    if (unsyncedOnly) {
      where.add('synced = 0');
    }

    final rows = await db.query(
      _table,
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'received_at DESC',
      limit: limit,
      offset: offset,
    );

    return rows.map(LoraRecord.fromMap).toList();
  }

  /// Ambil satu paket berdasarkan ID
  Future<LoraRecord?> getById(int id) async {
    final db = await database;
    final rows = await db.query(
      _table,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : LoraRecord.fromMap(rows.first);
  }

  /// Tandai paket sebagai sudah di-sync ke API
  Future<void> markSynced(List<String> uuids) async {
    if (uuids.isEmpty) return;
    final db = await database;
    final placeholders = uuids.map((_) => '?').join(',');
    await db.rawUpdate(
      'UPDATE $_table SET synced = 1 WHERE uuid IN ($placeholders)',
      uuids,
    );
  }

  /// Hapus data lama (lebih dari N hari)
  Future<int> deleteOlderThan(int days) async {
    final db = await database;
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return db.delete(
      _table,
      where: 'received_at < ?',
      whereArgs: [cutoff.toIso8601String()],
    );
  }

  /// Hapus semua data
  Future<void> clearAll() async {
    final db = await database;
    await db.delete(_table);
  }

  // ── Statistik ─────────────────────────────────────────────────────────────
  Future<LoraStats> getStats() async {
    final db = await database;

    int countRow(List<Map> rows) =>
        (rows.first.values.first as int?) ?? 0;

    final total    = countRow(await db.rawQuery('SELECT COUNT(*) FROM $_table'));
    final rx       = countRow(await db.rawQuery("SELECT COUNT(*) FROM $_table WHERE packet_type='rx'"));
    final err      = countRow(await db.rawQuery("SELECT COUNT(*) FROM $_table WHERE packet_type='error'"));
    final unsynced = countRow(await db.rawQuery('SELECT COUNT(*) FROM $_table WHERE synced=0'));

    final lastRow = await db.rawQuery(
      "SELECT rssi, snr, received_at FROM $_table "
      "WHERE packet_type='rx' AND rssi IS NOT NULL "
      "ORDER BY received_at DESC LIMIT 1",
    );

    final firstRow = await db.rawQuery(
      'SELECT received_at FROM $_table ORDER BY received_at ASC LIMIT 1',
    );

    return LoraStats(
      totalPackets: total,
      rxPackets: rx,
      errorPackets: err,
      unsyncedCount: unsynced,
      lastRssi: lastRow.isNotEmpty ? lastRow.first['rssi'] as int? : null,
      lastSnr: lastRow.isNotEmpty
          ? (lastRow.first['snr'] as num?)?.toDouble()
          : null,
      firstRecord: firstRow.isNotEmpty
          ? DateTime.tryParse(firstRow.first['received_at'] as String)
          : null,
      lastRecord: lastRow.isNotEmpty
          ? DateTime.tryParse(lastRow.first['received_at'] as String)
          : null,
    );
  }

  /// Path file database (untuk ditampilkan di UI)
  Future<String> getDatabasePath() async {
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, 'LoRaReceiver', _dbName);
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
