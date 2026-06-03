import 'dart:convert';

class LoraRecord {
  final int?    id;
  final String  uuid;
  final String  rawData;
  final String? parsedData;
  final int?    rssi;
  final double? snr;
  final String  packetType;
  final DateTime receivedAt;
  final bool    syncedToApi;

  // ── Field sensor spesifik ─────────────────────────────────────────────────
  final String? trail;
  final double? lat;
  final double? lng;
  final double? suhuAir;
  final double? suhuKelembaban;
  final double? berat;
  final int?    interval;

  const LoraRecord({
    this.id,
    required this.uuid,
    required this.rawData,
    this.parsedData,
    this.rssi,
    this.snr,
    required this.packetType,
    required this.receivedAt,
    this.syncedToApi     = false,
    this.trail,
    this.lat,
    this.lng,
    this.suhuAir,
    this.suhuKelembaban,
    this.berat,
    this.interval,
  });

  // ── SQLite ────────────────────────────────────────────────────────────────
  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'uuid':             uuid,
    'raw_data':         rawData,
    'parsed_data':      parsedData,
    'rssi':             rssi,
    'snr':              snr,
    'packet_type':      packetType,
    'received_at':      receivedAt.toIso8601String(),
    'synced':           syncedToApi ? 1 : 0,
    'trail':            trail,
    'lat':              lat,
    'lng':              lng,
    'suhu_air':         suhuAir,
    'suhu_kelembaban':  suhuKelembaban,
    'berat':            berat,
    'interval':         interval,
  };

  factory LoraRecord.fromMap(Map<String, dynamic> m) => LoraRecord(
    id:             m['id']             as int?,
    uuid:           m['uuid']           as String,
    rawData:        m['raw_data']       as String,
    parsedData:     m['parsed_data']    as String?,
    rssi:           m['rssi']           as int?,
    snr:            (m['snr']           as num?)?.toDouble(),
    packetType:     m['packet_type']    as String,
    receivedAt:     DateTime.parse(m['received_at'] as String),
    syncedToApi:    (m['synced']        as int? ?? 0) == 1,
    trail:          m['trail']          as String?,
    lat:            (m['lat']           as num?)?.toDouble(),
    lng:            (m['lng']           as num?)?.toDouble(),
    suhuAir:        (m['suhu_air']      as num?)?.toDouble(),
    suhuKelembaban: (m['suhu_kelembaban'] as num?)?.toDouble(),
    berat:          (m['berat']         as num?)?.toDouble(),
    interval:       m['interval']       as int?,
  );

  // ── REST API ──────────────────────────────────────────────────────────────
  Map<String, dynamic> toJson() => {
    'id':               id,
    'uuid':             uuid,
    'raw_data':         rawData,
    'parsed_data':      parsedData != null ? _tryDecode(parsedData!) : null,
    'rssi':             rssi,
    'snr':              snr,
    'packet_type':      packetType,
    'received_at':      receivedAt.toIso8601String(),
    'synced':           syncedToApi,
    'trail':            trail,
    'lat':              lat,
    'lng':              lng,
    'suhu_air':         suhuAir,
    'suhu_kelembaban':  suhuKelembaban,
    'berat':            berat,
    'interval':         interval,
  };

  static dynamic _tryDecode(String s) {
    try { return jsonDecode(s); } catch (_) { return s; }
  }

  LoraRecord copyWith({bool? syncedToApi, int? id}) => LoraRecord(
    id:             id             ?? this.id,
    uuid:           uuid,
    rawData:        rawData,
    parsedData:     parsedData,
    rssi:           rssi,
    snr:            snr,
    packetType:     packetType,
    receivedAt:     receivedAt,
    syncedToApi:    syncedToApi    ?? this.syncedToApi,
    trail:          trail,
    lat:            lat,
    lng:            lng,
    suhuAir:        suhuAir,
    suhuKelembaban: suhuKelembaban,
    berat:          berat,
    interval:       interval,
  );
}

class LoraStats {
  final int      totalPackets;
  final int      rxPackets;
  final int      errorPackets;
  final int      unsyncedCount;
  final int?     lastRssi;
  final double?  lastSnr;
  final DateTime? firstRecord;
  final DateTime? lastRecord;

  const LoraStats({
    required this.totalPackets,
    required this.rxPackets,
    required this.errorPackets,
    required this.unsyncedCount,
    this.lastRssi,
    this.lastSnr,
    this.firstRecord,
    this.lastRecord,
  });

  Map<String, dynamic> toJson() => {
    'total_packets':  totalPackets,
    'rx_packets':     rxPackets,
    'error_packets':  errorPackets,
    'unsynced_count': unsyncedCount,
    'last_rssi':      lastRssi,
    'last_snr':       lastSnr,
    'first_record':   firstRecord?.toIso8601String(),
    'last_record':    lastRecord?.toIso8601String(),
  };
}
