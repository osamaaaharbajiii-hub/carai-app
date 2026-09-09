import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

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
        scaffoldBackgroundColor: const Color(0xFF090D16),
        primaryColor: const Color(0xFFFFB703),
        cardColor: const Color(0xFF131B2E),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF090D16),
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
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
  String statusMessage = "جاهز للاتصال";

  @override
  void initState() {
    super.initState();
    _getBluetoothDevices();
  }

  Future<void> _getBluetoothDevices() async {
    try {
      List<BluetoothDevice> devices = await FlutterBluetoothSerial.instance.getBondedDevices();
      setState(() => devicesList = devices);
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  Future<void> _connectToOBD(BluetoothDevice device) async {
    setState(() => statusMessage = "جاري الاتصال بـ ${device.name}...");
    try {
      BluetoothConnection conn = await BluetoothConnection.toAddress(device.address);
      setState(() {
        connection = conn;
        isConnected = true;
        selectedDevice = device;
        statusMessage = "متصل بـ ${device.name}";
      });
    } catch (e) {
      setState(() {
        isConnected = false;
        statusMessage = "فشل الاتصال: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("CarAI PREMIUM"),
        actions: [
          IconButton(
            icon: Icon(
              isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
              color: isConnected ? Colors.greenAccent : Colors.redAccent,
            ),
            onPressed: () => _showDevicePicker(context),
          ),
        ],
      ),
      
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF8B5CF6),
        icon: const Icon(Icons.smart_toy_outlined, color: Colors.white, size: 26),
        label: const Text("Ask AI", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () => _showAiChatSheet(context),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusHeader(),
            const SizedBox(height: 24),

            const Text(
              "ALL-IN-ONE DIAGNOSTICS",
              style: TextStyle(color: Color(0xFFFFB703), letterSpacing: 1.5, fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 16),

            // Grid Items Including ICE (Gasoline/Diesel) + EV + Hybrid
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: [
                _buildGridItem(Icons.qr_code_scanner, "Full Scan", Colors.amber, () => _showICEFeature(context, "فحص الشامل لكافة الكومبيوترات (Engine, ABS, Airbag)")),
                _buildGridItem(Icons.speed, "Live Data", Colors.amber, () => _showICEFeature(context, "قراءة الحساسات المباشرة (RPM, Temp, O2, MAF)")),
                _buildGridItem(Icons.local_gas_station, "Engine (ICE)", Colors.orange, () => _showICEFeature(context, "فحص محركات البنزين والديزل والانبعاثات")),
                _buildGridItem(Icons.battery_charging_full, "Hybrid Health", Colors.greenAccent, () {}),
                _buildGridItem(Icons.electric_car, "Tesla CAN", Colors.cyanAccent, () {}),
                _buildGridItem(Icons.oil_barrel, "Oil & Service", Colors.amber, () => _showICEFeature(context, "تصفير مؤشر الزيت والصيانة (Oil Reset)")),
                _buildGridItem(Icons.tune, "1-Click Mod", Colors.orangeAccent, () => _showModsSheet(context)),
                _buildGridItem(Icons.vpn_key, "Key Coding", Colors.amber, () {}),
                _buildGridItem(Icons.psychology, "AI Repair", Colors.purpleAccent, () => _showAiChatSheet(context)),
              ],
            ),

            const SizedBox(height: 30),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "ONE-CLICK MODIFICATIONS",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                TextButton(
                  onPressed: () => _showModsSheet(context),
                  child: const Text("عرض الكل", style: TextStyle(color: Color(0xFFFFB703))),
                )
              ],
            ),
            const SizedBox(height: 12),

            _buildModCard("64-Color Ambient Lighting", "تفعيل الإضاءة المحيطية الداخلية", Icons.lightbulb_outline),
            _buildModCard("Daytime Running Lights (DRL)", "التحكم بأضواء النهار من الشاشة", Icons.wb_sunny_outlined),
            _buildModCard("Seatbelt Warning Disable", "إلغاء صوت تنبيه حزام الأمان", Icons.notifications_off_outlined),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF131B2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFB703).withOpacity(0.3), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFB703).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.minor_crash, color: Color(0xFFFFB703), size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  selectedDevice != null ? selectedDevice!.name ?? "OBD Adapter" : "غير متصل",
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(statusMessage, style: const TextStyle(color: Colors.grey, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridItem(IconData icon, String label, Color iconColor, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF131B2E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: iconColor, size: 30),
            const SizedBox(height: 8),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildModCard(String title, String subtitle, IconData icon) {
    return Card(
      color: const Color(0xFF131B2E),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: const Color(0xFFFFB703)),
        ),
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        trailing: const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 14),
        onTap: () => _showModsSheet(context),
      ),
    );
  }

  void _showICEFeature(BuildContext context, String detail) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF131B2E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.local_gas_station, color: Color(0xFFFFB703), size: 40),
              const SizedBox(height: 12),
              const Text("فحص محركات الاحتراق الداخلي", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(detail, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 14)),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFB703),
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text("بدء الفحص الآن", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              )
            ],
          ),
        );
      },
    );
  }

  void _showAiChatSheet(BuildContext context) {
    TextEditingController controller = TextEditingController();
    List<String> messages = [
      "أهلاً بك! أنا مساعد CarAI الذكي. كيف يمكنني مساعدتك في تشخيص أعطال المحرك، البنزين/الديزل، الهايبرد أو تسلا؟"
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF131B2E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                top: 20, left: 16, right: 16,
              ),
              child: SizedBox(
                height: 450,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.smart_toy_outlined, color: Color(0xFF8B5CF6), size: 28),
                        SizedBox(width: 10),
                        Text("مساعد CarAI الذكي", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const Divider(color: Colors.white10, height: 24),
                    Expanded(
                      child: ListView.builder(
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          bool isUser = index % 2 != 0;
                          return Align(
                            alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isUser ? const Color(0xFF8B5CF6) : const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(messages[index], style: const TextStyle(color: Colors.white)),
                            ),
                          );
                        },
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: controller,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: "اسأل عن أي كود أو عطل...",
                              hintStyle: const TextStyle(color: Colors.grey),
                              filled: true,
                              fillColor: const Color(0xFF1E293B),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.send, color: Color(0xFF8B5CF6)),
                          onPressed: () {
                            if (controller.text.isNotEmpty) {
                              setModalState(() {
                                messages.add(controller.text);
                                messages.add("جاري تحليل السؤال لحجم العطل الخاص بـ (${controller.text})...");
                                controller.clear();
                              });
                            }
                          },
                        )
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showModsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF131B2E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("تعديل أضواء النهار (DRL)", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text("تفعيل خيارات التحكم بالأضواء المباشرة من الشاشة.", style: TextStyle(color: Colors.grey, fontSize: 13)),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFB703),
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text("تفعيل التعديل (Aktivieren)", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDevicePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF131B2E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("اختر أداة OBD للبلوتوث", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: devicesList.length,
                  itemBuilder: (context, index) {
                    final dev = devicesList[index];
                    return ListTile(
                      title: Text(dev.name ?? "Unknown Device", style: const TextStyle(color: Colors.white)),
                      subtitle: Text(dev.address, style: const TextStyle(color: Colors.grey)),
                      trailing: const Icon(Icons.bluetooth, color: Color(0xFFFFB703)),
                      onTap: () {
                        Navigator.pop(context);
                        _connectToOBD(dev);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

