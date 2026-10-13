import 'package:flutter/material.dart';

// Paleta: tamnoplava noć + zlatne pločice.
const bgTop = Color(0xFF14306A);
const bgBottom = Color(0xFF07142E);
const panel = Color(0xFF102552);
const panelLight = Color(0xFF173269);
const panelBorder = Color(0xFF2B4D8F);
const gold = Color(0xFFFFC93C);
const goldDeep = Color(0xFFF0A21B);
const goldText = Color(0xFF3B2600);
const textMuted = Color(0xFFA9B8D9);
const success = Color(0xFF3DDC84);
const danger = Color(0xFFFF4D5E);

// Zadržana imena koja koriste ostali ekrani.
const brandBlue = Color(0xFF2F6BD6);
const brandRed = danger;
const cellEmpty = Color(0xFF0D2148);
const cellFilled = gold;
const cellInitial = Color(0xFFFFF4DC);
const cellSelected = Color(0xFF8EC5FF);
const cellWord = success;

const goldGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0xFFFFE07A), gold, goldDeep],
);

const blueGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0xFF2559B8), Color(0xFF173E8C)],
);

const backgroundGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [bgTop, bgBottom],
);

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: brandBlue,
    brightness: Brightness.dark,
    primary: gold,
    onPrimary: goldText,
    secondary: brandBlue,
    surface: panel,
    error: danger,
  );
  final base = ThemeData(colorScheme: scheme, useMaterial3: true, brightness: Brightness.dark);
  return base.copyWith(
    scaffoldBackgroundColor: bgBottom,
    textTheme: base.textTheme.apply(bodyColor: Colors.white, displayColor: Colors.white),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
    ),
    cardTheme: CardTheme(
      color: panel,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: panelBorder),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: panel,
      isDense: true,
      labelStyle: const TextStyle(color: textMuted),
      hintStyle: const TextStyle(color: textMuted),
      helperStyle: const TextStyle(color: textMuted),
      prefixIconColor: textMuted,
      suffixIconColor: textMuted,
      border:
          OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: panelBorder)),
      enabledBorder:
          OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: panelBorder)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: gold, width: 2)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: gold,
        foregroundColor: goldText,
        disabledBackgroundColor: panelLight,
        disabledForegroundColor: textMuted,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: 0.5),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: panel,
        side: const BorderSide(color: panelBorder, width: 1.5),
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: gold)),
    tabBarTheme: const TabBarTheme(
      labelColor: Colors.white,
      unselectedLabelColor: textMuted,
      indicatorSize: TabBarIndicatorSize.tab,
      dividerColor: Colors.transparent,
      labelStyle: TextStyle(fontWeight: FontWeight.w700),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: panelLight,
      contentTextStyle: TextStyle(color: Colors.white),
      behavior: SnackBarBehavior.floating,
    ),
    dialogTheme: DialogTheme(
      backgroundColor: panel,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: panelBorder)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(backgroundColor: panel),
    dividerTheme: const DividerThemeData(color: panelBorder),
    listTileTheme: const ListTileThemeData(iconColor: gold),
    chipTheme: ChipThemeData(
      backgroundColor: panelLight,
      side: const BorderSide(color: panelBorder),
      labelStyle: const TextStyle(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: gold),
    radioTheme: RadioThemeData(fillColor: WidgetStateProperty.all(gold)),
  );
}
