import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'ui/editor_screen.dart';

void main() {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    MediaKit.ensureInitialized();
  } catch (e) {
    print('Warning during startup init: $e');
  }
  runApp(const IvCaptionsApp());
}

class IvCaptionsApp extends StatelessWidget {
  const IvCaptionsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IvCaptions',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF000000), // Pure black background
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFD4AF37), // 24k Gold
          surface: Color(0xFF0F0F0F), // Dark panel
        ),
      ),
      home: const EditorScreen(),
    );
  }
}
