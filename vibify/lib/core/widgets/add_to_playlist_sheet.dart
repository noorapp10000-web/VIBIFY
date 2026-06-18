import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../features/player/domain/entities/track.dart';
import '../../features/playlists/presentation/providers/playlists_provider.dart';

Future<void> showAddToPlaylistSheet(
  BuildContext context,
  WidgetRef ref,
  Track track,
) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _AddToPlaylistSheet(ref: ref, track: track),
  );
}

class _AddToPlaylistSheet extends ConsumerWidget {
  final WidgetRef ref;
  final Track track;

  const _AddToPlaylistSheet({required this.ref, required this.track});

  @override
  Widget build(BuildContext context, WidgetRef watchRef) {
    final playlistsAsync = watchRef.watch(playlistsNotifierProvider);

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Add to Playlist',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _showCreateDialog(context, watchRef);
                  },
                  icon: const Icon(Icons.add_rounded,
                      size: 18, color: AppColors.primaryBeige),
                  label: const Text(
                    'New',
                    style: TextStyle(color: AppColors.primaryBeige),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          playlistsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(AppColors.primaryBeige),
              ),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Error loading playlists: $e'),
            ),
            data: (playlists) {
              if (playlists.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Icon(Icons.queue_music_rounded,
                          size: 48, color: AppColors.primaryBeige),
                      const SizedBox(height: 12),
                      Text(
                        'No playlists yet.\nCreate one to get started.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                );
              }
              return ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.45,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: playlists.length,
                  itemBuilder: (ctx, i) {
                    final pl = playlists[i];
                    return ListTile(
                      leading: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.primaryBeige.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.queue_music_rounded,
                            color: AppColors.primaryBeige, size: 22),
                      ),
                      title: Text(pl.name,
                          style: Theme.of(context).textTheme.titleSmall),
                      subtitle: Text('${pl.trackCount} songs',
                          style: Theme.of(context).textTheme.bodySmall),
                      onTap: () async {
                        Navigator.pop(context);
                        await watchRef
                            .read(playlistsNotifierProvider.notifier)
                            .addTrackToPlaylist(pl.id, track);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Added to "${pl.name}"'),
                              duration: const Duration(seconds: 2),
                              backgroundColor: AppColors.primaryBeige,
                            ),
                          );
                        }
                      },
                    );
                  },
                ),
              );
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  void _showCreateDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('New Playlist'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Playlist name'),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                Navigator.pop(context);
                await ref
                    .read(playlistsNotifierProvider.notifier)
                    .createPlaylist(name);
                if (context.mounted) {
                  await showAddToPlaylistSheet(context, ref, track);
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}
