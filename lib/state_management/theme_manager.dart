// في lib/state_management/theme_manager.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeManager with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;
  bool _isAutoMode = true;
  bool _isInitialized = false;
  Timer? _scheduledTimer;
  
  static const String _themeKey = 'selectedThemeMode';
  static const String _autoModeKey = 'isAutoThemeMode';
  
  // ⏰ إعدادات الوقت (ساعات ودقائق)
  static const int _dayStartHour = 6;
  static const int _dayStartMinute = 0;    // 06:00 ☀️
  
  static const int _nightStartHour = 17;
  static const int _nightStartMinute = 0;  // 17:00 🌙 

  ThemeManager() {
    _initialize();
  }

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;
  bool get isAutoMode => _isAutoMode;
  bool get isInitialized => _isInitialized;

  Future<void> _initialize() async {
    await _loadTheme();
    _scheduleNextThemeChange();
    _isInitialized = true;
    notifyListeners();
  }

  //  تحديد الثيم بناءً على الوقت الحالي (بالدقائق)
  ThemeMode _getThemeByTime() {
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;
    
    final dayStart = _dayStartHour * 60 + _dayStartMinute;      // 06:00 = 360
    final nightStart = _nightStartHour * 60 + _nightStartMinute; // 18:10 = 1090
    
    debugPrint('⏰ Current time: ${now.hour}:${now.minute} ($currentMinutes min)');
    debugPrint('☀️ Day starts at: $_dayStartHour:$_dayStartMinute ($dayStart min)');
    debugPrint('🌙 Night starts at: $_nightStartHour:$_nightStartMinute ($nightStart min)');
    
    if (currentMinutes >= dayStart && currentMinutes < nightStart) {
      debugPrint('→ Theme: LIGHT ☀️');
      return ThemeMode.light;
    } else {
      debugPrint('→ Theme: DARK 🌙');
      return ThemeMode.dark;
    }
  }

  //  جدولة التغيير القادم بدقة
  void _scheduleNextThemeChange() {
    if (!_isAutoMode) return;
    
    _scheduledTimer?.cancel();
    
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;
    
    final dayStart = _dayStartHour * 60 + _dayStartMinute;
    final nightStart = _nightStartHour * 60 + _nightStartMinute;
    
    DateTime nextChange;
    
    if (currentMinutes >= nightStart || currentMinutes < dayStart) {
      // 🌙 نحن في الليل - التغيير القادم عند بداية النهار
      if (currentMinutes >= nightStart) {
        nextChange = DateTime(now.year, now.month, now.day + 1, _dayStartHour, _dayStartMinute, 0);
      } else {
        nextChange = DateTime(now.year, now.month, now.day, _dayStartHour, _dayStartMinute, 0);
      }
    } else {
      // ☀️ نحن في النهار - التغيير القادم عند بداية الليل
      nextChange = DateTime(now.year, now.month, now.day, _nightStartHour, _nightStartMinute, 0);
    }
    
    final duration = nextChange.difference(now);
    
    debugPrint('═══════════════════════════════════════');
    debugPrint('🕐 Next theme change in: ${duration.inHours}h ${duration.inMinutes % 60}m ${duration.inSeconds % 60}s');
    debugPrint('📅 Will change at: $nextChange');
    debugPrint('═══════════════════════════════════════');
    
    //  Timer واحد ينتظر حتى الوقت المحدد بالضبط
    _scheduledTimer = Timer(duration, () {
      debugPrint(' THEME CHANGING NOW!');
      _themeMode = _getThemeByTime();
      notifyListeners(); //  هذا يُحدّث الـ UI فوراً
      _scheduleNextThemeChange(); // جدولة التغيير التالي
    });
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    
    _isAutoMode = prefs.getBool(_autoModeKey) ?? true;
    
    if (_isAutoMode) {
      _themeMode = _getThemeByTime();
    } else {
      final themeIndex = prefs.getInt(_themeKey);
      if (themeIndex != null && themeIndex < ThemeMode.values.length) {
        _themeMode = ThemeMode.values[themeIndex];
      } else {
        _themeMode = ThemeMode.light;
      }
    }
  }

  Future<void> _saveTheme(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeKey, mode.index);
  }

  Future<void> _saveAutoMode(bool isAuto) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoModeKey, isAuto);
  }

  void setAutoMode(bool isAuto) {
    _isAutoMode = isAuto;
    _saveAutoMode(isAuto);
    
    if (isAuto) {
      _themeMode = _getThemeByTime();
      _scheduleNextThemeChange();
    } else {
      _scheduledTimer?.cancel();
    }
    notifyListeners();
  }

  void toggleAutoMode() {
    setAutoMode(!_isAutoMode);
  }

  void switchTheme() {
    _isAutoMode = false;
    _saveAutoMode(false);
    _scheduledTimer?.cancel();
    
    _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    _saveTheme(_themeMode);
    notifyListeners();
  }

  void setTheme(ThemeMode mode) {
    _isAutoMode = false;
    _saveAutoMode(false);
    _scheduledTimer?.cancel();
    
    _themeMode = mode;
    _saveTheme(mode);
    notifyListeners();
  }

  @override
  void dispose() {
    _scheduledTimer?.cancel();
    super.dispose();
  }
}