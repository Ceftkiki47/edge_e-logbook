import 'package:flutter_libserialport/flutter_libserialport.dart';

void main() {
  print('Available ports:');
  for (var name in SerialPort.availablePorts) {
    final sp = SerialPort(name);
    print('Port: $name');
    print('  Desc: ${sp.description}');
    print('  Manufacturer: ${sp.manufacturer}');
    print('  Product: ${sp.productName}');
    print('  VendorID: ${sp.vendorId}');
    print('  ProductID: ${sp.productId}');
    sp.dispose();
  }
}
