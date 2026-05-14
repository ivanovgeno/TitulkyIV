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

/// Design tokens
class AppColors {
  static const Color bg = Color(0xFF08080D);
  static const Color bgPanel = Color(0xFF0E0E16);
  static const Color bgCard = Color(0xFF141420);
  static const Color bgElevated = Color(0xFF1A1A28);
  static const Color bgHover = Color(0xFF202030);

  static const Color accent = Color(0xFFD4AF37);
  static const Color accentLight = Color(0xFFFFD866);
  static const Color accentDim = Color(0xFFAA8A1C);

  static const Color textPrimary = Color(0xFFF0F0F5);
  static const Color textSecondary = Color(0xFF8888A0);
  static const Color textMuted = Color(0xFF505068);

  static const Color border = Color(0xFF1E1E30);
  static const Color borderLight = Color(0xFF2A2A40);

  static const Color danger = Color(0xFFFF3366);
  static const Color success = Color(0xFF22CC66);
  static const Color info = Color(0xFF4488FF);
  static const Color playhead = Color(0xFFFF3355);
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
        scaffoldBackgroundColor: AppColors.bg,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.accent,
          secondary: AppColors.accentLight,
          surface: AppColors.bgPanel,
          onSurface: AppColors.textPrimary,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.bgPanel,
          elevation: 0,
        ),
        sliderTheme: SliderThemeData(
          activeTrackColor: AppColors.accent,
          inactiveTrackColor: AppColors.border,
          thumbColor: AppColors.accent,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
          trackHeight: 2,
          overlayShape: SliderComponentShape.noOverlay,
        ),
        tooltipTheme: TooltipThemeData(
          decoration: BoxDecoration(
            color: AppColors.bgElevated,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          textStyle: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
        ),
      ),
      home: const EditorScreen(),
    );
  }
}

