import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;

  // Light theme colors
  Color _primaryColorLight = const Color(0xFF1E88E5); // Blue
  Color _secondaryColorLight = const Color(0xFF26A69A); // Teal

  // Dark theme colors
  Color _primaryColorDark = const Color(0xFF0D47A1); // Dark Blue
  Color _secondaryColorDark = const Color(0xFF00796B); // Dark Teal

  // Getters
  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  // Light theme
  ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.light(
          primary: _primaryColorLight,
          secondary: _secondaryColorLight,
          surface: Colors.white,
          background: const Color(0xFFF5F5F5),
          error: Colors.red.shade700,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: _primaryColorLight,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: _primaryColorLight,
            foregroundColor: Colors.white,
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        cardTheme: CardTheme(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          filled: true,
          fillColor: Colors.grey.shade50,
        ),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(fontWeight: FontWeight.bold),
          headlineMedium: TextStyle(fontWeight: FontWeight.bold),
          titleLarge: TextStyle(fontWeight: FontWeight.bold),
        ),
      );

  // Dark theme
  ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.dark(
          primary: _primaryColorDark,
          secondary: _secondaryColorDark,
          surface: const Color(0xFF121212),
          background: const Color(0xFF121212),
          error: Colors.red.shade300,
        ),
        scaffoldBackgroundColor: const Color(0xFF121212),
        appBarTheme: AppBarTheme(
          backgroundColor: _primaryColorDark,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: _primaryColorDark,
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        cardTheme: CardTheme(
          color: const Color(0xFF1E1E1E),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          filled: true,
          fillColor: const Color(0xFF1E1E1E),
        ),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(fontWeight: FontWeight.bold),
          headlineMedium: TextStyle(fontWeight: FontWeight.bold),
          titleLarge: TextStyle(fontWeight: FontWeight.bold),
        ),
      );

  ThemeProvider() {
    _loadThemePreference();
  }

  // Load saved theme preference
  Future<void> _loadThemePreference() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      // Load theme mode
      final String? themeModeString = prefs.getString('theme_mode');
      if (themeModeString != null) {
        if (themeModeString == 'dark') {
          _themeMode = ThemeMode.dark;
        } else if (themeModeString == 'light') {
          _themeMode = ThemeMode.light;
        } else {
          _themeMode = ThemeMode.system;
        }
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading theme preference: $e');
    }
  }

  // Toggle between light and dark themes
  Future<void> toggleTheme() async {
    if (_themeMode == ThemeMode.light) {
      _themeMode = ThemeMode.dark;
    } else {
      _themeMode = ThemeMode.light;
    }

    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'theme_mode', _themeMode == ThemeMode.dark ? 'dark' : 'light');
    } catch (e) {
      debugPrint('Error saving theme preference: $e');
    }

    notifyListeners();
  }

  // Set specific theme
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;

    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      String themeString = 'system';

      if (mode == ThemeMode.dark) {
        themeString = 'dark';
      } else if (mode == ThemeMode.light) {
        themeString = 'light';
      }

      await prefs.setString('theme_mode', themeString);
    } catch (e) {
      debugPrint('Error saving theme preference: $e');
    }

    notifyListeners();
  }
}
