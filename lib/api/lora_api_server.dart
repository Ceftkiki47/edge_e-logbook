import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_cors_headers/shelf_cors_headers.dart';

import '../database/lora_database.dart';
import '../models/lora_record.dart';
import '../services/elogbook_sync_service.dart';

class LoraApiServer {
  static const defaultPort = 7788;

  HttpServer? _server;
  int _port = defaultPort;
  bool get isRunning => _server != null;
  int  get port      => _port;

  final _db = LoraDatabase.instance;
  ElogbookSyncService? _sync;

  // ── Start / Stop ──────────────────────────────────────────────────────────
  Future<bool> start({int port = defaultPort, ElogbookSyncService? sync}) async {
    if (_server != null) return true;
    _sync = sync;
    _port = port;

    try {
      final handler = const Pipeline()
          .addMiddleware(corsHeaders(headers: {
            'Access-Control-Allow-Origin':  '*',
            'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
            'Access-Control-Allow-Headers': 'Content-Type, Authorization',
          }))
          .addMiddleware(logRequests())
          .addHandler(_buildRouter());

      _server = await io.serve(handler.call, InternetAddress.anyIPv4, port);
      debugPrint('[API] Server berjalan di http://0.0.0.0:$port');
      return true;
    } catch (e) {
      debugPrint('[API] Gagal start: $e');
      return false;
    }
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }

