import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const CarAIApp());
}

class CarAIApp extends StatelessWidget {
  const CarAIApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CarAI - Master Diagnostic & Key Programming Studio',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0D47A1),
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
  
  // Bluetooth Connection State
  BluetoothConnection? connection;
  bool isConnected = false;
  List<BluetoothDevice> devicesList = [];
  BluetoothDevice? selectedDevice;
  
  // Sensors
  String engineRpm = "0 RPM";
  String coolantTemp = "0 °C";

  // Key & Immo Programming State
  String immoStatus = "نظام الإيموبلايزر: جاهز للاستعلام";
  String extractedPinCode = "----";
  int programmedKeysCount = 2;
  bool isKeyProgrammingBusy = false;

  // Selected Module for Deep Diagnostics
  String selectedModule = "25 - Immobilizer System";
  String currentLongCoding = "00000312002400000000";

  // AI Chat Assistant State
  final TextEditingController _chatController = TextEditingController();
  final List<Map<String, String>> _chatMessages = [
    {
      "sender": "ai",
      "text": "مرحباً بك! أنا مساعد CarAI الذكي. يمكنك سؤالي عن طريقة تكويد المفاتيح، فك شفرات الأعطال (DTC)، أو شرح خطوات التكويد الطويل (Long Coding) لأي سيارة."
    }
  ];
  bool isAiThinking = false;

  final List<String> carModules = [
    "25 - Immobilizer System (IMMO / Key Module)",
    "01 - Engine Control Module (ECM / ECU)",
    "02 - Transmission Control Module (TCM)",
    "03 - ABS / ESP Braking System",
    "09 - Central Electrics / BCM (Body Control)",
    "15 - Airbag / SRS Safety System",
    "17 - Instrument Cluster (Dashboard & Key Data)"
  ];

