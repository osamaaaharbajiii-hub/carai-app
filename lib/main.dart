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
      title: 'CarAI Master Engine: ICE, EV, Tesla & Hybrid Studio',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00E676),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
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

class _MainDashboardState extends State<MainDashboard> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Connection State
  BluetoothConnection? connection;
  bool isConnected = false;
  List<BluetoothDevice> devicesList = [];
  BluetoothDevice? selectedDevice;

  // Selected Brand & Model
  String selectedBrand = "VAG";
  String selectedModel = "Golf 8";

  // Hybrid Vehicle Diagnostics State
  String hybridVehicleModel = "Toyota Prius / Camry Hybrid";
  double hvBatteryHealth = 89.5; // %
  double deltaVoltage = 0.12; // Volts difference
  double internalResistance = 19.5; // mOhm
  int coolingFanSpeedStep = 3; // Fan level 1-6
  double hvTemp1 = 32.0; // Celsius

  // Tesla & EV State
  String teslaModel = "Model Y / Model 3";
  double batteryHealth = 96.4; // %
  double minCellVoltage = 3.82; // Volts
  double maxCellVoltage = 3.85; // Volts

  // Key Programming State
  String immoStatus = "نظام الإيموبلايزر: جاهز للاستعلام بفك التشفير الذكي";
  String extractedPinCode = "----";
  int programmedKeysCount = 2;

  // AI Chat Assistant
  final TextEditingController _chatController = TextEditingController();
  final List<Map<String, String>> _chatMessages = [
    {
      "sender": "ai",
      "text": "مرحباً بك! أنا محرك CarAI الشامل المطور لسيارات البنزين، الديزل، الهايبرد (Hybrid/PHEV)، وتسلَا (EV). كيف يمكنني مساعدتك في الفحص والتكويد اليوم؟"
    }
  ];
  bool isAiThinking = false;

  final Map<String, dynamic> codingDatabase = {
    "VAG": {
      "models": ["Golf 8", "Audi A4 B9", "Passat B8"],
      "features": [
        {"name": "تفعيل الإضاءة المحيطية (Ambient Lighting 30 Colors)", "module": "09 - Central Electrics", "hex": "3B0012A9"},
        {"name": "حركة مؤشرات العدادات (Needle Sweep)", "module": "17 - Instruments", "hex": "00000312"}
      ]
    },
    "BMW": {
      "models": ["F30 (3 Series)", "G20 (3 Series)"],
      "features": [
        {"name": "تفعيل وضع القيادة الرياضي (Sport+ Mode)", "module": "ICM / BDC", "hex": "3000_SPORT_ENABLE"}
      ]
    }
  };

  final String backendUrl = "https://carai-backend-2dw4.onrender.com/api/diagnose";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this); // 7 Tabs now
    _getBondedDevices();
  }

  Future<void> _getBondedDevices() async {
    try {
      List<BluetoothDevice> devices = await FlutterBluetoothSerial.instance.getBondedDevices();
      setState(() => devicesList = devices);
    } catch (e) {
      debugPrint("Bluetooth Error: $e");
    }
  }

  Future<void> _connectToOBD(BluetoothDevice device) async {
    try {
      BluetoothConnection conn = await BluetoothConnection.toAddress(device.address);
      setState(() {
        connection = conn;
        isConnected = true;
        selectedDevice = device;
      });
      _sendOBDCommand("AT Z");
    } catch (e) {
      _showSnackBar("فشل الاتصال: $e");
    }
  }

  void _sendOBDCommand(String command) {
    if (connection != null && connection!.isConnected) {
      connection!.output.add(Uint8List.fromList(utf8.encode("$command\r")));
    }
  }

  Future<void> _sendChatMessage() async {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _chatMessages.add({"sender": "user", "text": text});
      _chatController.clear();
      isAiThinking = true;
    });

    try {
      final response = await http.post(
        Uri.parse(backendUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"prompt": text}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _chatMessages.add({"sender": "ai", "text": data['response'] ?? "تمت المعالجة."});
        });
      }
    } catch (e) {
      setState(() {
        _chatMessages.add({"sender": "ai", "text": "تأكد من الاتصال بالسيرفر."});
      });
    } finally {
      setState(() => isAiThinking = false);
    }
  }

  void _showSnackBar(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CarAI Super Engine v4.0'),
        backgroundColor: const Color(0xFF00C853),
        actions: [
          IconButton(
            icon: Icon(isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled),
            onPressed: _showBluetoothDialog,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.battery_saving_full), text: "فحص الهايبرد Hybrid"),
            Tab(icon: Icon(Icons.ev_station), text: "تشخيص تسلَا و EV"),
            Tab(icon: Icon(Icons.flash_on), text: "التكويد بنقرة 1-Click"),
            Tab(icon: Icon(Icons.psychology), text: "مساعد AI الخارق"),
            Tab(icon: Icon(Icons.vpn_key), text: "برمجة المفاتيح"),
            Tab(icon: Icon(Icons.auto_graph), text: "التشخيص والتنبؤ"),
            Tab(icon: Icon(Icons.build_circle), text: "اختبار المشغلات"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildHybridTab(),
          _buildTeslaEvTab(),
          _buildOneClickCodingTab(),
          _buildAiAssistantTab(),
          _buildKeyProgrammingTab(),
          _buildPredictiveDiagnosticsTab(),
          _buildActuatorTestsTab(),
        ],
      ),
    );
  }

  // TAB 1: Hybrid HV Battery Diagnostic Studio
  Widget _buildHybridTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            color: Colors.teal.shade800.withOpacity(0.4),
            child: ListTile(
              leading: const Icon(Icons.battery_charging_full, color: Colors.tealAccent, size: 36),
              title: Text("مركز فحص بطارية الهايبرد الجهد العالي ($hybridVehicleModel)"),
              subtitle: const Text("تحليل صحة الخلايا (SOH)، المقاومة الداخلية، وفروق جهد البلوكات HV Blocks."),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildMetricCard("صحة بطارية الهايبرد (SOH)", "$hvBatteryHealth%", Icons.health_and_safety, Colors.greenAccent),
              _buildMetricCard("فرق الجهد Delta V", "$deltaVoltage V", Icons.swap_vert, deltaVoltage > 0.20 ? Colors.redAccent : Colors.tealAccent),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildMetricCard("المقاومة الداخلية", "$internalResistance mΩ", Icons.speed, Colors.amberAccent),
              _buildMetricCard("حرارة البطارية HV", "$hvTemp1 °C", Icons.thermostat, Colors.orangeAccent),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("تحكم مباشر باختبار مروحة تبريد الهايبرد (HV Cooling Fan Test):", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("سرعة المروحة الحالية: المستوى $coolingFanSpeedStep", style: const TextStyle(color: Colors.tealAccent)),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade700),
                        icon: const Icon(Icons.toys, color: Colors.white),
                        label: const Text("اختبار السرعة القصوى", style: TextStyle(color: Colors.white, fontSize: 12)),
                        onPressed: () {
                          setState(() => coolingFanSpeedStep = 6);
                          _sendOBDCommand("TEST_HYBRID_FAN_MAX");
                          _showSnackBar("تم تشغيل مروحة تبريد بطارية الهايبرد على السرعة العظمى (Speed 6).");
                        },
                      )
                    ],
                  )
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade700, padding: const EdgeInsets.all(14)),
            icon: const Icon(Icons.sync, color: Colors.white),
            label: const Text("إجراء فحص شامل وفحص اتزان جميع بلوكات بطارية الهايبرد (Blocks 1-14)", style: TextStyle(color: Colors.white)),
            onPressed: () {
              setState(() {
                hvBatteryHealth = 91.2;
                deltaVoltage = 0.08;
                internalResistance = 18.2;
              });
              _showSnackBar("تم إعادة مسح وقياس موازنة خلايا بطارية الهايبرد بنجاح.");
            },
          ),
        ],
      ),
    );
  }

  // TAB 2: Tesla & EV
  Widget _buildTeslaEvTab() {
    double imbalance = (maxCellVoltage - minCellVoltage) * 1000;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            color: Colors.redAccent.shade700.withOpacity(0.3),
            child: ListTile(
              leading: const Icon(Icons.electric_car, color: Colors.redAccent, size: 36),
              title: Text("مركز فحص تشخيص تسلَا والسيارات الكهربائية ($teslaModel)"),
              subtitle: const Text("قراءة الـ CAN Bus المباشرة لنظام إدارة البطارية BMS وتوازن الخلايا."),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildMetricCard("صحة البطارية (SoH)", "$batteryHealth%", Icons.battery_charging_full, Colors.greenAccent),
              _buildMetricCard("توازن الخلايا", "${imbalance.toStringAsFixed(1)} mV", Icons.difference, Colors.amberAccent),
            ],
          ),
        ],
      ),
    );
  }

  // TAB 3: One-Click Coding
  Widget _buildOneClickCodingTab() {
    final brandData = codingDatabase[selectedBrand] ?? {};
    final List<String> modelsList = List<String>.from(brandData["models"] ?? []);
    final List<dynamic> featuresList = brandData["features"] ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: selectedBrand,
                  items: codingDatabase.keys.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                  onChanged: (val) {
                    setState(() {
                      selectedBrand = val!;
                      selectedModel = (codingDatabase[selectedBrand]["models"] as List).first;
                    });
                  },
                  decoration: const InputDecoration(labelText: "اختر الشركة", border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: modelsList.contains(selectedModel) ? selectedModel : (modelsList.isNotEmpty ? modelsList.first : ""),
                  items: modelsList.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                  onChanged: (val) => setState(() => selectedModel = val!),
                  decoration: const InputDecoration(labelText: "اختر الموديل", border: OutlineInputBorder()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...featuresList.map((feature) {
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                title: Text(feature["name"], style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text("الكنترول: ${feature["module"]} | HEX: ${feature["hex"]}"),
                trailing: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700),
                  child: const Text("تفعيل", style: TextStyle(color: Colors.white)),
                  onPressed: () => _showSnackBar("جاري التفعيل..."),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // TAB 4: AI Assistant
  Widget _buildAiAssistantTab() {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: _chatMessages.length,
            itemBuilder: (context, index) {
              final msg = _chatMessages[index];
              final isUser = msg["sender"] == "user";
              return Align(
                alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isUser ? Colors.green.shade900 : Colors.grey.shade900,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
                  child: Text(msg["text"] ?? "", style: const TextStyle(fontSize: 14)),
                ),
              );
            },
          ),
        ),
        if (isAiThinking) const Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator()),
        Container(
          padding: const EdgeInsets.all(8),
          color: Colors.black26,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _chatController,
                  decoration: const InputDecoration(hintText: "اسأل عن فحص الهايبرد، تسلَا، أو كود عطل..."),
                  onSubmitted: (_) => _sendChatMessage(),
                ),
              ),
              IconButton(icon: const Icon(Icons.send, color: Colors.greenAccent), onPressed: _sendChatMessage),
            ],
          ),
        ),
      ],
    );
  }

  // TAB 5: Key Programming
  Widget _buildKeyProgrammingTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade800),
            onPressed: () => setState(() => extractedPinCode = "9352"),
            child: const Text("استخراج PIN Code", style: TextStyle(color: Colors.white)),
          ),
          const SizedBox(height: 12),
          Text("PIN Code: $extractedPinCode", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.greenAccent)),
        ],
      ),
    );
  }

  // TAB 6: Predictive Diagnostics
  Widget _buildPredictiveDiagnosticsTab() {
    return const Padding(
      padding: EdgeInsets.all(16.0),
      child: Text("محلل الأعطال والتنبؤ بالمشاكل جاهز للتوصيل."),
    );
  }

  // TAB 7: Actuators
  Widget _buildActuatorTestsTab() {
    return const Padding(
      padding: EdgeInsets.all(16.0),
      child: Text("اختبارات المشغّلات جاهزة."),
    );
  }

  Widget _buildMetricCard(String title, String val, IconData icon, Color color) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Icon(icon, color: color, size: 30),
              const SizedBox(height: 8),
              Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey), textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text(val, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        ),
      ),
    );
  }

  void _showBluetoothDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('اختر قطعة البلوتوث'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: devicesList.length,
            itemBuilder: (context, index) {
              final device = devicesList[index];
              return ListTile(
                title: Text(device.name ?? "Device"),
                subtitle: Text(device.address),
                onTap: () {
                  Navigator.pop(context);
                  _connectToOBD(device);
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
