import 'package:flutter/material.dart';

class AppColors {
  static const bg = Color(0xFF0E0E14);
  static const surface = Color(0xFF16161F);
  static const surface2 = Color(0xFF1C1C28);
  static const border = Color(0x14FFFFFF); // rgba(255,255,255,0.08)
  static const borderActive = Color(0x998B5CF6);
  static const accent = Color(0xFF8B5CF6);
  static const accent2 = Color(0xFFA78BFA);
  static const accentGlow = Color(0x408B5CF6);
  static const text = Color(0xFFF0EEFF);
  static const text2 = Color(0x8CF0EEFF); // 55% opacity
  static const text3 = Color(0x47F0EEFF); // 28% opacity
  static const success = Color(0xFF34D399);
  static const successGlow = Color(0x4034D399);
  static const danger = Color(0xFFF87171);
  static const ink = Color(0xFF1A1033);
  static const canvasBg = Color(0xFFFAFAFE);
  static const docViewport = Color(0xFF222230);
}

class AppTheme {
  static ThemeData get theme => ThemeData(
        scaffoldBackgroundColor: AppColors.bg,
        colorScheme: const ColorScheme.dark(
          surface: AppColors.surface,
          primary: AppColors.accent,
          secondary: AppColors.accent2,
          error: AppColors.danger,
        ),
        fontFamily: 'DM Sans',
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: AppColors.text),
        ),
        sliderTheme: SliderThemeData(
          activeTrackColor: AppColors.accent,
          inactiveTrackColor: AppColors.border,
          thumbColor: AppColors.accent,
          overlayColor: AppColors.accentGlow,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
          trackHeight: 4,
        ),
        checkboxTheme: CheckboxThemeData(
          fillColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.selected)
                  ? AppColors.accent
                  : AppColors.surface2),
        ),
      );
}
