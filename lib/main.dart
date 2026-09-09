import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const UltraCarAIApp());
}

class UltraCarAIApp extends StatelessWidget {
  const UltraCarAIApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CarAI Super Diagnostic',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        primaryColor: Colors.blueAccent,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E293B),
          elevation: 0,
        ),
      ),
      home: const MainDashboard(),
    );
  }
}

class MainDashboard extends StatefulWidget {
  const MainDashboard({super.key});

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  BluetoothConnection? connection;
  bool isConnected = false;
  List<BluetoothDevice> devicesList = [];
  BluetoothDevice? selectedDevice;
  
  String liveObdData = "انتظار الاتصال...";
  String aiResponse = "أهلاً بك! قم بالاتصال بالمركبة لبدء التشخيص الذكي.";

  // Hybrid Data
  double soh = 92.5;
  double cellImbalance = 0.012;
  double internalResistance = 14.2;

  // Tesla CAN Data
  double batteryPackTemp = 32.4;
  double maxCellVoltage = 4.18;
  double minCellVoltage = 4.16;

  @override
  void initState() {
    super.initState();
    _getBluetoothDevices();
  }

  Future<void> _getBluetoothDevices() async {
    try {
      List<BluetoothDevice> devices = await FlutterBluetoothSerial.instance.getBondedDevices();
      setState(() {
        devicesList = devices;
      });
    } catch (e) {
      debugPrint("Error fetching devices: $e");
    }
  }

  Future<void> _connectToOBD(BluetoothDevice device) async {
    try {
      BluetoothConnection conn = await BluetoothConnection.toAddress(device.address);
      setState(() {
        connection = conn;
        isConnected = true;
        selectedDevice = device;
        liveObdData = "تم الاتصال بنجاح بـ ${device.name}";
      });
    } catch (e) {
      setState(() {
        liveObdData = "فشل الاتصال بالأداة: $e";
      });
    }
  }

  void _sendObdCommand(String command) {
    if (connection != null && connection!.isConnected) {
      connection!.output.add(Uint8List.fromList(utf8.encode("$command\r")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 7,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("CarAI Super App"),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(icon: Icon(Icons.speed), text: "اللوحة الرئيسية"),
              Tab(icon: Icon(Icons.memory), text: "تشخيص OBD-II"),
              Tab(icon: Icon(Icons.battery_full), text: "فحص الهايبرد Hybrid"),
              Tab(icon: Icon(Icons.electric_car), text: "تشخيص التسلا Tesla"),
              Tab(icon: Icon(Icons.terminal), text: "البرمجة والتكوين"),
              Tab(icon: Icon(Icons.vpn_key), text: "برمجة المفاتيح"),
              Tab(icon: Icon(Icons.smart_toy), text: "المساعد الذكي AI"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildOverviewTab(),
            _buildObdTab(),
            _buildHybridTab(),
            _buildTeslaTab(),
            _buildCodingTab(),
            _buildKeyTab(),
            _buildAiTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            color: const Color(0xFF1E293B),
            child: ListTile(
              title: Text(isConnected ? "متصل: ${selectedDevice?.name}" : "غير متصل بأي أداة"),
              subtitle: Text(liveObdData),
              trailing: Icon(
                isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                color: isConnected ? Colors.green : Colors.red,
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text("الأجهزة المقترنة:", style: TextStyle(fontWeight: FontWeight.bold)),
          Expanded(
            child: ListView.builder(
              itemCount: devicesList.length,
              itemBuilder: (context, index) {
                final dev = devicesList[index];
                return ListTile(
                  title: Text(dev.name ?? "دستگاه ناشناس"),
                  subtitle: Text(dev.address),
                  onTap: () => _connectToOBD(dev),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildObdTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton(
            onPressed: () => _sendObdCommand("010C"),
            child: const Text("قراءة دورات المحرك RPM (010C)"),
          ),
          ElevatedButton(
            onPressed: () => _sendObdCommand("03"),
            child: const Text("قراءة أسطر الأخطاء DTCs (03)"),
          ),
        ],
      ),
    );
  }

  Widget _buildHybridTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          _buildInfoTile("صحة البطارية (SOH)", "$soh %", Colors.green),
          _buildInfoTile("فرق الجهد بين الخلايا", "$cellImbalance V", Colors.amber),
          _buildInfoTile("المقاومة الداخلية", "$internalResistance mΩ", Colors.blue),
        ],
      ),
    );
  }

  Widget _buildTeslaTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          _buildInfoTile("حرارة البطارية", "$batteryPackTemp °C", Colors.orange),
          _buildInfoTile("أعلى جهد خلية", "$maxCellVoltage V", Colors.green),
          _buildInfoTile("أدنى جهد خلية", "$minCellVoltage V", Colors.green),
        ],
      ),
    );
  }

  Widget _buildCodingTab() {
    return const Center(child: Text("وحدة البرمجة والتكوين 1-Click Coding (VAG / BMW)"));
  }

  Widget _buildKeyTab() {
    return const Center(child: Text("وحدة برمجة المفاتيح وقراءة PIN Code"));
  }

  Widget _buildAiTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SingleChildScrollView(child: Text(aiResponse)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile(String title, String value, Color color) {
    return Card(
      child: ListTile(
        title: Text(title),
        trailing: Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
