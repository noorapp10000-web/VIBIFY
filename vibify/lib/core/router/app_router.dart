import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/home/presentation/pages/home_page.dart';
import '../../features/library/presentation/pages/library_page.dart';
import '../../features/player/presentation/pages/player_page.dart';
import '../../features/search/presentation/pages/search_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../features/playlists/presentation/pages/playlist_detail_page.dart';
import '../../features/playlists/presentation/pages/playlists_page.dart';
import '../../features/downloads/presentation/pages/downloads_page.dart';
import '../../features/local_music/presentation/pages/local_music_page.dart';
import '../widgets/main_scaffold.dart';

part 'app_router.g.dart';

@riverpod
GoRouter appRouter(AppRouterRef ref) {
  return GoRouter(
    initialLocation: AppRoutes.home,
    debugLogDiagnostics: false,
    routes: [
      ShellRoute(
        builder: (context, state, child) => MainScaffold(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.home,
            name: 'home',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: HomePage(),
            ),
          ),
          GoRoute(
            path: AppRoutes.search,
            name: 'search',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: SearchPage(),
            ),
          ),
          GoRoute(
            path: AppRoutes.library,
            name: 'library',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: LibraryPage(),
            ),
          ),
          GoRoute(
            path: AppRoutes.localMusic,
            name: 'localMusic',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: LocalMusicPage(),
            ),
          ),
          GoRoute(
            path: AppRoutes.settings,
            name: 'settings',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: SettingsPage(),
            ),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.player,
        name: 'player',
        pageBuilder: (context, state) => CustomTransitionPage(
          child: const PlayerPage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 1),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: child,
            );
          },
        ),
      ),
      GoRoute(
        path: AppRoutes.playlists,
        name: 'playlists',
        pageBuilder: (context, state) => MaterialPage(
          child: const PlaylistsPage(),
        ),
      ),
      GoRoute(
        path: '${AppRoutes.playlists}/:id',
        name: 'playlistDetail',
        pageBuilder: (context, state) {
          final playlistId = state.pathParameters['id']!;
          return MaterialPage(
            child: PlaylistDetailPage(playlistId: playlistId),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.downloads,
        name: 'downloads',
        pageBuilder: (context, state) => const MaterialPage(
          child: DownloadsPage(),
        ),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Page not found: ${state.error}'),
      ),
    ),
  );
}

class AppRoutes {
  AppRoutes._();

  static const String home = '/';
  static const String search = '/search';
  static const String library = '/library';
  static const String localMusic = '/local-music';
  static const String player = '/player';
  static const String playlists = '/playlists';
  static const String downloads = '/downloads';
  static const String settings = '/settings';
}
