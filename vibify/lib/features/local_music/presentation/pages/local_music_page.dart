import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../library/presentation/widgets/track_list_item.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../providers/local_music_provider.dart';

class LocalMusicPage extends ConsumerStatefulWidget {
  const LocalMusicPage({super.key});

  @override
  ConsumerState<LocalMusicPage> createState() => _LocalMusicPageState();
}

class _LocalMusicPageState extends ConsumerState<LocalMusicPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(localMusicNotifierProvider.notifier).init();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(localMusicNotifierProvider);

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverAppBar(
            title: Text(
              'Phone Music',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            pinned: true,
            floating: true,
            actions: [
              IconButton(
                onPressed: () =>
                    ref.read(localMusicNotifierProvider.notifier).refresh(),
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              isScrollable: true,
              indicatorColor: AppColors.primaryBeige,
              labelColor: AppColors.primaryBeige,
              unselectedLabelColor: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.5),
              labelStyle: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              tabs: [
                Tab(text: 'Songs (${state.tracks.length})'),
                Tab(text: 'Albums (${state.albums.length})'),
                Tab(text: 'Artists (${state.artists.length})'),
                Tab(text: 'Folders (${state.folders.length})'),
              ],
            ),
          ),
        ],
        body: state.isLoading
            ? const Center(
                child: CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation(AppColors.primaryBeige)),
              )
            : state.permissionDenied
                ? _PermissionRequest(
                    onRequest: () => ref
                        .read(localMusicNotifierProvider.notifier)
                        .requestPermission(),
                  )
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _SongsTab(state: state),
                      _AlbumsTab(state: state),
                      _ArtistsTab(state: state),
                      _FoldersTab(state: state),
                    ],
                  ),
      ),
    );
  }
}

class _SongsTab extends ConsumerWidget {
  final LocalMusicState state;

  const _SongsTab({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.tracks.isEmpty) {
      return const Center(child: Text('No music files found'));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      physics: const BouncingScrollPhysics(),
      itemCount: state.tracks.length,
      itemBuilder: (context, index) => TrackListItem(
        track: state.tracks[index],
        onTap: () {
          ref
              .read(playerNotifierProvider.notifier)
              .playAll(state.tracks, startIndex: index);
          context.push(AppRoutes.player);
        },
      ),
    );
  }
}

class _AlbumsTab extends StatelessWidget {
  final LocalMusicState state;

  const _AlbumsTab({required this.state});

  @override
  Widget build(BuildContext context) {
    if (state.albums.isEmpty) {
      return const Center(child: Text('No albums found'));
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: state.albums.length,
      itemBuilder: (context, index) {
        final album = state.albums[index];
        return _AlbumCard(name: album.name, songCount: album.numOfSongs);
      },
    );
  }
}

class _ArtistsTab extends StatelessWidget {
  final LocalMusicState state;

  const _ArtistsTab({required this.state});

  @override
  Widget build(BuildContext context) {
    if (state.artists.isEmpty) {
      return const Center(child: Text('No artists found'));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: state.artists.length,
      itemBuilder: (context, index) {
        final artist = state.artists[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: AppColors.primaryBeige.withValues(alpha: 0.2),
            child: Text(
              artist.name.isNotEmpty ? artist.name[0].toUpperCase() : '?',
              style: const TextStyle(
                color: AppColors.primaryBeige,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          title: Text(artist.name,
              style: Theme.of(context).textTheme.titleSmall),
          subtitle: Text(
            '${artist.numOfTracks} songs',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        );
      },
    );
  }
}

class _FoldersTab extends StatelessWidget {
  final LocalMusicState state;

  const _FoldersTab({required this.state});

  @override
  Widget build(BuildContext context) {
    if (state.folders.isEmpty) {
      return const Center(child: Text('No folders found'));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: state.folders.length,
      itemBuilder: (context, index) {
        final folder = state.folders[index];
        final name = folder.split('/').last;
        return ListTile(
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primaryBeige.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.folder_rounded,
                color: AppColors.primaryBeige),
          ),
          title: Text(name, style: Theme.of(context).textTheme.titleSmall),
          subtitle: Text(
            folder,
            style: Theme.of(context).textTheme.bodySmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
        );
      },
    );
  }
}

class _AlbumCard extends StatelessWidget {
  final String name;
  final int songCount;

  const _AlbumCard({required this.name, required this.songCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.primaryBeige.withValues(alpha: 0.15),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(14)),
              ),
              child: const Center(
                child: Icon(Icons.album_rounded,
                    size: 48, color: AppColors.primaryBeige),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '$songCount songs',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionRequest extends StatelessWidget {
  final VoidCallback onRequest;

  const _PermissionRequest({required this.onRequest});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.folder_off_rounded,
              size: 72,
              color: AppColors.primaryBeige,
            ),
            const SizedBox(height: 20),
            Text(
              'Storage Permission Required',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Vibify needs access to your music files to scan your local library.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: onRequest,
              icon: const Icon(Icons.folder_open_rounded),
              label: const Text('Grant Permission'),
            ),
          ],
        ),
      ),
    );
  }
}
