import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Mode d'affichage de l'app. FitForge est dark-first : le sombre est le
/// mode par défaut, le clair est une préférence utilisateur.
enum AppThemeMode { dark, light }

class ThemeModeNotifier extends Notifier<AppThemeMode> {
  @override
  AppThemeMode build() => AppThemeMode.dark;

  void toggle() => state = state == AppThemeMode.dark
      ? AppThemeMode.light
      : AppThemeMode.dark;

  void set(AppThemeMode mode) => state = mode;
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, AppThemeMode>(
  ThemeModeNotifier.new,
);
