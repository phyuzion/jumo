// lib/shared/themes/app_theme.dart

import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: false, // Material 3 비활성화 (선호에 따라)
      primaryColor: Colors.blue,
      scaffoldBackgroundColor: Colors.white,
      colorScheme: const ColorScheme.light(
        primary: Colors.blue,
        onPrimary: Colors.black,
      ),
      // 최소한의 라운드
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            // 모서리를 약간만 둥글게
            borderRadius: BorderRadius.circular(1),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        ),
      ),
      // TextButton, OutlinedButton도 비슷하게
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(1)),
          ),
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(1)),
          ),
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          ),
        ),
      ),
      // Card, Dialog 등도 원하면 비슷하게 커스터마이즈 가능
      cardTheme: const CardTheme(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(1)),
        ),
        margin: EdgeInsets.all(4),
      ),
    );
  }
}
