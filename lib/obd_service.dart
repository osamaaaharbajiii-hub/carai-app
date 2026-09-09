import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class ObdService {
  final BluetoothDevice device;
  BluetoothCharacteristic? _writeCharacteristic;
  BluetoothCharacteristic? _notifyCharacteristic;
  StreamSubscription? _notifySubscription;

  ObdService(this.device);

  // 1. تهيئة الاتصال والأذونات
  Future<bool> initialize() async {
    try {
      Map<Permission, PermissionStatus> permissions = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.location,
      ].request();

      if (permissions[Permission.bluetoothConnect] != PermissionStatus.granted) {
        return false;
      }

      await device.connect(autoConnect: false);

      List<BluetoothService> services = await device.discoverServices();
      for (var service in services) {
        for (var char in service.characteristics) {
          if (char.properties.write || char.properties.writeWithoutResponse) {
            _writeCharacteristic = char;
          }
          if (char.properties.notify || char.properties.indicate) {
            _notifyCharacteristic = char;
          }
        }
      }

      if (_notifyCharacteristic != null) {
        await _notifyCharacteristic!.setNotifyValue(true);
      }

      return await setupAdapter();
    } catch (e) {
      print("Error initializing OBD connection: $e");
      return false;
    }
  }

  // 2. دالة تهيئة المحول (setupAdapter)
  Future<bool> setupAdapter() async {
    try {
      await sendCommand('AT Z');   // Reset ELM327
      await sendCommand('AT E0');  // Echo Off
      await sendCommand('AT L0');  // Linefeeds Off
      await sendCommand('AT SP 0'); // Auto Protocol Detect
      return true;
    } catch (e) {
      return false;
    }
  }

  // 3. دالة قراءة أعطال السيارة (readDtcCodes)
  Future<List<String>> readDtcCodes() async {
    try {
      // 03 هو أمر OBD-II القياسي لقراءة أكواد الأعطال (DTCs)
      String response = await sendCommand('03');
      
      if (response.contains('NO DATA') || response.contains('ERROR')) {
        return [];
      }

      List<String> codes = [];
      // تحليل استجابة الأعطال وتنظيف السلاسل النصية
      List<String> lines = response.split('\r');
      for (var line in lines) {
        String cleanLine = line.replaceAll(' ', '').trim();
        if (cleanLine.startsWith('43')) {
          // استخراج الأكواد من السلسلة الهكس
          String hexData = cleanLine.substring(2);
          for (int i = 0; i < hexData.length - 3; i += 4) {
            String codeHex = hexData.substring(i, i + 4);
            if (codeHex != '0000') {
              codes.add('P$codeHex');
            }
          }
        }
      }
      return codes.isEmpty ? ['P0000 (No DTCs Found)'] : codes;
    } catch (e) {
      return ['Error reading DTCs: $e'];
    }
  }

  // 4. خوارزمية إرسال الأوامر للسيارة
  Future<String> sendCommand(String command) async {
    if (_writeCharacteristic == null || _notifyCharacteristic == null) {
      return "Error: Characteristics not configured";
    }

    Completer<String> completer = Completer<String>();
    StringBuffer responseBuffer = StringBuffer();

    _notifySubscription = _notifyCharacteristic!.lastValueStream.listen((data) {
      String responseChunk = utf8.decode(data, allowMalformed: true);
      responseBuffer.write(responseChunk);

      if (responseBuffer.toString().contains('>')) {
        _notifySubscription?.cancel();
        completer.complete(responseBuffer.toString().replaceAll('>', '').trim());
      }
    });

    List<int> bytes = utf8.encode("$command\r");
    await _writeCharacteristic!.write(bytes, withoutResponse: false);

    return completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        _notifySubscription?.cancel();
        return "Error: Command Timeout";
      },
    );
  }

  // 5. دالة التخلص من الموارد وإنهاء الاتصال (dispose)
  void dispose() {
    disconnect();
  }

  Future<void> disconnect() async {
    await _notifySubscription?.cancel();
    await device.disconnect();
  }
}
