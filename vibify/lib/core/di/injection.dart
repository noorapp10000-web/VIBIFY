import 'package:get_it/get_it.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:dio/dio.dart';

import '../network/network_client.dart';
import '../network/network_info.dart';
import '../../features/player/data/datasources/audio_handler.dart';
import '../../features/player/data/repositories/player_repository_impl.dart';
import '../../features/player/domain/repositories/player_repository.dart';
import '../../features/player/domain/usecases/play_track_usecase.dart';
import '../../features/player/domain/usecases/manage_queue_usecase.dart';
import '../../features/search/data/datasources/youtube_datasource.dart';
import '../../features/search/data/repositories/search_repository_impl.dart';
import '../../features/search/domain/repositories/search_repository.dart';
import '../../features/search/domain/usecases/search_tracks_usecase.dart';
import '../../features/local_music/data/datasources/local_music_datasource.dart';
import '../../features/local_music/data/repositories/local_music_repository_impl.dart';
import '../../features/local_music/domain/repositories/local_music_repository.dart';
import '../../features/local_music/domain/usecases/get_local_tracks_usecase.dart';
import '../../features/playlists/data/datasources/playlist_datasource.dart';
import '../../features/playlists/data/repositories/playlist_repository_impl.dart';
import '../../features/playlists/domain/repositories/playlist_repository.dart';
import '../../features/playlists/domain/usecases/playlist_usecases.dart';
import '../../features/downloads/data/datasources/download_datasource.dart';
import '../../features/downloads/data/repositories/download_repository_impl.dart';
import '../../features/downloads/domain/repositories/download_repository.dart';
import '../../features/downloads/domain/usecases/download_usecases.dart';
import '../constants/app_constants.dart';

final GetIt sl = GetIt.instance;

Future<void> setupDependencies() async {
  // Hive boxes
  await Hive.openBox(AppConstants.settingsBox);
  await Hive.openBox(AppConstants.playlistBox);
  await Hive.openBox(AppConstants.downloadBox);
  await Hive.openBox(AppConstants.historyBox);
  await Hive.openBox(AppConstants.favoritesBox);
  await Hive.openBox(AppConstants.cacheBox);

  // Core
  sl.registerLazySingleton<Dio>(() => NetworkClient.createDio());
  sl.registerLazySingleton<NetworkInfo>(() => NetworkInfoImpl());

  // Audio handler — init runs in background, does NOT block startup
  final audioHandler = VibifyAudioHandler.create();
  sl.registerSingleton<VibifyAudioHandler>(audioHandler);

  // Search / YouTube
  sl.registerLazySingleton<YoutubeDatasource>(() => YoutubeDatasourceImpl());
  sl.registerLazySingleton<SearchRepository>(
    () => SearchRepositoryImpl(sl(), sl()),
  );
  sl.registerLazySingleton(() => SearchTracksUsecase(sl()));

  // Player
  sl.registerLazySingleton<PlayerRepository>(
    () => PlayerRepositoryImpl(sl()),
  );
  sl.registerLazySingleton(() => PlayTrackUsecase(sl()));
  sl.registerLazySingleton(() => ManageQueueUsecase(sl()));

  // Local music
  sl.registerLazySingleton<LocalMusicDatasource>(
    () => LocalMusicDatasourceImpl(),
  );
  sl.registerLazySingleton<LocalMusicRepository>(
    () => LocalMusicRepositoryImpl(sl()),
  );
  sl.registerLazySingleton(() => GetLocalTracksUsecase(sl()));

  // Playlists
  sl.registerLazySingleton<PlaylistDatasource>(
    () => PlaylistDatasourceImpl(Hive.box(AppConstants.playlistBox)),
  );
  sl.registerLazySingleton<PlaylistRepository>(
    () => PlaylistRepositoryImpl(sl()),
  );
  sl.registerLazySingleton(() => PlaylistUsecases(sl()));

  // Downloads
  sl.registerLazySingleton<DownloadDatasource>(
    () => DownloadDatasourceImpl(Hive.box(AppConstants.downloadBox)),
  );
  sl.registerLazySingleton<DownloadRepository>(
    () => DownloadRepositoryImpl(sl(), sl()),
  );
  sl.registerLazySingleton(() => DownloadUsecases(sl()));
}
