import 'dart:async';
import 'package:flutter/material.dart';
import 'obd_service.dart';

class LiveDataScreen extends StatefulWidget {
  final ObdService obdService;

  const LiveDataScreen({super.key, required this.obdService});

  @override
  State<LiveDataScreen> createState() => _LiveDataScreenState();
}

class _LiveDataScreenState extends State<LiveDataScreen> {
  Timer? _timer;
  int rpm = 0;
  int speed = 0;
  int coolantTemp = 0;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  void _startPolling() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      final rpmData = await widget.obdService.sendCommand('010C');
      final speedData = await widget.obdService.sendCommand('010D');
      final tempData = await widget.obdService.sendCommand('0105');

      if (mounted) {
        setState(() {
          rpm = _parseRpm(rpmData);
          speed = _parseSpeed(speedData);
          coolantTemp = _parseTemp(tempData);
          isLoading = false;
        });
      }
    });
  }

  int _parseRpm(String raw) {
    // ELM327 returns "41 0C XX YY"
    try {
      final parts = raw.split(' ');
      if (parts.length >= 4 && parts[0] == '41' && parts[1] == '0C') {
        int a = int.parse(parts[2], radix: 16);
        int b = int.parse(parts[3], radix: 16);
        return ((a * 256) + b) ~/ 4;
      }
    } catch (_) {}
    return rpm;
  }

  int _parseSpeed(String raw) {
    // ELM327 returns "41 0D XX"
    try {
      final parts = raw.split(' ');
      if (parts.length >= 3 && parts[0] == '41' && parts[1] == '0D') {
        return int.parse(parts[2], radix: 16);
      }
    } catch (_) {}
    return speed;
  }

  int _parseTemp(String raw) {
    // ELM327 returns "41 05 XX" -> Temp = A - 40
    try {
      final parts = raw.split(' ');
      if (parts.length >= 3 && parts[0] == '41' && parts[1] == '05') {
        return int.parse(parts[2], radix: 16) - 40;
      }
    } catch (_) {}
    return coolantTemp;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Engine Data', style: TextStyle(color: Color(0xFFFFB300))),
        backgroundColor: const Color(0xFF161920),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFFB300)))
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                children: [
                  _buildMetricCard('Engine RPM', '$rpm', 'RPM', Icons.speed, Colors.amber),
                  _buildMetricCard('Vehicle Speed', '$speed', 'km/h', Icons.directions_car, Colors.blue),
                  _buildMetricCard('Coolant Temp', '$coolantTemp', '°C', Icons.thermostat, Colors.red),
                ],
              ),
            ),
    );
  }

  Widget _buildMetricCard(String title, String value, String unit, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
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
          Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(width: 4),
              Text(unit, style: TextStyle(fontSize: 12, color: color)),
            ],
          ),
        ],
      ),
    );
  }
}
