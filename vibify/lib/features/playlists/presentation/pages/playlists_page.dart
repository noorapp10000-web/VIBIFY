import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/playlist.dart';
import '../providers/playlists_provider.dart';

class PlaylistsPage extends ConsumerWidget {
  const PlaylistsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlistsAsync = ref.watch(playlistsNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Playlists'),
        actions: [
          IconButton(
            onPressed: () => _showCreateDialog(context, ref),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: playlistsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(AppColors.primaryBeige),
          ),
        ),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (playlists) => playlists.isEmpty
            ? _EmptyPlaylists(
                onCreate: () => _showCreateDialog(context, ref),
              )
            : ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: playlists.length,
                itemBuilder: (context, index) => _PlaylistTile(
                  playlist: playlists[index],
                  onTap: () => context
                      .push('${AppRoutes.playlists}/${playlists[index].id}'),
                  onDelete: () => ref
                      .read(playlistsNotifierProvider.notifier)
                      .deletePlaylist(playlists[index].id),
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateDialog(context, ref),
        backgroundColor: AppColors.primaryBeige,
        child: const Icon(Icons.add_rounded, color: Colors.white),
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
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                ref
                    .read(playlistsNotifierProvider.notifier)
                    .createPlaylist(controller.text.trim());
                Navigator.pop(context);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}

class _PlaylistTile extends StatelessWidget {
  final Playlist playlist;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _PlaylistTile({
    required this.playlist,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: AppColors.primaryBeige.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.queue_music_rounded,
            color: AppColors.primaryBeige, size: 26),
      ),
      title: Text(playlist.name,
          style: Theme.of(context).textTheme.titleSmall),
      subtitle: Text(
        '${playlist.trackCount} songs',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (value) {
          if (value == 'delete') onDelete();
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'delete', child: Text('Delete')),
        ],
        icon: const Icon(Icons.more_vert_rounded),
      ),
    );
  }
}

class _EmptyPlaylists extends StatelessWidget {
  final VoidCallback onCreate;

  const _EmptyPlaylists({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.queue_music_rounded,
            size: 72,
            color: AppColors.primaryBeige,
          ),
          const SizedBox(height: 16),
          Text('No playlists yet',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Create your first playlist to get started',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: onCreate,
            child: const Text('Create Playlist'),
          ),
        ],
      ),
    );
  }
}
