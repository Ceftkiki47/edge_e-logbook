import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import '../models/lora_packet.dart';

enum LoraConnectionState { disconnected, connecting, connected, error }

class Esp32LoraService {
  SerialPort? _port;
  SerialPortReader? _reader;
  String _buffer = '';

  final _packetCtrl = StreamController<LoraPacket>.broadcast();
  final _stateCtrl = StreamController<LoraConnectionState>.broadcast();

  Stream<LoraPacket> get packetStream => _packetCtrl.stream;
  Stream<LoraConnectionState> get stateStream => _stateCtrl.stream;

  LoraConnectionState _state = LoraConnectionState.disconnected;
  LoraConnectionState get state => _state;

  static List<String> availablePorts() => SerialPort.availablePorts;

  Future<bool> connect(String portName, {int baudRate = 115200}) async {
    _emit(LoraConnectionState.connecting);
    try {
      _port = SerialPort(portName);
      if (!_port!.openReadWrite()) {
        _emit(LoraConnectionState.error);
        return false;
      }
      final cfg = SerialPortConfig()
        ..baudRate = baudRate
        ..bits = 8
        ..stopBits = 1
        ..parity = SerialPortParity.none
        ..setFlowControl(SerialPortFlowControl.none);
      _port!.config = cfg;

      _reader = SerialPortReader(_port!);
      _reader!.stream.listen(_onData, onError: (_) {
        _emit(LoraConnectionState.error);
        disconnect();
      });

      _emit(LoraConnectionState.connected);
      _packetCtrl.add(LoraPacket.system('Terhubung ke $portName @ $baudRate'));
      return true;
    } catch (e) {
      _emit(LoraConnectionState.error);
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
      try {
        final json = jsonDecode(line) as Map<String, dynamic>;
        _packetCtrl.add(LoraPacket.fromJson(json, line));
      } catch (_) {
        _packetCtrl.add(LoraPacket.system(line));
      }
    }
  }

  Future<void> sendJson(Map<String, dynamic> payload) async {
    if (_port == null || !_port!.isOpen) return;
    _port!.write(Uint8List.fromList(utf8.encode('${jsonEncode(payload)}\n')));
  }

  Future<void> sendLoraData(String data) => sendJson({'type': 'send', 'data': data});
  Future<void> ping() => sendJson({'type': 'ping'});
  Future<void> setSpreadingFactor(int sf) => sendJson({'type': 'set_sf', 'value': sf});
  Future<void> setTxPower(int dbm) => sendJson({'type': 'set_power', 'value': dbm});

  void disconnect() {
    _reader?.close();
    _port?.close();
    _port?.dispose();
    _port = null;
    _reader = null;
    _buffer = '';
    _emit(LoraConnectionState.disconnected);
  }

  void _emit(LoraConnectionState s) {
    _state = s;
    _stateCtrl.add(s);
  }

  void dispose() {
    disconnect();
    _packetCtrl.close();
    _stateCtrl.close();
  }
}
