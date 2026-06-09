import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:uuid/uuid.dart';
import '../models/lora_record.dart';

enum SerialState { disconnected, connecting, connected, error }

class LoraSerialService {
  SerialPort? _port;
  SerialPortReader? _reader;
  String _buffer = '';
  final _uuid = const Uuid();

  final _packetCtrl = StreamController<LoraRecord>.broadcast();
  final _stateCtrl  = StreamController<SerialState>.broadcast();

  Stream<LoraRecord>  get packetStream => _packetCtrl.stream;
  Stream<SerialState> get stateStream  => _stateCtrl.stream;

  SerialState _state = SerialState.disconnected;
  SerialState get state => _state;

  static List<String> availablePorts() => SerialPort.availablePorts;

  Future<bool> connect({required String portName, int baudRate = 115200}) async {
    _emit(SerialState.connecting);
    try {
      _port = SerialPort(portName);
      if (!_port!.openRead()) {
        _emit(SerialState.error);
        return false;
      }
      final cfg = SerialPortConfig()
        ..baudRate = baudRate
        ..bits     = 8
        ..stopBits = 1
        ..parity   = SerialPortParity.none
        ..setFlowControl(SerialPortFlowControl.none);
      _port!.config = cfg;

      _reader = SerialPortReader(_port!);
      _reader!.stream.listen(_onData, onError: (_) {
        _emit(SerialState.error);
        disconnect();
      });

      _emit(SerialState.connected);
      _packetCtrl.add(_system('Terhubung ke $portName @ $baudRate baud'));
      return true;
    } catch (_) {
      _emit(SerialState.error);
      return false;
    }
  }

  void _onData(Uint8List bytes) {
    _buffer += utf8.decode(bytes, allowMalformed: true);
    int nl;
    while ((nl = _buffer.indexOf('\n')) != -1) {
      final line = _buffer.substring(0, nl).trim();
      _buffer = _buffer.substring(nl + 1);
      if (line.isEmpty) continue;
      _packetCtrl.add(_parseLine(line));
    }
  }

  LoraRecord _parseLine(String line) {
    try {
      final j = jsonDecode(line) as Map<String, dynamic>;
      final t = j['type'] as String? ?? 'unknown';

      // Payload bisa nested di field 'data' sebagai JSON string,
      // atau field sensor langsung di root
      Map<String, dynamic> payload = j;
      final dataField = j['data'];
      if (dataField is String && dataField.trim().startsWith('{')) {
        try {
          payload = {...j, ...jsonDecode(dataField) as Map<String, dynamic>};
        } catch (_) {}
      } else if (dataField is Map<String, dynamic>) {
        payload = {...j, ...dataField};
      }

      final type = switch (t) {
        'rx'    => 'rx',
        'error' => 'error',
        _       => 'system',
      };

      return LoraRecord(
        uuid:           _uuid.v4(),
        rawData:        line,
        parsedData:     dataField is String ? dataField : null,
        rssi:           j['rssi']   as int?,
        snr:            (j['snr']   as num?)?.toDouble(),
        packetType:     type,
        receivedAt:     DateTime.now(),
        trail:          payload['trail']           as String?,
        lat:            (payload['lat']            as num?)?.toDouble(),
        lng:            (payload['lng']            as num?)?.toDouble(),
        suhuAir:        (payload['suhu_air']       as num?)?.toDouble(),
        suhuKelembaban: (payload['suhu_kelembaban'] as num?)?.toDouble(),
        berat:          (payload['berat']          as num?)?.toDouble(),
        interval:       payload['interval']        as int?,
        jenisIkan:      payload['jenis_ikan']      as String?,
        idIkan:         payload['id_ikan']         as int?,
      );
    } catch (_) {
      return _system(line);
    }
  }

  LoraRecord _system(String msg) => LoraRecord(
        uuid:       _uuid.v4(),
        rawData:    msg,
        packetType: 'system',
        receivedAt: DateTime.now(),
      );

  void disconnect() {
    _reader?.close();
    _port?.close();
    _port?.dispose();
    _port   = null;
    _reader = null;
    _buffer = '';
    _emit(SerialState.disconnected);
  }

  void _emit(SerialState s) {
    _state = s;
    _stateCtrl.add(s);
  }

  void dispose() {
    disconnect();
    _packetCtrl.close();
    _stateCtrl.close();
  }
}
