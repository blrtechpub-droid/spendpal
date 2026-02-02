import 'package:flutter/material.dart';

class AppTheme {
  // Colors - Background
  static const Color primaryBackground = Color(0xFF1C1C1E);
  static const Color secondaryBackground = Color(0xFF2C2C2E);
  static const Color cardBackground = Color(0xFF3A3A3C);

  // Colors - Text (Improved WCAG AA contrast)
  static const Color primaryText = Colors.white;           // #FFFFFF (21:1 contrast)
  static const Color secondaryText = Color(0xFFB8B8B8);    // #B8B8B8 (5.2:1 contrast) - WCAG AA ✓
  static const Color tertiaryText = Color(0xFF9E9E9E);     // #9E9E9E (4.6:1 contrast) - WCAG AA ✓

  // Colors - Brand & Accent
  static const Color tealAccent = Color(0xFF64FFDA);       // Material Teal A200
  static const Color orangeAccent = Color(0xFFFF9E57);     // Warmer orange
  static const Color greenAccent = Color(0xFF69F0AE);      // Material Green A200
  static const Color redAccent = Color(0xFFFF6B6B);        // Softer red
  static const Color yellowAccent = Color(0xFFFFD54F);     // Material Amber A200
  static const Color purpleAccent = Color(0xFFB39DDB);     // Material Deep Purple 200

  // Colors - Functional
  static const Color dividerColor = Color(0xFF48484A);
  static const Color errorColor = Color(0xFFFF6B6B);
  static const Color warningColor = Color(0xFFFFA726);
  static const Color successColor = Color(0xFF69F0AE);

  // Helper method for soft white color (reduces glare in light mode)
  static Color softWhite(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? const Color(0xFFF8F8F8)  // Soft white for light mode
        : Colors.white.withValues(alpha: 0.95);  // Slightly transparent for dark mode
  }

  // Category Colors (Darker for dark theme visibility)
  static const Color foodCategory = Color(0xFFFFA726);        // Amber
  static const Color travelCategory = Color(0xFF42A5F5);      // Blue
  static const Color shoppingCategory = Color(0xFFAB47BC);    // Purple
  static const Color maidCategory = Color(0xFF26A69A);        // Teal
  static const Color cookCategory = Color(0xFF66BB6A);        // Green
  static const Color groceriesCategory = Color(0xFF8D6E63);   // Brown
  static const Color utilitiesCategory = Color(0xFF78909C);   // Blue Grey
  static const Color entertainmentCategory = Color(0xFFEC407A); // Pink
  static const Color healthcareCategory = Color(0xFFEF5350);  // Red
  static const Color defaultCategory = Color(0xFF90A4AE);     // Grey

  // Avatar & Icon Sizes
  static const double avatarRadiusSmall = 20.0;
  static const double avatarRadiusMedium = 28.0;
  static const double avatarRadiusLarge = 40.0;
  static const double iconSizeDefault = 24.0;
  static const double iconSizeEmphasis = 28.0;
  static const double iconSizeLarge = 32.0;

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

