class AppConstants {
  AppConstants._();

  static const String appName = 'Vibify';
  static const String appVersion = '1.0.0';

  // Hive box names
  static const String settingsBox = 'settings_box';
  static const String playlistBox = 'playlist_box';
  static const String downloadBox = 'download_box';
  static const String historyBox = 'history_box';
  static const String favoritesBox = 'favorites_box';
  static const String cacheBox = 'cache_box';

  // Settings keys
  static const String themeKey = 'theme_mode';
  static const String audioQualityKey = 'audio_quality';
  static const String sleepTimerKey = 'sleep_timer';
  static const String crossfadeDurationKey = 'crossfade_duration';
  static const String equaliserEnabledKey = 'equaliser_enabled';

  // Audio
  static const int maxQueueSize = 500;
  static const int defaultCrossfadeDuration = 3;
  static const double defaultPlaybackSpeed = 1.0;

  // Network
  static const int networkTimeout = 30000;
  static const int maxRetries = 3;

  // Cache
  static const int maxCacheSize = 512 * 1024 * 1024; // 512 MB
  static const int imageCacheMaxItems = 200;
  static const int imageCacheMaxBytes = 50 * 1024 * 1024; // 50 MB

  // Pagination
  static const int defaultPageSize = 20;
  static const int searchPageSize = 30;

  // Local music
  static const List<String> supportedFormats = [
    'mp3', 'm4a', 'aac', 'flac', 'wav', 'ogg', 'opus',
  ];

  // YouTube
  static const String youtubeBaseUrl = 'https://www.youtube.com';
  static const int ytStreamRefreshBufferSeconds = 60;
}