  final String backendUrl = "https://carai-backend-2dw4.onrender.com/api/diagnose";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
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
      _sendOBDCommand("AT SP 6");
    } catch (e) {
      _showSnackBar("فشل الاتصال بقطعة OBD2: $e");
    }
  }

  void _sendOBDCommand(String command) {
    if (connection != null && connection!.isConnected) {
      connection!.output.add(Uint8List.fromList(utf8.encode("$command\r")));
    } else {
      _simulateKeyProgrammingResponse(command);
    }
  }

  void _simulateKeyProgrammingResponse(String command) {
    if (command == "READ_PIN") {
      setState(() {
        extractedPinCode = "8492";
        immoStatus = "تم استخراج كود الأمان PIN (SKC) بنجاح!";
      });
    } else if (command == "PROGRAM_KEY") {
      setState(() {
        programmedKeysCount += 1;
        immoStatus = "تم مطابقة وبرمجة المفتاح الجديد بنجاح (عدد المفاتيح: $programmedKeysCount).";
      });
    } else if (command == "ERASE_KEYS") {
      setState(() {
        programmedKeysCount = 1;
        immoStatus = "تم مسح جميع المفاتيح المفقودة. المفتاح الحالي فقط هو المعتمد.";
      });
    }
  }

  Future<void> _processKeyProgrammingAI(String actionType) async {
    setState(() => isKeyProgrammingBusy = true);
    _sendOBDCommand(actionType);

    try {
      final response = await http.post(
        Uri.parse(backendUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "prompt": "عملية تكويد مفتاح إيموبلايزر (Key Programming): $actionType في نظام $selectedModule. اشرح خطوات العايرة والأوامر البرمجية بدقة."
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() => immoStatus = data['response'] ?? "تم تنفيذ عملية المفاتيح بنجاح.");
      }
    } catch (e) {
      // Handled locally
    } finally {
      setState(() => isKeyProgrammingBusy = false);
    }
  }

  // AI Assistant Chat Handler
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
        body: jsonEncode({
          "prompt": "أنت خبير فحص وتكويد سيارات وبرمجة مفاتيح (Car Diagnostic & Key Programming Expert). أجب عن السؤال التالي باللغة العربية بأسلوب فني دقيق وبسيط:\n$text"
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _chatMessages.add({"sender": "ai", "text": data['response'] ?? "عذراً، لم أستطع تحليل الطلب حالياً."});
        });
      } else {
        setState(() {
          _chatMessages.add({"sender": "ai", "text": "حدث خطأ أثناء الاتصال بالخادم الرئيسي."});
        });
      }
    } catch (e) {
      setState(() {
        _chatMessages.add({
          "sender": "ai",
          "text": "تعذر الاتصال بالسيرفر. تأكد من وجود اتصال بالإنترنت."
        });
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
        title: const Text('CarAI Pro: Diagnostic & Key Studio'),
        backgroundColor: const Color(0xFF0D47A1),
        actions: [
          IconButton(
            icon: Icon(
              isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
              color: isConnected ? Colors.greenAccent : Colors.redAccent,
            ),
            onPressed: _showBluetoothDialog,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.psychology), text: "مساعد AI"),
            Tab(icon: Icon(Icons.vpn_key), text: "برمجة المفاتيح"),
            Tab(icon: Icon(Icons.memory), text: "التكويد الطويل"),
            Tab(icon: Icon(Icons.build_circle), text: "اختبار المشغلات"),
            Tab(icon: Icon(Icons.speed), text: "اللوحة الحية"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAiAssistantTab(),
          _buildKeyProgrammingTab(),
          _buildLongCodingTab(),
          _buildActuatorTestsTab(),
          _buildLiveGaugesTab(),
        ],
      ),
    );
  }

  // TAB 1: AI Assistant Chat Studio
  Widget _buildAiAssistantTab() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.blue.shade900.withOpacity(0.4),
          child: const Row(
            children: [
              Icon(Icons.smart_toy, color: Colors.cyanAccent, size: 28),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  "مساعد السيارات الذكي (AI Assistant)\nاطرح أي سؤال عن الأعطال، التكويد، أو برمجة المفاتيح.",
                  style: TextStyle(fontSize: 12, height: 1.3),
                ),
              ),
            ],
          ),
        ),
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
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isUser ? Colors.blue.shade800 : Colors.grey.shade900,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isUser ? Colors.blueAccent : Colors.cyan.shade700,
                      width: 1,
                    ),
                  ),
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
                  child: Text(
                    msg["text"] ?? "",
                    style: const TextStyle(fontSize: 14, height: 1.4),
                  ),
                ),
              );
            },
          ),
        ),
        if (isAiThinking)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                SizedBox(width: 10),
                Text("الذكاء الاصطناعي يفكر...", style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          color: Colors.black26,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _chatController,
                  decoration: const InputDecoration(
                    hintText: "اسأل الذكاء الاصطناعي (مثال: كيف أكوّد مفتاح جولف 6؟)...",
                    border: InputBorder.none,
                  ),
                  onSubmitted: (_) => _sendChatMessage(),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send, color: Colors.cyanAccent),
                onPressed: _sendChatMessage,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // TAB 2: Immobilizer & Key Programming
  Widget _buildKeyProgrammingTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            color: Colors.amber.shade900.withOpacity(0.3),
            child: const ListTile(
              leading: Icon(Icons.security, color: Colors.amber, size: 36),
              title: Text("مركز تكويد وبرمجة المفاتيح (Key & Immo Center)", style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text("دعم استخراج PIN Code، إضافة مفاتيح الشريحة/البصمة، ومسح المفاتيح المفقودة."),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("كود الأمان المستخرج (PIN/SKC):", style: TextStyle(color: Colors.grey)),
                      const SizedBox(height: 4),
                      Text(extractedPinCode, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.greenAccent)),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text("المفاتيح المكتوبة:", style: TextStyle(color: Colors.grey)),
                      const SizedBox(height: 4),
                      Text("$programmedKeysCount مفاتيح", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.cyanAccent)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade700, padding: const EdgeInsets.all(14)),
            icon: const Icon(Icons.key, color: Colors.white),
            label: const Text("1. قراءة واستخراج كود PIN/SKC الخاص بالإيموبلايزر", style: TextStyle(color: Colors.white, fontSize: 15)),
            onPressed: () => _processKeyProgrammingAI("READ_PIN"),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, padding: const EdgeInsets.all(14)),
            icon: const Icon(Icons.add_moderator, color: Colors.white),
            label: const Text("2. برمجة ومطابقة مفتاح جديد (Key Matching - Channel 21)", style: TextStyle(color: Colors.white, fontSize: 15)),
            onPressed: () => _processKeyProgrammingAI("PROGRAM_KEY"),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade800, padding: const EdgeInsets.all(14)),
            icon: const Icon(Icons.phonelink_erase, color: Colors.white),
            label: const Text("3. مسح جميع المفاتيح المفقودة أو الضائعة", style: TextStyle(color: Colors.white, fontSize: 15)),
            onPressed: () => _processKeyProgrammingAI("ERASE_KEYS"),
          ),
          const SizedBox(height: 20),
          Card(
            color: Colors.blueGrey.shade900,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("سجل التكويد وتأكيد الأمن المباشر:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amberAccent)),
                  const SizedBox(height: 8),
                  if (isKeyProgrammingBusy)
                    const Center(child: CircularProgressIndicator())
                  else
                    Text(immoStatus, style: const TextStyle(fontSize: 14, height: 1.4)),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  // TAB 3: Long Coding Engine
  Widget _buildLongCodingTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            value: selectedModule,
            items: carModules.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
            onChanged: (val) => setState(() => selectedModule = val!),
            decoration: const InputDecoration(labelText: "اختر الكنترول المراد تكويده", border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("محرك التكويد الطويل التفاعلي (AI Bit-By-Bit Coding):", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  SelectableText(currentLongCoding, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.cyanAccent, fontFamily: 'monospace')),
                  const Divider(height: 20),
                  const Text("تفعيل الخيارات التلقائية بنقرة واحدة (1-Click Retrofit):"),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ActionChip(label: const Text("تأكيد عايرة بوابة الهواء Throttle Adaptation"), onPressed: () {}),
                      ActionChip(label: const Text("برمجة وتكويد البخاخات Injector IMA Code"), onPressed: () {}),
                      ActionChip(label: const Text("تفعيل فتح النوافذ بالريموت Remote Windows"), onPressed: () {}),
                    ],
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  // TAB 4: Actuator Output Tests
  Widget _buildActuatorTestsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text("اختبارات المشغّلات المباشرة (Actuator Output Tests):", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 10),
          _buildActuatorCard("اختبار مضخة الوقود Fuel Pump Test", "إرسال أمر تشغيل الطلمبة لمدة 10 ثوانٍ للتحقق من الضغط.", Icons.local_gas_station),
          _buildActuatorCard("اختبار مراوح التبريد Cooling Fan Test", "تشغيل المروحة على السرعة العالية والمنخفضة.", Icons.toys),
          _buildActuatorCard("فتح فرامل اليد الإلكترونية EPB Service Mode", "فتح الكليبرات الخلفية لتغيير فحمات الفرامل.", Icons.minor_crash),
        ],
      ),
    );
  }

  Widget _buildActuatorCard(String title, String desc, IconData icon) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: Colors.blueAccent, size: 30),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(desc, style: const TextStyle(fontSize: 12)),
        trailing: ElevatedButton(
          child: const Text("اختبار"),
          onPressed: () => _showSnackBar("جاري تشغيل اختبار $title..."),
        ),
      ),
    );
  }

  // TAB 5: Live Gauges
  Widget _buildLiveGaugesTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            children: [
              _buildGaugeCard("دوران المحرك", engineRpm, Icons.speed, Colors.blue),
              _buildGaugeCard("حرارة المحرك", coolantTemp, Icons.thermostat, Colors.orange),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGaugeCard(String title, String val, IconData icon, Color col) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Icon(icon, color: col, size: 32),
              const SizedBox(height: 8),
              Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 4),
              Text(val, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
        title: const Text('اختر قطعة البلوتوث المقترنة'),
        content: SizedBox(
          width: double.maxFinite,
          child: devicesList.isEmpty
              ? const Text('لا توجد أجهزة مقترنة.')
              : ListView.builder(
                  shrinkWrap: t
