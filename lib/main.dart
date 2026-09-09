import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

void main() {
  runApp(const CarAiApp());
}

class CarAiApp extends StatelessWidget {
  const CarAiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CarAI Diagnostic',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0D0F12),
        primaryColor: const Color(0xFFFFB300),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFFB300),
          secondary: Color(0xFFFF8F00),
          surface: Color(0xFF161920),
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
  bool isConnected = false;
  String selectedProtocol = 'Auto Protocol (OBD-II)';
  List<BluetoothDevice> devicesList = [];
  BluetoothDevice? selectedDevice;

  final List<String> protocols = [
    'Auto Protocol (OBD-II)',
    'ISO 15765-4 (CAN)',
    'ISO 14230-4 (KWP2000)',
    'ISO 9141-2',
    'SAE J1850 (PWM/VPW)',
    'Tesla Proprietary CAN',
    'Hybrid ECU Direct Protocol',
  ];

  void _getDevices() async {
    FlutterBluePlus.startScan(timeout: const Duration(seconds: 4));
    FlutterBluePlus.scanResults.listen((results) {
      setState(() {
        devicesList = results.map((r) => r.device).toList();
      });
    });
  }

  Future<void> _connectToOBD(BluetoothDevice device) async {
    try {
      await device.connect();
      setState(() {
        selectedDevice = device;
        isConnected = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connected to ${device.platformName}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to connect: $e')),
      );
    }
  }

  void _openToolModal(String title, Widget content) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161920),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFFB300),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 15),
            content,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'CarAI Diagnostic',
          style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFFFB300)),
        ),
        backgroundColor: const Color(0xFF161920),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
              color: isConnected ? Colors.green : Colors.red,
            ),
            onPressed: _getDevices,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Card
            Card(
              color: const Color(0xFF161920),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
                side: BorderSide(color: Colors.white.withOpacity(0.05)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(
                      isConnected ? Icons.check_circle : Icons.warning_amber_rounded,
                      size: 40,
                      color: isConnected ? Colors.green : const Color(0xFFFFB300),
                    ),
                    const SizedBox(width: 15),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isConnected ? 'Connected' : 'Scanner Disconnected',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          selectedDevice != null
                              ? selectedDevice!.platformName
                              : 'Select OBD-II Adapter',
                          style: const TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Protocol Picker
            const Text(
              'OBD-II Protocol Selection',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF161920),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedProtocol,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF161920),
                  items: protocols.map((String protocol) {
                    return DropdownMenuItem<String>(
                      value: protocol,
                      child: Text(protocol, style: const TextStyle(color: Colors.white)),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => selectedProtocol = val);
                  },
                ),
              ),
            ),
            const SizedBox(height: 25),

            // Diagnostic Grid Tools
            const Text(
              'Diagnostic & Control Tools',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFFFB300)),
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: [
                _buildToolCard('Full Diagnostic', Icons.troubleshoot, Colors.amber, () {
                  _openToolModal('DTC Scanner', const Text('Scanning ECU for fault codes...'));
                }),
                _buildToolCard('Live Data', Icons.speed, Colors.amber, () {
                  _openToolModal('Live Parameters', const Text('RPM, Speed, Coolant Temp stream...'));
                }),
                _buildToolCard('Oil Reset', Icons.oil_barrel, Colors.amber, () {
                  _openToolModal('Oil Service Reset', const Text('Reset oil life indicator to 100%.'));
                }),
                _buildToolCard('DRL / Lighting', Icons.highlight, Colors.amber, () {
                  _openToolModal('Daytime Running Lights', const Text('Configure DRL behavior and toggle mode.'));
                }),
                _buildToolCard('Tesla Systems', Icons.electric_car, Colors.amber, () {
                  _openToolModal('Tesla CAN Diagnostics', const Text('Battery Health, Cell Voltages, Thermal Status.'));
                }),
                _buildToolCard('AI Assistant', Icons.psychology, Colors.amber, () {
                  _openToolModal('AI Repair Assistant', const Text('Enter DTC code to get repair solutions.'));
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF161920),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 36, color: color),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
