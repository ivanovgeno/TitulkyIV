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

/// Modern design tokens used across the app.
class AppColors {
  // Backgrounds
  static const Color bg = Color(0xFF0A0A0F);
  static const Color bgPanel = Color(0xFF111118);
  static const Color bgCard = Color(0xFF16161F);
  static const Color bgElevated = Color(0xFF1C1C26);
  static const Color bgHover = Color(0xFF22222E);

  // Accent – warm gold gradient endpoints
  static const Color accent = Color(0xFFD4AF37);
  static const Color accentLight = Color(0xFFFFD866);
  static const Color accentDim = Color(0xFFAA8A1C);

  // Text
  static const Color textPrimary = Color(0xFFF0F0F5);
  static const Color textSecondary = Color(0xFFA0A0B0);
  static const Color textMuted = Color(0xFF606070);

  // Borders
  static const Color border = Color(0xFF2A2A38);
  static const Color borderLight = Color(0xFF3A3A48);

  // Semantic
  static const Color danger = Color(0xFFFF4466);
  static const Color success = Color(0xFF44DD88);
  static const Color info = Color(0xFF4488FF);

  // Playhead
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
          titleTextStyle: TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            letterSpacing: 0.3,
          ),
        ),
        sliderTheme: SliderThemeData(
          activeTrackColor: AppColors.accent,
          inactiveTrackColor: AppColors.border,
          thumbColor: AppColors.accent,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
          trackHeight: 3,
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
        scrollbarTheme: ScrollbarThemeData(
          thumbColor: WidgetStateProperty.all(AppColors.accent.withOpacity(0.5)),
          radius: const Radius.circular(8),
          thickness: WidgetStateProperty.all(6.0),
        ),
      ),
      home: const EditorScreen(),
    );
  }
}

