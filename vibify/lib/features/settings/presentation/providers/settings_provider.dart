import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../../core/constants/app_constants.dart';

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>(
  (ref) => ThemeModeNotifier(),
);

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.system) {
    _load();
  }

  void _load() {
    final box = Hive.box(AppConstants.settingsBox);
    final stored = box.get(AppConstants.themeKey, defaultValue: 'system');
    state = _fromString(stored);
  }

  Future<void> setTheme(ThemeMode mode) async {
    final box = Hive.box(AppConstants.settingsBox);
    await box.put(AppConstants.themeKey, _toString(mode));
    state = mode;
  }

  ThemeMode _fromString(String s) {
    switch (s) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  String _toString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      default:
        return 'system';
    }
  }
}

final audioQualityProvider =
    StateNotifierProvider<AudioQualityNotifier, AudioQuality>(
  (ref) => AudioQualityNotifier(),
);

enum AudioQuality { low, medium, high, lossless }

class AudioQualityNotifier extends StateNotifier<AudioQuality> {
  AudioQualityNotifier() : super(AudioQuality.high) {
    _load();
  }

  void _load() {
    final box = Hive.box(AppConstants.settingsBox);
    final stored =
        box.get(AppConstants.audioQualityKey, defaultValue: 'high');
    state = AudioQuality.values.firstWhere(
      (q) => q.name == stored,
      orElse: () => AudioQuality.high,
    );
  }

  Future<void> setQuality(AudioQuality quality) async {
    final box = Hive.box(AppConstants.settingsBox);
    await box.put(AppConstants.audioQualityKey, quality.name);
    state = quality;
  }
}
