import 'package:flutter/material.dart';

ThemeData dashboardTheme(Brightness brightness) => ThemeData(
  useMaterial3: true,
  brightness: brightness,
  fontFamily: 'NotoSans',
  textTheme: const TextTheme(
    bodySmall: TextStyle(fontSize: 16),
    bodyMedium: TextStyle(fontSize: 16),
    bodyLarge: TextStyle(fontSize: 18),
    labelSmall: TextStyle(fontSize: 16),
    labelMedium: TextStyle(fontSize: 16),
    labelLarge: TextStyle(fontSize: 16),
  ),
  colorSchemeSeed: const Color(0xff41b69b),
);
