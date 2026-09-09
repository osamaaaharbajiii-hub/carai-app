import 'package:flutter/material.dart';
import 'main_dashboard.dart';

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
