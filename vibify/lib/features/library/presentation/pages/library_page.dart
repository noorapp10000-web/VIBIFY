import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../providers/library_provider.dart';
import '../widgets/track_list_item.dart';

class LibraryPage extends ConsumerStatefulWidget {
  const LibraryPage({super.key});

  @override
  ConsumerState<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends ConsumerState<LibraryPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            title: Text(
              'Library',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            pinned: true,
            floating: true,
            actions: [
              IconButton(
                onPressed: () => context.push(AppRoutes.playlists),
                icon: const Icon(Icons.playlist_add_rounded),
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              isScrollable: true,
              indicatorColor: AppColors.primaryBeige,
              labelColor: AppColors.primaryBeige,
              unselectedLabelColor: Theme.of(context)
                  .colorScheme
                  .onBackground
                  .withOpacity(0.5),
              labelStyle: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              tabs: const [
                Tab(text: 'Playlists'),
                Tab(text: 'Favorites'),
                Tab(text: 'History'),
                Tab(text: 'Downloads'),
                Tab(text: 'Albums'),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: const [
            _PlaylistsTab(),
            _FavoritesTab(),
            _HistoryTab(),
            _DownloadsTab(),
            _AlbumsTab(),
          ],
        ),
      ),
    );
  }
}

class _PlaylistsTab extends ConsumerWidget {
  const _PlaylistsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlistsAsync = ref.watch(playlistsProvider);

    return playlistsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation(AppColors.primaryBeige),
        ),
      ),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (playlists) => playlists.isEmpty
          ? _EmptyLibraryState(
              icon: Icons.playlist_play_rounded,
              message: 'No playlists yet',
              action: 'Create Playlist',
              onAction: () => context.push(AppRoutes.playlists),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: playlists.length,
              itemBuilder: (context, index) {
                final playlist = playlists[index];
                return ListTile(
                  leading: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.primaryBeige.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.queue_music_rounded,
                      color: AppColors.primaryBeige,
                    ),
                  ),
                  title: Text(playlist.name,
                      style: Theme.of(context).textTheme.titleSmall),
                  subtitle: Text(
                    '${playlist.trackCount} songs',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () =>
                      context.push('${AppRoutes.playlists}/${playlist.id}'),
                );
              },
            ),
    );
  }
}

class _FavoritesTab extends ConsumerWidget {
  const _FavoritesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favAsync = ref.watch(libraryFavoritesProvider);

    return favAsync.when(
      loading: () => const Center(
          child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(AppColors.primaryBeige))),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (tracks) => tracks.isEmpty
          ? const _EmptyLibraryState(
              icon: Icons.favorite_border_rounded,
              message: 'No favorites yet',
              action: null,
              onAction: null,
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: tracks.length,
              itemBuilder: (context, index) => TrackListItem(
                track: tracks[index],
                onTap: () {
                  ref
                      .read(playerNotifierProvider.notifier)
                      .playAll(tracks, startIndex: index);
                  context.push(AppRoutes.player);
                },
              ),
            ),
    );
  }
}

class _HistoryTab extends ConsumerWidget {
  const _HistoryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(libraryHistoryProvider);

    return historyAsync.when(
      loading: () => const Center(
          child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(AppColors.primaryBeige))),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (tracks) => tracks.isEmpty
          ? const _EmptyLibraryState(
              icon: Icons.history_rounded,
              message: 'No history yet',
              action: null,
              onAction: null,
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: tracks.length,
              itemBuilder: (context, index) => TrackListItem(
                track: tracks[index],
                onTap: () {
                  ref
                      .read(playerNotifierProvider.notifier)
                      .playAll(tracks, startIndex: index);
                  context.push(AppRoutes.player);
                },
              ),
            ),
    );
  }
}

class _DownloadsTab extends ConsumerWidget {
  const _DownloadsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.download_rounded,
            size: 56,
            color:
                Theme.of(context).colorScheme.onBackground.withOpacity(0.3),
          ),
          const SizedBox(height: 12),
          Text('Downloads',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () => context.push(AppRoutes.downloads),
            child: const Text('Go to Downloads'),
          ),
        ],
      ),
    );
  }
}

class _AlbumsTab extends ConsumerWidget {
  const _AlbumsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const Center(
      child: Text('Albums from your local library appear here'),
    );
  }
}

class _EmptyLibraryState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? action;
  final VoidCallback? onAction;

  const _EmptyLibraryState({
    required this.icon,
    required this.message,
    required this.action,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 64,
            color: Theme.of(context)
                .colorScheme
                .onBackground
                .withOpacity(0.25),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onBackground
                      .withOpacity(0.5),
                ),
          ),
          if (action != null && onAction != null) ...[
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: onAction,
              child: Text(action!),
            ),
          ],
        ],
      ),
    );
  }
}
