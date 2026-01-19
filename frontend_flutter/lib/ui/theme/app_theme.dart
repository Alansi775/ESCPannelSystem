import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // يفضل استخدام Google Fonts إذا أمكن، أو استبدله بـ Arial

class AppThemeData {
  // --- Industrial Palette ---
  static const Color primaryBlue = Color(0xFF2962FF); // Tesla Blue
  static const Color accentCyan = Color(0xFF00E5FF);  // Data/Energy
  static const Color dangerRed = Color(0xFFFF3B30);   // Stop/Disconnect
  static const Color successGreen = Color(0xFF00C853); // Connected
  
  // --- Backgrounds ---
  static const Color darkBg = Color(0xFF050505);      // Pure Black-ish
  static const Color darkSurface = Color(0xFF121212); // Matte Panel
  static const Color darkBorder = Color(0xFF2A2A2A);  // Subtle borders

  static ThemeData darkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBg,
      primaryColor: primaryBlue,
      cardColor: darkSurface,
      
      // Typography: Clean, Technical, Readable
      fontFamily: 'Roboto', // أو أي خط تقني
      textTheme: TextTheme(
        displayLarge: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: -0.5, color: Colors.white),
        displayMedium: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600, letterSpacing: -0.5, color: Colors.white),
        headlineSmall: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
        bodyLarge: const TextStyle(fontSize: 16, color: Color(0xFFE0E0E0)),
        bodyMedium: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.7)),
        labelSmall: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.5), letterSpacing: 1.0),
      ),

      // App Bar
      appBarTheme: const AppBarTheme(
        backgroundColor: darkBg,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
        iconTheme: IconThemeData(color: Colors.white),
      ),

      // Inputs
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: darkBorder)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: darkBorder)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: primaryBlue)),
      ),
    );
  }

  // Light theme can be standard, but we focus on Dark for Industrial look
  static ThemeData lightTheme() => ThemeData.light(); 
}