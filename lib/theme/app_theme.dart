import 'package:flutter/material.dart';

class AppTheme {
  // Colors
  static const Color primaryBackground = Color(0xFF1C1C1E);
  static const Color secondaryBackground = Color(0xFF2C2C2E);
  static const Color cardBackground = Color(0xFF3A3A3C);

  static const Color primaryText = Colors.white;
  static const Color secondaryText = Color(0xFFAAAAAA);
  static const Color tertiaryText = Color(0xFF666666);

  static const Color tealAccent = Colors.teal;
  static const Color orangeAccent = Colors.orange;
  static const Color greenAccent = Colors.green;
  static const Color redAccent = Colors.red;

  static const Color dividerColor = Color(0xFF48484A);

  // Category Colors
  static final Color foodCategory = Colors.yellow.shade100;
  static final Color travelCategory = Colors.blue.shade100;
  static final Color shoppingCategory = Colors.purple.shade100;
  static final Color maidCategory = Colors.teal.shade100;
  static final Color cookCategory = Colors.green.shade100;
  static const Color defaultCategory = Color(0xFFE0E0E0);

  // Text Styles
  static const TextStyle heading1 = TextStyle(
    color: primaryText,
    fontSize: 32,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle heading2 = TextStyle(
    color: primaryText,
    fontSize: 24,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle heading3 = TextStyle(
    color: primaryText,
    fontSize: 20,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle bodyLarge = TextStyle(
    color: primaryText,
    fontSize: 16,
    fontWeight: FontWeight.normal,
  );

  static const TextStyle bodyMedium = TextStyle(
    color: primaryText,
    fontSize: 14,
    fontWeight: FontWeight.normal,
  );

  static const TextStyle bodySmall = TextStyle(
    color: secondaryText,
    fontSize: 12,
    fontWeight: FontWeight.normal,
  );

  static const TextStyle caption = TextStyle(
    color: tertiaryText,
    fontSize: 10,
    fontWeight: FontWeight.normal,
  );

  // Button Styles
  static final ButtonStyle primaryButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: tealAccent,
    foregroundColor: Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    elevation: 0,
  );

  static final ButtonStyle secondaryButtonStyle = OutlinedButton.styleFrom(
    foregroundColor: primaryText,
    side: const BorderSide(color: tealAccent, width: 2),
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
  );

  static final ButtonStyle dangerButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: redAccent,
    foregroundColor: Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    elevation: 0,
  );

  // Input Decoration
  static InputDecoration inputDecoration({
    required String labelText,
    String? hintText,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      labelStyle: const TextStyle(color: secondaryText),
      hintStyle: const TextStyle(color: tertiaryText),
      filled: true,
      fillColor: cardBackground,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: tealAccent, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: redAccent, width: 2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: redAccent, width: 2),
      ),
    );
  }

  // Card Decoration
  static BoxDecoration cardDecoration = BoxDecoration(
    color: cardBackground,
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.2),
        blurRadius: 8,
        offset: const Offset(0, 4),
      ),
    ],
  );

  // Theme Data
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: primaryBackground,
      primaryColor: tealAccent,
      colorScheme: const ColorScheme.dark(
        primary: tealAccent,
        secondary: orangeAccent,
        surface: secondaryBackground,
        error: redAccent,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryBackground,
        elevation: 0,
        iconTheme: IconThemeData(color: primaryText),
        titleTextStyle: heading3,
      ),
      cardTheme: const CardThemeData(
        color: cardBackground,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: dividerColor,
        thickness: 1,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: primaryButtonStyle,
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: secondaryButtonStyle,
      ),
      inputDecorationTheme: InputDecorationTheme(
        labelStyle: const TextStyle(color: secondaryText),
        hintStyle: const TextStyle(color: tertiaryText),
        filled: true,
        fillColor: cardBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: tealAccent, width: 2),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: secondaryBackground,
        selectedItemColor: tealAccent,
        unselectedItemColor: secondaryText,
        type: BottomNavigationBarType.fixed,
      ),
      textTheme: const TextTheme(
        displayLarge: heading1,
        displayMedium: heading2,
        displaySmall: heading3,
        bodyLarge: bodyLarge,
        bodyMedium: bodyMedium,
        bodySmall: bodySmall,
        labelSmall: caption,
      ),
    );
  }

  // Spacing
  static const double spacing4 = 4.0;
  static const double spacing8 = 8.0;
  static const double spacing12 = 12.0;
  static const double spacing16 = 16.0;
  static const double spacing20 = 20.0;
  static const double spacing24 = 24.0;
  static const double spacing32 = 32.0;

  // Border Radius
  static const double radius8 = 8.0;
  static const double radius12 = 12.0;
  static const double radius16 = 16.0;
  static const double radius24 = 24.0;
}
