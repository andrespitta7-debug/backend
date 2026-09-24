import 'package:flutter/material.dart';

class AppTheme {
  static const fondoNoche = Color(0xFF0B1020);
  static const superficieNoche = Color(0xFF151D35);
  static const superficieElevada = Color(0xFF202A46);
  static const doradoCritico = Color(0xFFFFC857);
  static const rojoDanio = Color(0xFFE85D5D);
  static const verdeVida = Color(0xFF52D273);
  static const azulTexto = Color(0xFFD9E5FF);

  static ThemeData get dark {
    final colorScheme = ColorScheme.dark(
      primary: doradoCritico,
      onPrimary: fondoNoche,
      secondary: azulTexto,
      onSecondary: fondoNoche,
      error: rojoDanio,
      onError: Colors.white,
      surface: superficieNoche,
      onSurface: azulTexto,
    );

    final baseTextTheme = ThemeData.dark().textTheme;

    return ThemeData.dark().copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: fondoNoche,
      canvasColor: fondoNoche,
      appBarTheme: const AppBarTheme(
        backgroundColor: fondoNoche,
        foregroundColor: azulTexto,
        elevation: 0,
        centerTitle: false,
      ),
      textTheme: baseTextTheme.copyWith(
        headlineSmall: baseTextTheme.headlineSmall?.copyWith(
          color: doradoCritico,
          fontFamily: 'monospace',
          fontWeight: FontWeight.bold,
        ),
        titleLarge: baseTextTheme.titleLarge?.copyWith(
          color: azulTexto,
          fontFamily: 'monospace',
          fontWeight: FontWeight.bold,
        ),
        titleMedium: baseTextTheme.titleMedium?.copyWith(
          color: azulTexto,
          fontWeight: FontWeight.bold,
        ),
        bodyLarge: baseTextTheme.bodyLarge?.copyWith(color: azulTexto),
        bodyMedium: baseTextTheme.bodyMedium?.copyWith(color: azulTexto),
      ),
      cardTheme: CardThemeData(
        color: superficieNoche,
        elevation: 4,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: superficieElevada),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: doradoCritico,
          foregroundColor: fondoNoche,
          disabledBackgroundColor: superficieElevada,
          disabledForegroundColor: azulTexto.withValues(alpha: 0.55),
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: doradoCritico,
          textStyle: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: superficieNoche,
        labelStyle: const TextStyle(color: azulTexto),
        hintStyle: TextStyle(color: azulTexto.withValues(alpha: 0.6)),
        prefixIconColor: doradoCritico,
        suffixIconColor: doradoCritico,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: superficieElevada),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: superficieElevada),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: doradoCritico, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: rojoDanio),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: rojoDanio, width: 2),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: verdeVida,
        linearTrackColor: superficieElevada,
      ),
      dividerTheme: const DividerThemeData(color: superficieElevada),
    );
  }
}
