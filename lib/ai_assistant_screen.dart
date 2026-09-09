import 'package:flutter/material.dart';

class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  final TextEditingController _codeController = TextEditingController();
  String _analysis = '';
  bool _isAnalyzing = false;

  final Map<String, String> _commonCodes = {
    'P0300': 'Random/Multiple Cylinder Misfire Detected.\nPossible Causes: Spark plugs, ignition coils, low fuel pressure, or vacuum leak.',
    'P0420': 'Catalyst System Efficiency Below Threshold (Bank 1).\nPossible Causes: Oxygen sensor failure, catalytic converter failure, or exhaust leaks.',
    'P0171': 'System Too Lean (Bank 1).\nPossible Causes: Dirty MAF sensor, vacuum leak, weak fuel pump, or clogged fuel injectors.',
    'P0113': 'Intake Air Temperature Circuit High Input.\nPossible Causes: Faulty IAT sensor, open wire circuit, or loose connector.',
  };

  void _analyzeDtc() {
    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty) return;

    setState(() {
      _isAnalyzing = true;
      _analysis = '';
    });

    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          _analysis = _commonCodes[code] ??
              'Code $code Analysis:\nDiagnostic code registered. Check ECU wiring, sensors associated with code $code, or perform live data diagnosis.';
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Repair Assistant', style: TextStyle(color: Color(0xFFFFB300))),
        backgroundColor: const Color(0xFF161920),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter Trouble Code (DTC)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _codeController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'e.g. P0300, P0420',
                      hintStyle: const TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: const Color(0xFF161920),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _analyzeDtc,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFB300),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Analyze', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (_isAnalyzing)
              const Center(child: CircularProgressIndicator(color: Color(0xFFFFB300))),
            if (_analysis.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF161920),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFFB300).withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.psychology, color: Color(0xFFFFB300)),
                        SizedBox(width: 8),
                        Text('AI Diagnostic Result', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFFFB300))),
                      ],
                    ),
                    const Divider(color: Colors.white10, height: 20),
                    Text(_analysis, style: const TextStyle(color: Colors.white, height: 1.4)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
