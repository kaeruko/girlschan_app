import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService extends ChangeNotifier {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  static const String _kFontSizeKey = 'settings_font_size';
  static const String _kBgColorKey = 'settings_bg_color';

  // デフォルト値
  double _fontSize = 14.0;
  int _bgColorValue = 0xFFFFFFFF; // White

  double get fontSize => _fontSize;
  Color get backgroundColor => Color(_bgColorValue);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _fontSize = prefs.getDouble(_kFontSizeKey) ?? 14.0;
    _bgColorValue = prefs.getInt(_kBgColorKey) ?? 0xFFFFFFFF;
    notifyListeners();
  }

  Future<void> setFontSize(double size) async {
    _fontSize = size;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kFontSizeKey, size);
  }

  Future<void> setBackgroundColor(Color color) async {
    // ignore: deprecated_member_use
    _bgColorValue = color.value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    // ignore: deprecated_member_use
    await prefs.setInt(_kBgColorKey, color.value);
  }

  Color getBackgroundColor(BuildContext context) {
    return backgroundColor;
  }

  Color getTextColor(BuildContext context) {
    return backgroundColor.computeLuminance() < 0.5 ? Colors.white : Colors.black;
  }
}
