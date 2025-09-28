import 'package:flutter/material.dart';

class ThemeManager with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light; // القيمة الافتراضية

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  void toggleTheme(bool isOn) {
    _themeMode = isOn ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }
  
  // دالة لتغيير الـ theme بالضغط على زر
  void switchTheme() {
    _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }
}