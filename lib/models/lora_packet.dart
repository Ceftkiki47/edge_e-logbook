enum PacketType { rx, txAck, pong, status, error, unknown }

class LoraPacket {
  final PacketType type;
  final String? data;
  final int? rssi;
  final double? snr;
  final bool? ok;
  final String? msg;
  final DateTime timestamp;
  final String raw;

  LoraPacket({
    required this.type,
    required this.raw,
    this.data,
    this.rssi,
    this.snr,
    this.ok,
    this.msg,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory LoraPacket.fromJson(Map<String, dynamic> j, String raw) {
    final t = j['type'] as String? ?? '';
    final type = switch (t) {
      'rx'     => PacketType.rx,
      'tx_ack' => PacketType.txAck,
      'pong'   => PacketType.pong,
      'status' => PacketType.status,
      'error'  => PacketType.error,
      _        => PacketType.unknown,
    };
    return LoraPacket(
      type: type,
      raw:  raw,
      data: j['data'] as String?,
      rssi: j['rssi'] as int?,
      snr:  (j['snr'] as num?)?.toDouble(),
      ok:   j['ok'] as bool?,
      msg:  j['msg'] as String?,
    );
  }

  factory LoraPacket.system(String message) => LoraPacket(
        type: PacketType.status,
        raw:  message,
        msg:  message,
      );

  String get tagLabel => switch (type) {
        PacketType.rx      => 'RX',
        PacketType.error   => 'ERR',
        PacketType.txAck   => 'TX',
        PacketType.pong    => 'PONG',
        _                  => 'SYS',
      };

  String get displayData => data ?? msg ?? raw;

  bool get hasSignal => rssi != null && snr != null;
}
