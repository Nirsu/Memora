import 'package:flutter/material.dart';

const ink = Color(0xffededeb);
const muted = Color(0xffadadaa);
const accent = Color(0xffe0e0dc);
const canvas = Color(0xff171717);
const sidebar = Color(0xff111111);
const panel = Color(0xff202020);
const selectedSurface = Color(0xff2a2a29);
const line = Color(0xff343434);

final ThemeData appTheme = ThemeData(
  brightness: .dark,
  useMaterial3: true,
  fontFamily: 'Segoe UI',
  scaffoldBackgroundColor: canvas,
  splashFactory: NoSplash.splashFactory,
  colorScheme:
      ColorScheme.fromSeed(
        seedColor: accent,
        brightness: .dark,
        dynamicSchemeVariant: .monochrome,
      ).copyWith(
        primary: accent,
        onPrimary: sidebar,
        surface: panel,
        onSurface: ink,
        outline: line,
        surfaceTint: Colors.transparent,
        onSurfaceVariant: muted,
      ),
  dividerColor: line,
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(foregroundColor: ink),
  ),
  iconButtonTheme: IconButtonThemeData(
    style: IconButton.styleFrom(foregroundColor: muted),
  ),
  tabBarTheme: const TabBarThemeData(
    labelColor: ink,
    unselectedLabelColor: muted,
    indicatorColor: ink,
    dividerColor: line,
    labelStyle: TextStyle(fontSize: 13, fontWeight: .w600),
    unselectedLabelStyle: TextStyle(fontSize: 13),
  ),
  dialogTheme: DialogThemeData(
    backgroundColor: panel,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: const BorderSide(color: line),
    ),
  ),
  popupMenuTheme: PopupMenuThemeData(
    color: panel,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: const BorderSide(color: line),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: canvas,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: line),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: line),
    ),
    hintStyle: const TextStyle(color: muted),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: ink,
      foregroundColor: sidebar,
      textStyle: const TextStyle(
        fontFamily: 'Segoe UI',
        fontSize: 13,
        fontWeight: .w600,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: ink,
      side: const BorderSide(color: line),
      textStyle: const TextStyle(fontFamily: 'Segoe UI', fontSize: 13),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  ),
);
