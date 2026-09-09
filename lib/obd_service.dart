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

  // 1. خوارزمية طلب الأذونات وتهيئة الاتصال
  Future<bool> initialize() async {
    try {
      // طلب أذونات البلوتوث والموقع وقت التشغيل لتفادي خطأ PlatformException
      Map<Permission, PermissionStatus> permissions = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.location,
      ].request();

      if (permissions[Permission.bluetoothConnect] != PermissionStatus.granted) {
        print("Bluetooth permissions not granted.");
        return false;
      }

      // الاتصال بالجهاز
      await device.connect(autoConnect: false);

      // اكتشاف الخدمات والخصائص (Services & Characteristics)
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

      // تفعيل الاستماع للردود (Notify)
      if (_notifyCharacteristic != null) {
        await _notifyCharacteristic!.setNotifyValue(true);
      }

      // تهيئة قطعة ELM327 بإرسال أوامر AT الأساسية
      await sendCommand('AT Z');  // Reset
      await sendCommand('AT SP 0'); // Auto Detect Protocol
      
      return true;
    } catch (e) {
      print("Error initializing OBD connection: $e");
      return false;
    }
  }

  // 2. خوارزمية إرسال الأوامر للسيارة واستقبال الرد
  Future<String> sendCommand(String command) async {
    if (_writeCharacteristic == null || _notifyCharacteristic == null) {
      return "Error: Characteristics not configured";
    }

    Completer<String> completer = Completer<String>();
    StringBuffer responseBuffer = StringBuffer();

    // الاستماع للبيانات القادمة من قطعة OBD
    _notifySubscription = _notifyCharacteristic!.lastValueStream.listen((data) {
      String responseChunk = utf8.decode(data, allowMalformed: true);
      responseBuffer.write(responseChunk);

      // تنتهي استجابة ELM327 دائماً بظهور رمز '>'
      if (responseBuffer.toString().contains('>')) {
        _notifySubscription?.cancel();
        completer.complete(responseBuffer.toString().replaceAll('>', '').trim());
      }
    });

    // إرسال الأمر مع إضافة سطر جديد \r (ضروري لقطعة ELM327)
    List<int> bytes = utf8.encode("$command\r");
    await _writeCharacteristic!.write(bytes, withoutResponse: false);

    // مهلة زمنية 5 ثوانٍ للرد
    return completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        _notifySubscription?.cancel();
        return "Error: Command Timeout";
      },
    );
  }

  // 3. إنهاء الاتصال
  Future<void> disconnect() async {
    await _notifySubscription?.cancel();
    await device.disconnect();
  }
}
