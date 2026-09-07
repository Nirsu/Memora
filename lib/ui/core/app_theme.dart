import 'package:flutter/material.dart';

const ink = Color(0xffededee);
const muted = Color(0xff96969f);
const accent = Color(0xffc4b5fd);
const panel = Color(0xff19191c);
const line = Color(0xff2b2b30);

final ThemeData appTheme = ThemeData(
  brightness: .dark,
  useMaterial3: true,
  fontFamily: 'Segoe UI',
  scaffoldBackgroundColor: const Color(0xff141416),
  splashFactory: NoSplash.splashFactory,
  colorScheme: ColorScheme.fromSeed(seedColor: accent, brightness: .dark)
      .copyWith(
        primary: accent,
        onPrimary: const Color(0xff18181b),
        surface: panel,
        onSurface: ink,
        outline: line,
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
    fillColor: const Color(0xff141416),
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
      foregroundColor: const Color(0xff18181b),
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
