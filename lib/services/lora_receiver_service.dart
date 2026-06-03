import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import '../models/lora_packet.dart';

enum SerialState { disconnected, connecting, connected, error }

class LoraReceiverService {
  SerialPort? _port;
  SerialPortReader? _reader;
  String _buffer = '';

  final _packetCtrl = StreamController<LoraPacket>.broadcast();
  final _stateCtrl  = StreamController<SerialState>.broadcast();

  Stream<LoraPacket> get packetStream => _packetCtrl.stream;
  Stream<SerialState> get stateStream  => _stateCtrl.stream;

  SerialState _state = SerialState.disconnected;
  SerialState get state => _state;

  static List<String> availablePorts() => SerialPort.availablePorts;

  Future<bool> connect(String portName, {int baudRate = 115200}) async {
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
      _packetCtrl.add(LoraPacket.system('Terhubung ke $portName @ $baudRate baud'));
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
      try {
        final json = jsonDecode(line) as Map<String, dynamic>;
        _packetCtrl.add(LoraPacket.fromJson(json, line));
      } catch (_) {
        _packetCtrl.add(LoraPacket.system(line));
      }
    }
  }

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