  // ── Router ────────────────────────────────────────────────────────────────
  Handler _buildRouter() {
    final r = Router();

    // ── Health ───────────────────────────────────────────────────────────────
    r.get('/api/health', (_) async => _json({
      'status':    'ok',
      'timestamp': DateTime.now().toIso8601String(),
      'version':   '1.0.0',
      'service':   'LoRa Receiver API',
    }));

    // ── POST /api/ingest — simpan paket langsung ke database lokal ───────────
    // Endpoint ini untuk Postman / script eksternal yang ingin insert data
    // TIDAK perlu konfigurasi elogbook, langsung masuk SQLite
    r.post('/api/ingest', (Request req) async {
      final rawBody = await req.readAsString();
      if (rawBody.isEmpty) return _error('Body tidak boleh kosong', 400);

      Map<String, dynamic> j;
      try {
        j = jsonDecode(rawBody) as Map<String, dynamic>;
      } catch (e) {
        return _error('Body JSON tidak valid: $e', 400);
      }

      // Support 2 format:
      // 1. Single : { "data": "sensor:25.3", "rssi": -67, "snr": 9.2 }
      // 2. Batch  : { "packets": [ {...}, {...} ] }
      final List<dynamic> list =
          j.containsKey('packets') ? (j['packets'] as List) : [j];

      if (list.isEmpty) return _error('Tidak ada paket yang dikirim', 400);

      int inserted = 0, skipped = 0;
      final errs = <String>[];

      for (final item in list) {
        try {
          final p    = item as Map<String, dynamic>;
          final uuid = (p['uuid'] as String?)?.isNotEmpty == true
              ? p['uuid'] as String
              : _uuid();

          await _db.insert(LoraRecord(
            uuid:       uuid,
            rawData:    (p['raw_data'] as String?) ?? jsonEncode(p),
            parsedData: (p['parsed_data'] as String?) ?? (p['data'] as String?),
            rssi:       p['rssi'] as int?,
            snr:        (p['snr'] as num?)?.toDouble(),
            packetType: (p['packet_type'] as String?) ?? 'rx',
            receivedAt: p['received_at'] != null
                ? DateTime.tryParse(p['received_at'] as String) ?? DateTime.now()
                : DateTime.now(),
          ));
          inserted++;
        } catch (e) {
          skipped++;
          errs.add(e.toString());
        }
      }

      return _json({
        'ok':       inserted > 0,
        'inserted': inserted,
        'skipped':  skipped,
        'total':    list.length,
        if (errs.isNotEmpty) 'errors': errs,
      }, inserted > 0 ? 201 : 400);
    });

    // ── Stats ────────────────────────────────────────────────────────────────
    r.get('/api/stats', (_) async {
      final s = await _db.getStats();
      return _json(s.toJson());
    });

    // ═════════════════════════════════════════════════════════════════════════
    // PUSH ENDPOINTS — untuk Postman & integrasi elogbook
    // ═════════════════════════════════════════════════════════════════════════

    // ── GET /api/push/status — cek status & konfigurasi sync ─────────────────
    r.get('/api/push/status', (_) async {
      final last = _sync?.lastResult;
      return _json({
        'sync_status':  _sync?.status.name ?? 'not_configured',
        'auto_enabled': _sync?.autoEnabled ?? false,
        'elogbook_url': _sync?.baseUrl.isNotEmpty == true ? _sync!.baseUrl : null,
        'is_configured': _sync?.isConfigured ?? false,
        'last_push': last == null ? null : {
          'pushed':    last.pushed,
          'failed':    last.failed,
          'ok':        last.isSuccess,
          'timestamp': last.timestamp.toIso8601String(),
          'error':     last.errorMessage,
        },
      });
    });

    // ── GET /api/push/unsynced — preview data belum terkirim ──────────────────
    r.get('/api/push/unsynced', (Request req) async {
      final q     = req.url.queryParameters;
      final limit = int.tryParse(q['limit'] ?? '20') ?? 20;
      final records = await _db.getAll(
        limit:        limit.clamp(1, 200),
        type:         'rx',
        unsyncedOnly: true,
      );
      final stats = await _db.getStats();
      return _json({
        'unsynced_total': stats.unsyncedCount,
        'preview_count':  records.length,
        'preview':        records.map((r) => r.toJson()).toList(),
      });
    });

    // ── POST /api/push — trigger sync semua unsynced dari DB ke elogbook ──────
    r.post('/api/push', (Request req) async {
      if (_sync == null || !_sync!.isConfigured) {
        return _error(
          'URL elogbook belum dikonfigurasi. '
          'Buka halaman API Server di aplikasi, isi URL elogbook, lalu coba lagi.',
          400,
        );
      }
      if (_sync!.status == SyncStatus.syncing) {
        return _error('Sync sedang berjalan, tunggu selesai.', 409);
      }

      final result = await _sync!.syncNow();
      return _json({
        'ok':        result.isSuccess,
        'pushed':    result.pushed,
        'failed':    result.failed,
        'message':   result.errorMessage ?? 'Sync selesai',
        'timestamp': result.timestamp.toIso8601String(),
      }, result.isSuccess ? 200 : 500);
    });

    // ── POST /api/push/batch — kirim data custom langsung ke elogbook ─────────
    // Berguna untuk test dari Postman tanpa perlu data dari ESP32
    r.post('/api/push/batch', (Request req) async {
      if (_sync == null || !_sync!.isConfigured) {
        return _error(
          'URL elogbook belum dikonfigurasi. Isi di halaman API Server.',
          400,
        );
      }

      final rawBody = await req.readAsString();
      if (rawBody.isEmpty) {
        return _error('Body tidak boleh kosong', 400);
      }

      try {
        final j = jsonDecode(rawBody) as Map<String, dynamic>;
        if (j['packets'] == null) {
          return _error('Field "packets" (array) wajib ada', 400);
        }
      } catch (e) {
        return _error('Body JSON tidak valid: $e', 400);
      }

      try {
        final statusCode = await _sync!.forwardRaw(rawBody);
        final ok = statusCode >= 200 && statusCode < 300;
        return _json({
          'ok':              ok,
          'upstream_status': statusCode,
          'message':         ok ? 'Data berhasil dikirim ke elogbook' : 'Elogbook menolak data',
        }, ok ? 200 : 502);
      } catch (e) {
        return _error('Gagal menghubungi elogbook: $e', 502);
      }
    });

    // ═════════════════════════════════════════════════════════════════════════
    // PACKETS ENDPOINTS
    // ═════════════════════════════════════════════════════════════════════════

    r.get('/api/packets/latest', (Request req) async {
      final limit = int.tryParse(req.url.queryParameters['limit'] ?? '20') ?? 20;
      final records = await _db.getAll(limit: limit.clamp(1, 200), type: 'rx');
      return _json({'count': records.length, 'data': records.map((r) => r.toJson()).toList()});
    });

    r.get('/api/packets/range', (Request req) async {
      final q    = req.url.queryParameters;
      final from = DateTime.tryParse(q['from'] ?? '');
      final to   = DateTime.tryParse(q['to']   ?? '');
      if (from == null || to == null) {
        return _error('Parameter from dan to wajib (ISO8601)', 400);
      }
      final records = await _db.getAll(from: from, to: to, limit: 1000);
      return _json({
        'from':  from.toIso8601String(),
        'to':    to.toIso8601String(),
        'count': records.length,
        'data':  records.map((r) => r.toJson()).toList(),
      });
    });

    r.get('/api/packets/<id>', (Request req, String id) async {
      final intId = int.tryParse(id);
      if (intId == null) return _error('ID tidak valid', 400);
      final record = await _db.getById(intId);
      if (record == null) return _error('Paket tidak ditemukan', 404);
      return _json(record.toJson());
    });

    r.get('/api/packets', (Request req) async {
      final q        = req.url.queryParameters;
      final limit    = int.tryParse(q['limit']  ?? '100') ?? 100;
      final offset   = int.tryParse(q['offset'] ?? '0')   ?? 0;
      final type     = q['type'];
      final unsynced = q['unsynced'] == '1' || q['unsynced'] == 'true';
      final from     = q['from'] != null ? DateTime.tryParse(q['from']!) : null;
      final to       = q['to']   != null ? DateTime.tryParse(q['to']!)   : null;

      final records = await _db.getAll(
        limit:        limit.clamp(1, 1000),
        offset:       offset,
        type:         type,
        from:         from,
        to:           to,
        unsyncedOnly: unsynced,
      );
      return _json({
        'count':  records.length,
        'limit':  limit,
        'offset': offset,
        'data':   records.map((r) => r.toJson()).toList(),
      });
    });

    // ── Export CSV ────────────────────────────────────────────────────────────
    r.get('/api/export/csv', (Request req) async {
      final q       = req.url.queryParameters;
      final limit   = int.tryParse(q['limit'] ?? '5000') ?? 5000;
      final from    = q['from'] != null ? DateTime.tryParse(q['from']!) : null;
      final to      = q['to']   != null ? DateTime.tryParse(q['to']!)   : null;
      final records = await _db.getAll(limit: limit, from: from, to: to, type: 'rx');

      final sb = StringBuffer('id,uuid,raw_data,rssi,snr,received_at\n');
      for (final rec in records) {
        final safe = rec.rawData.replaceAll('"', '""');
        sb.writeln('${rec.id},"${rec.uuid}","$safe",${rec.rssi ?? ''},${rec.snr ?? ''},${rec.receivedAt.toIso8601String()}');
      }
      return Response.ok(sb.toString(), headers: {
        'Content-Type':        'text/csv; charset=utf-8',
        'Content-Disposition': 'attachment; filename="lora_data.csv"',
        'Access-Control-Allow-Origin': '*',
      });
    });

    // ── 404 fallback ──────────────────────────────────────────────────────────
    r.all('/<ignored|.*>', (_) => _error('Endpoint tidak ditemukan', 404));

    return r;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  Response _json(dynamic data, [int status = 200]) => Response(
    status,
    body: jsonEncode(data),
    headers: {
      'Content-Type':                'application/json; charset=utf-8',
      'Access-Control-Allow-Origin': '*',
    },
  );

  Response _error(String message, int status) =>
      _json({'error': message, 'status': status}, status);

  // Simple UUID v4 tanpa dependency tambahan
  String _uuid() {
    final r = DateTime.now().microsecondsSinceEpoch;
    return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replaceAllMapped(
      RegExp(r'[xy]'),
      (m) {
        final v = (r ^ (r >> 4)) & 0xf;
        return (m.group(0) == 'x' ? v : (v & 0x3 | 0x8)).toRadixString(16);
      },
    );
  }
}
