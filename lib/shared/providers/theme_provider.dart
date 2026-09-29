import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Valeurs alignées sur le web : systeme | clair | sombre
enum AppThemeMode {
  systeme,
  clair,
  sombre;

  String get dbValue => name;

  static AppThemeMode fromDb(String? value) {
    return AppThemeMode.values.firstWhere(
      (e) => e.name == value,
      orElse: () => AppThemeMode.systeme,
    );
  }

  ThemeMode get flutterMode => switch (this) {
        AppThemeMode.systeme => ThemeMode.system,
        AppThemeMode.clair => ThemeMode.light,
        AppThemeMode.sombre => ThemeMode.dark,
      };
}

class ThemeModeNotifier extends StateNotifier<AppThemeMode> {
  ThemeModeNotifier(this._prefs)
      : super(
          AppThemeMode.fromDb(_prefs.getString(_key)),
        );

  static const _key = 'togoai-theme';
  final SharedPreferences _prefs;

  Future<void> setMode(AppThemeMode mode) async {
    state = mode;
    await _prefs.setString(_key, mode.dbValue);
  }

  void syncFromProfile(String? theme) {
    if (theme == null) return;
    state = AppThemeMode.fromDb(theme);
  }
}

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Override in main()');
});

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, AppThemeMode>((ref) {
  return ThemeModeNotifier(ref.watch(sharedPreferencesProvider));
});
