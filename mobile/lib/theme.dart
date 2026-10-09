import 'package:flutter/material.dart';

const brandBlue = Color(0xFF0C4076);
const brandRed = Color(0xFFC8102E);
const cellEmpty = Color(0xFFF1F3F7);
const cellFilled = Color(0xFFFFFFFF);
const cellInitial = Color(0xFFFFE8B3);
const cellSelected = Color(0xFFCFE3FF);
const cellWord = Color(0xFFD6F2DF);

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: brandBlue, primary: brandBlue, secondary: brandRed);
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: const Color(0xFFF6F7FA),
    appBarTheme: const AppBarTheme(backgroundColor: brandBlue, foregroundColor: Colors.white, centerTitle: true),
    inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder(), isDense: true),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48), textStyle: const TextStyle(fontSize: 16)),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
    ),
  );
}
