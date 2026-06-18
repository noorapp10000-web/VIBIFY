import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../downloads/domain/entities/download_item.dart';
import '../../../downloads/presentation/providers/downloads_provider.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../../../playlists/presentation/providers/playlists_provider.dart';
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
                  .onSurface
                  .withValues(alpha: 0.5),
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
    final playlistsAsync = ref.watch(playlistsNotifierProvider);

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
                      color: AppColors.primaryBeige.withValues(alpha: 0.15),
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
    final downloadsAsync = ref.watch(downloadsNotifierProvider);

    return downloadsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation(AppColors.primaryBeige),
        ),
      ),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (downloads) {
        if (downloads.isEmpty) {
          return const _EmptyLibraryState(
            icon: Icons.download_rounded,
            message: 'No downloads yet',
            action: null,
            onAction: null,
          );
        }

        final active = downloads.where((d) => d.isDownloading || d.isQueued).toList();
        final completed = downloads.where((d) => d.isCompleted).toList();
        final failed = downloads.where((d) => d.isFailed).toList();

        return ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 16),
          children: [
            if (active.isNotEmpty) ...[
              _SectionHeader(
                label: 'Downloading (${active.length})',
                trailing: null,
              ),
              ...active.map((item) => _DownloadTileInline(
                    item: item,
                    ref: ref,
                  )),
            ],
            if (failed.isNotEmpty) ...[
              _SectionHeader(
                label: 'Failed (${failed.length})',
                trailing: null,
              ),
              ...failed.map((item) => _DownloadTileInline(
                    item: item,
                    ref: ref,
                  )),
            ],
            if (completed.isNotEmpty) ...[
              _SectionHeader(
                label: 'Downloaded (${completed.length})',
                trailing: TextButton(
                  onPressed: () => ref
                      .read(downloadsNotifierProvider.notifier)
                      .clearCompleted(),
                  child: const Text(
                    'Clear All',
                    style: TextStyle(
                      color: AppColors.primaryBeige,
                      fontSize: 13,
                      fontFamily: 'Inter',
                    ),
                  ),
                ),
              ),
              ...completed.map((item) => _DownloadTileInline(
                    item: item,
                    ref: ref,
                  )),
            ],
          ],
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final Widget? trailing;

  const _SectionHeader({required this.label, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.5),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  )),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _DownloadTileInline extends StatelessWidget {
  final DownloadItem item;
  final WidgetRef ref;

  const _DownloadTileInline({required this.item, required this.ref});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: _statusColor().withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(_statusIcon(), color: _statusColor(), size: 22),
      ),
      title: Text(
        item.track.title,
        style: Theme.of(context).textTheme.titleSmall,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            item.track.artist,
            style: Theme.of(context).textTheme.bodySmall,
            maxLines: 1,
          ),
          if (item.isDownloading || item.isQueued) ...[
            const SizedBox(height: 5),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: item.isQueued ? null : item.progress,
                backgroundColor: AppColors.primaryBeige.withValues(alpha: 0.12),
                valueColor:
                    const AlwaysStoppedAnimation(AppColors.primaryBeige),
                minHeight: 3,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              item.isQueued
                  ? 'Queued…'
                  : '${(item.progress * 100).toInt()}%  •  ${_sizeText()}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.primaryBeige,
                    fontSize: 11,
                  ),
            ),
          ],
          if (item.isFailed)
            Text(
              item.errorMessage ?? 'Download failed — tap retry',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.red,
                    fontSize: 11,
                  ),
            ),
        ],
      ),
      isThreeLine: item.isDownloading || item.isQueued || item.isFailed,
      trailing: _buildAction(context),
    );
  }

  String _sizeText() {
    if (item.fileSizeBytes == null) return '';
    final mb = item.fileSizeBytes! / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }

  Widget? _buildAction(BuildContext context) {
    if (item.isDownloading) {
      return IconButton(
        onPressed: () =>
            ref.read(downloadsNotifierProvider.notifier).pause(item.id),
        icon: const Icon(Icons.pause_rounded),
        color: AppColors.primaryBeige,
        tooltip: 'Pause',
      );
    }
    if (item.isPaused) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: () =>
                ref.read(downloadsNotifierProvider.notifier).resume(item.id),
            icon: const Icon(Icons.play_arrow_rounded),
            color: AppColors.primaryBeige,
            tooltip: 'Resume',
          ),
          IconButton(
            onPressed: () =>
                ref.read(downloadsNotifierProvider.notifier).cancel(item.id),
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Cancel',
          ),
        ],
      );
    }
    if (item.isFailed) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: () =>
                ref.read(downloadsNotifierProvider.notifier).retry(item.id),
            icon: const Icon(Icons.refresh_rounded),
            color: AppColors.primaryBeige,
            tooltip: 'Retry',
          ),
          IconButton(
            onPressed: () =>
                ref.read(downloadsNotifierProvider.notifier).delete(item.id),
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: 'Delete',
          ),
        ],
      );
    }
    if (item.isCompleted) {
      return IconButton(
        onPressed: () =>
            ref.read(downloadsNotifierProvider.notifier).delete(item.id),
        icon: const Icon(Icons.delete_outline_rounded),
        tooltip: 'Remove',
      );
    }
    return null;
  }

  Color _statusColor() {
    switch (item.status) {
      case DownloadStatus.completed:
        return Colors.green;
      case DownloadStatus.downloading:
        return AppColors.primaryBeige;
      case DownloadStatus.paused:
        return Colors.orange;
      case DownloadStatus.failed:
        return Colors.red;
      default:
        return AppColors.primaryBeige;
    }
  }

  IconData _statusIcon() {
    switch (item.status) {
      case DownloadStatus.completed:
        return Icons.download_done_rounded;
      case DownloadStatus.downloading:
        return Icons.downloading_rounded;
      case DownloadStatus.paused:
        return Icons.pause_circle_rounded;
      case DownloadStatus.failed:
        return Icons.error_outline_rounded;
      case DownloadStatus.queued:
        return Icons.queue_rounded;
      default:
        return Icons.download_rounded;
    }
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
                .onSurface
                .withValues(alpha: 0.25),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.5),
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
