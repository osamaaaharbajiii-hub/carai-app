import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class ObdService {
  final BluetoothDevice device;
  BluetoothCharacteristic? _writeCharacteristic;
  BluetoothCharacteristic? _notifyCharacteristic;
  StreamSubscription? _notifySubscription;

  ObdService(this.device);

  // تهيئة الخدمة واكتشاف خصائص التوصيل
  Future<bool> initialize() async {
    try {
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

      if (_writeCharacteristic != null && _notifyCharacteristic != null) {
        await _notifyCharacteristic!.setNotifyValue(true);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // إرسال أمر OBD (مثل 010C للـ RPM أو 03 للأعطال)
  Future<String> sendCommand(String command) async {
    if (_writeCharacteristic == null || _notifyCharacteristic == null) {
      return 'Error: Not connected';
    }

    Completer<String> completer = Completer<String>();
    StringBuffer responseBuffer = StringBuffer();

    _notifySubscription?.cancel();
    _notifySubscription = _notifyCharacteristic!.lastValueStream.listen((value) {
      String data = utf8.decode(value, allowMalformed: true);
      responseBuffer.write(data);
      if (data.contains('>')) { // علامة انتهاء الاستجابة في محولات ELM327
        if (!completer.isCompleted) {
          completer.complete(responseBuffer.toString().replaceAll('>', '').trim());
        }
      }
    });

    // إرسال الأمر مع إلحاق Carriage Return (\r)
    List<int> bytes = utf8.encode('$command\r');
    await _writeCharacteristic!.write(bytes, withoutResponse: _writeCharacteristic!.properties.writeWithoutResponse);

    return completer.future.timeout(
      const Duration(seconds: 4),
      onTimeout: () => 'Timeout: No response from ECU',
    );
  }

  // تهيئة قطعة الـ OBD2 بأوامر AT الأساسية
  Future<void> setupAdapter() async {
    await sendCommand('AT Z');  // Reset
    await sendCommand('AT E0'); // Echo Off
    await sendCommand('AT SP 0'); // Auto Protocol Detection
  }

  // قراءة أكواد الأعطال المخزنة (DTC)
  Future<List<String>> readDtcCodes() async {
    String rawData = await sendCommand('03');
    if (rawData.contains('NO SCAN') || rawData.contains('43 00')) {
      return [];
    }
    // تحليل بسيط للاستجابة المرجعة
    return [rawData];
  }

  // مسح لمبة المحرك والأعطال
  Future<String> clearDtcCodes() async {
    return await sendCommand('04');
  }

  void dispose() {
    _notifySubscription?.cancel();
  }
}