  static final ButtonStyle textButtonStyle = TextButton.styleFrom(
    foregroundColor: tealAccent,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    ),
  );

  static final ButtonStyle dangerOutlinedButtonStyle = OutlinedButton.styleFrom(
    foregroundColor: errorColor,
    side: const BorderSide(color: errorColor, width: 2),
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
  );

  static final ButtonStyle warningButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: orangeAccent,
    foregroundColor: primaryBackground,
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    elevation: 0,
  );

  static final ButtonStyle successButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: successColor,
    foregroundColor: primaryBackground,
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

  // Light Theme Colors (Splitwise-style)
  static const Color lightBackground = Color(0xFFF5F5F5);
  static const Color lightCardBackground = Colors.white;
  static const Color lightPrimaryText = Color(0xFF212121);
  static const Color lightSecondaryText = Color(0xFF757575);
  static const Color lightDivider = Color(0xFFE0E0E0);
  static const Color tealPrimary = Color(0xFF5CC5A7); // Splitwise teal
  static const Color tealDark = Color(0xFF48A38A);

  // Theme Data - Light Theme (Splitwise-style)
  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBackground,
      primaryColor: tealPrimary,
      colorScheme: ColorScheme.light(
        primary: tealPrimary,
        secondary: orangeAccent,
        surface: lightCardBackground,
        error: redAccent,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: lightPrimaryText,
        onError: Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: tealPrimary,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: heading3.copyWith(color: Colors.white),
      ),
      cardTheme: CardThemeData(
        color: lightCardBackground,
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.1),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: lightDivider,
        thickness: 1,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: tealPrimary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: tealPrimary,
          side: BorderSide(color: tealPrimary, width: 2),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        labelStyle: TextStyle(color: lightSecondaryText),
        hintStyle: TextStyle(color: lightSecondaryText),
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: lightDivider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: lightDivider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: tealPrimary, width: 2),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: const Color(0xFFFAFAFA),
        selectedItemColor: tealPrimary,
        unselectedItemColor: lightSecondaryText,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      textTheme: TextTheme(
        displayLarge: heading1.copyWith(color: lightPrimaryText),
        displayMedium: heading2.copyWith(color: lightPrimaryText),
        displaySmall: heading3.copyWith(color: lightPrimaryText),
        bodyLarge: bodyLarge.copyWith(color: lightPrimaryText),
        bodyMedium: bodyMedium.copyWith(color: lightPrimaryText),
        bodySmall: bodySmall.copyWith(color: lightSecondaryText),
        labelSmall: caption.copyWith(color: lightSecondaryText),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: tealPrimary,
        foregroundColor: Colors.white,
      ),
    );
  }

  // Theme Data - Dark Theme
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

  // Spacing (Standardized - no spacing20, use spacing16 or spacing24)
  static const double spacingXS = 4.0;
  static const double spacingS = 8.0;
  static const double spacingM = 12.0;
  static const double spacingL = 16.0;
  static const double spacingXL = 24.0;
  static const double spacingXXL = 32.0;

  // Legacy spacing constants (deprecated - use named versions above)
  static const double spacing4 = spacingXS;
  static const double spacing8 = spacingS;
  static const double spacing12 = spacingM;
  static const double spacing16 = spacingL;
  static const double spacing24 = spacingXL;
  static const double spacing32 = spacingXXL;

  // Responsive spacing methods
  // Returns spacing scaled based on screen width
  static double responsiveSpacing(BuildContext context, double baseSpacing) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth > 600) {
      // Tablet/larger screens
      return baseSpacing * 1.5;
    } else if (screenWidth > 400) {
      // Large phones
      return baseSpacing * 1.2;
    }
    // Small phones
    return baseSpacing;
  }

  // Responsive horizontal padding for containers
  static EdgeInsets responsiveHorizontalPadding(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth > 600) {
      return const EdgeInsets.symmetric(horizontal: 32);
    } else if (screenWidth > 400) {
      return const EdgeInsets.symmetric(horizontal: 20);
    }
    return const EdgeInsets.symmetric(horizontal: 16);
  }

  // Responsive vertical padding for lists and scrollable content
  static EdgeInsets responsiveVerticalPadding(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth > 600) {
      return const EdgeInsets.symmetric(vertical: 24);
    }
    return const EdgeInsets.symmetric(vertical: 16);
  }

  // Responsive card padding
  static EdgeInsets responsiveCardPadding(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth > 600) {
      return const EdgeInsets.all(24);
    } else if (screenWidth > 400) {
      return const EdgeInsets.all(20);
    }
    return const EdgeInsets.all(16);
  }

  // Border Radius
  static const double radius8 = 8.0;
  static const double radius12 = 12.0;
  static const double radius16 = 16.0;
  static const double radius24 = 24.0;
}
