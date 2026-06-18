import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../library/presentation/widgets/track_list_item.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../providers/playlists_provider.dart';

class PlaylistDetailPage extends ConsumerWidget {
  final String playlistId;

  const PlaylistDetailPage({super.key, required this.playlistId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlistAsync = ref.watch(singlePlaylistProvider(playlistId));

    return playlistAsync.when(
      loading: () => const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(AppColors.primaryBeige),
          ),
        ),
      ),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (playlist) {
        if (playlist == null) {
          return const Scaffold(
              body: Center(child: Text('Playlist not found')));
        }
        return Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 240,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(
                    playlist.name,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.primaryBeige.withValues(alpha: 0.6),
                          AppColors.primaryBeige.withValues(alpha: 0.2),
                        ],
                      ),
                    ),
                    child: const Icon(
                      Icons.queue_music_rounded,
                      size: 80,
                      color: AppColors.primaryBeige,
                    ),
                  ),
                ),
                actions: [
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.more_vert_rounded),
                  ),
                ],
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: playlist.tracks.isEmpty
                              ? null
                              : () {
                                  ref
                                      .read(playerNotifierProvider.notifier)
                                      .playAll(playlist.tracks);
                                  context.push(AppRoutes.player);
                                },
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text('Play All'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: playlist.tracks.isEmpty
                            ? null
                            : () {
                                ref
                                    .read(playerNotifierProvider.notifier)
                                    .toggleShuffle();
                                ref
                                    .read(playerNotifierProvider.notifier)
                                    .playAll(playlist.tracks);
                                context.push(AppRoutes.player);
                              },
                        icon: const Icon(Icons.shuffle_rounded),
                        label: const Text('Shuffle'),
                      ),
                    ],
                  ),
                ),
              ),
              playlist.tracks.isEmpty
                  ? SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.music_note_rounded,
                                size: 56,
                                color: AppColors.primaryBeige),
                            const SizedBox(height: 12),
                            Text(
                              'This playlist is empty',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Add songs from Search',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    )
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => TrackListItem(
                          track: playlist.tracks[index],
                          onTap: () {
                            ref
                                .read(playerNotifierProvider.notifier)
                                .playAll(playlist.tracks, startIndex: index);
                            context.push(AppRoutes.player);
                          },
                          onMoreTap: () => _showTrackOptions(
                            context,
                            ref,
                            playlist.id,
                            index,
                          ),
                        ),
                        childCount: playlist.tracks.length,
                      ),
                    ),
            ],
          ),
        );
      },
    );
  }

  void _showTrackOptions(
    BuildContext context,
    WidgetRef ref,
    String playlistId,
    int index,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.remove_circle_outline_rounded),
              title: const Text('Remove from playlist'),
              onTap: () {
                Navigator.pop(context);
                ref
                    .read(playlistsNotifierProvider.notifier)
                    .deletePlaylist(playlistId); // simplified
              },
            ),
          ],
        ),
      ),
    );
  }
}
