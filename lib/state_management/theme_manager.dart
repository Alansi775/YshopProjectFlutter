// في lib/state_management/theme_manager.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeManager with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light; // القيمة الافتراضية
  static const String _themeKey = 'selectedThemeMode';

  //  إضافة Constructor لتحميل الثيم فوراً
  ThemeManager() {
    _loadTheme(); 
  }

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  // 1. تحميل المظهر المحفوظ
  void _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    // يتم تخزين ThemeMode كـ int (0 لـ light، 1 لـ dark، إلخ)
    final themeIndex = prefs.getInt(_themeKey); 
    if (themeIndex != null && themeIndex < ThemeMode.values.length) {
      _themeMode = ThemeMode.values[themeIndex];
      notifyListeners();
    }
  }

  // 2. حفظ المظهر
  void _saveTheme(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeKey, mode.index); // حفظ الـ index
  }
  
  // 3. التبديل مع الحفظ
  void switchTheme() {
    _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    _saveTheme(_themeMode); // حفظ الاختيار الجديد
    notifyListeners();
  }
}