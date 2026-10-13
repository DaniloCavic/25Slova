import 'package:flutter/material.dart';

/// Boje koje zavise od režima (tamni / svetli).
class AppPalette {
  final Brightness brightness;
  final Color bgTop, bgBottom, panel, panelLight, panelBorder, textMain, textMuted, cellEmpty, success;
  const AppPalette({
    required this.brightness,
    required this.bgTop,
    required this.bgBottom,
    required this.panel,
    required this.panelLight,
    required this.panelBorder,
    required this.textMain,
    required this.textMuted,
    required this.cellEmpty,
    required this.success,
  });
}

/// Tamni režim: tamnoplava noć + zlatne pločice.
const darkPalette = AppPalette(
  brightness: Brightness.dark,
  bgTop: Color(0xFF14306A),
  bgBottom: Color(0xFF07142E),
  panel: Color(0xFF102552),
  panelLight: Color(0xFF173269),
  panelBorder: Color(0xFF2B4D8F),
  textMain: Colors.white,
  textMuted: Color(0xFFA9B8D9),
  cellEmpty: Color(0xFF0D2148),
  success: Color(0xFF3DDC84),
);

/// Svetli režim: svetloplava pozadina, bele kartice, iste zlatne pločice.
const lightPalette = AppPalette(
  brightness: Brightness.light,
  bgTop: Color(0xFFF4F7FD),
  bgBottom: Color(0xFFDCE5F5),
  panel: Colors.white,
  panelLight: Color(0xFFE9EFFA),
  panelBorder: Color(0xFFC6D3EA),
  textMain: Color(0xFF14213D),
  textMuted: Color(0xFF5A6A8A),
  cellEmpty: Color(0xFFE6ECF7),
  success: Color(0xFF17924F),
);

/// Trenutna paleta — menja se iz podešavanja (AppState.setThemeMode) pre ponovnog crtanja aplikacije.
AppPalette pal = darkPalette;

Color get bgTop => pal.bgTop;
Color get bgBottom => pal.bgBottom;
Color get panel => pal.panel;
Color get panelLight => pal.panelLight;
Color get panelBorder => pal.panelBorder;
Color get textMain => pal.textMain;
Color get textMuted => pal.textMuted;
Color get cellEmpty => pal.cellEmpty;
Color get success => pal.success;
Color get cellWord => pal.success;
bool get isDark => pal.brightness == Brightness.dark;

/// Zlatna za tekst: na svetloj podlozi tamnija da bi bila čitljiva.
Color get goldAccent => isDark ? gold : const Color(0xFFA86A00);

const gold = Color(0xFFFFC93C);
const goldDeep = Color(0xFFF0A21B);
const goldText = Color(0xFF3B2600);
const danger = Color(0xFFFF4D5E);
const brandBlue = Color(0xFF2F6BD6);
const brandRed = danger;
const cellFilled = gold;
const cellInitial = Color(0xFFFFF4DC);
const cellSelected = Color(0xFF8EC5FF);

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

LinearGradient get backgroundGradient => LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [bgTop, bgBottom],
    );

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: brandBlue,
    brightness: pal.brightness,
    primary: isDark ? gold : const Color(0xFFB87800),
    onPrimary: goldText,
    secondary: brandBlue,
    surface: panel,
    error: danger,
  );
  final base = ThemeData(colorScheme: scheme, useMaterial3: true, brightness: pal.brightness);
  return base.copyWith(
    scaffoldBackgroundColor: bgBottom,
    textTheme: base.textTheme.apply(bodyColor: textMain, displayColor: textMain),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: textMain,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: textMain),
    ),
    cardTheme: CardTheme(
      color: panel,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: panelBorder),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: panel,
      isDense: true,
      labelStyle: TextStyle(color: textMuted),
      hintStyle: TextStyle(color: textMuted),
      helperStyle: TextStyle(color: textMuted),
      prefixIconColor: textMuted,
      suffixIconColor: textMuted,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: panelBorder)),
      enabledBorder:
          OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: panelBorder)),
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
        foregroundColor: textMain,
        backgroundColor: panel,
        side: BorderSide(color: panelBorder, width: 1.5),
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme:
        TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: isDark ? gold : const Color(0xFFB87800))),
    tabBarTheme: TabBarTheme(
      labelColor: Colors.white,
      unselectedLabelColor: textMuted,
      indicatorSize: TabBarIndicatorSize.tab,
      dividerColor: Colors.transparent,
      labelStyle: const TextStyle(fontWeight: FontWeight.w700),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: panelLight,
      contentTextStyle: TextStyle(color: textMain),
      behavior: SnackBarBehavior.floating,
    ),
    dialogTheme: DialogTheme(
      backgroundColor: panel,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: panelBorder)),
    ),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: panel),
    dividerTheme: DividerThemeData(color: panelBorder),
    listTileTheme: const ListTileThemeData(iconColor: gold),
    chipTheme: ChipThemeData(
      backgroundColor: panelLight,
      side: BorderSide(color: panelBorder),
      labelStyle: TextStyle(color: textMain),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: gold),
    radioTheme: RadioThemeData(fillColor: WidgetStateProperty.all(gold)),
  );
}
