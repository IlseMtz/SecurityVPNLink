import 'package:flutter/material.dart';

class ColoresSecureLink {
  static const marino = Color(0xFF192C4D);
  static const azul = Color(0xFF2563EB);
  static const fondo = Color(0xFFF3F6FB);
  static const borde = Color(0xFFE1E7F0);
  static const secundario = Color(0xFF64748B);
}

ThemeData crearTemaSecureLink() {
  final esquema = ColorScheme.fromSeed(
    seedColor: ColoresSecureLink.azul,
    brightness: Brightness.light,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: esquema,
    scaffoldBackgroundColor: ColoresSecureLink.fondo,
    appBarTheme: const AppBarTheme(
      backgroundColor: ColoresSecureLink.marino,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 18,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: ColoresSecureLink.borde),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: ColoresSecureLink.azul,
          width: 2,
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: ColoresSecureLink.azul,
        foregroundColor: Colors.white,
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 46),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: ColoresSecureLink.borde,
    ),
  );
}