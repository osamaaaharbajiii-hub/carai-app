import 'dart:async';
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

class ProtocolInfo {
  final String title;
  final String description;
  final String category;
  final bool isRecommended;
  final String? hardwareNote;

  ProtocolInfo({
    required this.title,
    required this.description,
    required this.category,
    this.isRecommended = false,
    this.hardwareNote,
  });
}

class MainDashboard extends StatefulWidget {
  const MainDashboard({super.key});

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  bool isConnected = false;
  BluetoothDevice? selectedDevice;
  
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;

  final List<ProtocolInfo> protocols = [
    ProtocolInfo(
      title: 'Auto Protocol (OBD-II)',
      description: 'Recommended — automatically detects protocol for 98% of vehicles',
      category: 'Standard Protocols',
      isRecommended: true,
    ),
    ProtocolInfo(
      title: 'ISO 15765-4 (CAN)',
      description: 'Most vehicles built from 2008+ onwards (High Speed Data)',
      category: 'Standard Protocols',
    ),
    ProtocolInfo(
      title: 'ISO 14230-4 (KWP2000)',
      description: 'Common in European & Asian vehicles (2000-2008)',
      category: 'Standard Protocols',
    ),
    ProtocolInfo(
      title: 'ISO 9141-2',
      description: 'Older European, Asian, and Chrysler vehicles (Pre-2004)',
      category: 'Standard Protocols',
    ),
    ProtocolInfo(
      title: 'SAE J1850 (PWM/VPW)',
      description: 'Older Ford (PWM) and General Motors (VPW) models',
      category: 'Standard Protocols',
    ),
    ProtocolInfo(
      title: 'Tesla Proprietary CAN',
      description: 'Direct Battery & Drive Unit CAN bus access for Model 3/Y/S/X',
      category: 'Advanced & Proprietary',
      hardwareNote: 'Requires Tesla Diagnostic OBD Harness adapter + STN1110/vLinker adapter',
    ),
    ProtocolInfo(
      title: 'Hybrid ECU Direct Protocol',
      description: 'High-voltage Battery & Inverter ECU diagnosis for Toyota/Lexus/Honda',
      category: 'Advanced & Proprietary',
      hardwareNote: 'Supports standard ELM327 v1.5 / vLinker MC+ adapters',
    ),
  ];

  late ProtocolInfo selectedProtocol;

  @override
  void initState() {
    super.initState();
    selectedProtocol = protocols[0];
  }

  @override
  void dispose() {
    _connectionSubscription?.cancel();
    super.dispose();
  }

  Future<void> _getDevices() async {
    try {
      // 1. Check if Bluetooth is supported and enabled
      if (await FlutterBluePlus.isSupported == false) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Bluetooth is not supported on this device')),
          );
        }
        return;
      }

      var adapterState = await FlutterBluePlus.adapterState.first;
      if (adapterState != BluetoothAdapterState.on) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please turn on Bluetooth first')),
          );
        }
        return;
      }

      // 2. Start scanning
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));

      if (mounted) {
        _showDevicePicker();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error starting scan: $e')),
        );
      }
    }
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    try {
      await _connectionSubscription?.cancel();
      await FlutterBluePlus.stopScan();

      await device.connect();

      if (mounted) {
        setState(() {
          selectedDevice = device;
          isConnected = true;
        });
      }

      _connectionSubscription = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected && mounted) {
          setState(() {
            isConnected = false;
            selectedDevice = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Device disconnected')),
          );
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connection failed: $e')),
        );
      }
    }
  }

  void _showDevicePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161920),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.65,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Available OBD-II Adapters',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFFB300),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () {
                      FlutterBluePlus.stopScan();
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: StreamBuilder<List<ScanResult>>(
                  stream: FlutterBluePlus.scanResults,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: Color(0xFFFFB300)),
                      );
                    }

                    final results = snapshot.data ?? [];

                    if (results.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.bluetooth_searching, size: 48, color: Colors.grey),
                            SizedBox(height: 12),
                            Text(
                              'No Bluetooth adapters found',
                              style: TextStyle(color: Colors.grey, fontSize: 14),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Make sure your OBD-II adapter is plugged in and paired.',
                              style: TextStyle(color: Colors.grey, fontSize: 12),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: results.length,
                      itemBuilder: (context, index) {
                        final r = results[index];
                        final deviceName = r.device.platformName.isNotEmpty
                            ? r.device.platformName
                            : 'Unknown Adapter';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0D0F12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withOpacity(0.05)),
                          ),
                          child: ListTile(
                            leading: const Icon(Icons.bluetooth, color: Color(0xFFFFB300)),
                            title: Text(
                              deviceName,
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            subtitle: Text(
                              r.device.remoteId.str,
                              style: const TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                            trailing: Text(
                              '${r.rssi} dBm',
                              style: const TextStyle(color: Colors.grey, fontSize: 11),
                            ),
                            onTap: () {
                              Navigator.pop(context); // Close modal before attempting connection
                              _connectToDevice(r.device);
                            },
                          ),
                        );
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

  void _showProtocolSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF161920),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[700],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 15),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Select OBD-II Protocol',
                    style: TextStyle(
                      fontSize: 18,
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
              const SizedBox(height: 10),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: protocols.length,
                  itemBuilder: (context, index) {
                    final item = protocols[index];
                    bool isFirstOfCategory = index == 0 ||
                        protocols[index - 1].category != item.category;
                    bool isSelected = selectedProtocol.title == item.title;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isFirstOfCategory) ...[
                          Padding(
                            padding: const EdgeInsets.only(top: 15, bottom: 8),
                            child: Text(
                              item.category.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFFFB300),
                                letterSpacing: 1.1,
                              ),
                            ),
                          ),
                        ],
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFFFFB300).withOpacity(0.12)
                                : const Color(0xFF0D0F12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFFFFB300)
                                  : Colors.white.withOpacity(0.05),
                            ),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 6),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item.title,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: isSelected
                                          ? const Color(0xFFFFB300)
                                          : Colors.white,
                                    ),
                                  ),
                                ),
                                if (item.isRecommended)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                          color: Colors.green, width: 0.8),
                                    ),
                                    child: const Text(
                                      'Recommended',
                                      style: TextStyle(
                                          color: Colors.green,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(
                                  item.description,
                                  style: const TextStyle(
                                      color: Colors.grey, fontSize: 12),
                                ),
                                if (item.hardwareNote != null) ...[
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Icon(Icons.info_outline,
                                          size: 13, color: Colors.amber),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          item.hardwareNote!,
                                          style: const TextStyle(
                                              color: Colors.amber,
                                              fontSize: 10.5,
                                              fontStyle: FontStyle.italic),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                            onTap: () {
                              setState(() {
                                selectedProtocol = item;
                              });
                              Navigator.pop(context);
                            },
                          ),
                        ),
                      ],
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
            // Connection Status Card
            Card(
              color: const Color(0xFF161920),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
                side: BorderSide(
                  color: isConnected ? Colors.green.withOpacity(
