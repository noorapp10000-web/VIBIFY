import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/extensions/duration_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/track.dart';
import '../providers/player_provider.dart';

class QueuePanel extends ConsumerWidget {
  final List<Track> queue;
  final int currentIndex;
  final VoidCallback onClose;

  const QueuePanel({
    super.key,
    required this.queue,
    required this.currentIndex,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Text(
                'Queue',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Inter',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () =>
                    ref.read(playerNotifierProvider.notifier).clearQueue(),
                child: Text(
                  'Clear',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontFamily: 'Inter',
                    fontSize: 14,
                  ),
                ),
              ),
              IconButton(
                onPressed: onClose,
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: queue.length,
            onReorderItem: (oldIndex, newIndex) {
              ref
                  .read(playerNotifierProvider.notifier)
                  .skipToIndex(newIndex);
            },
            itemBuilder: (context, index) {
              final track = queue[index];
              final isCurrent = index == currentIndex;
              return _QueueItem(
                key: ValueKey(track.id),
                track: track,
                index: index,
                isCurrent: isCurrent,
                onTap: () => ref
                    .read(playerNotifierProvider.notifier)
                    .skipToIndex(index),
                onRemove: () => ref
                    .read(playerNotifierProvider.notifier)
                    .removeFromQueue(index),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _QueueItem extends StatelessWidget {
  final Track track;
  final int index;
  final bool isCurrent;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _QueueItem({
    super.key,
    required this.track,
    required this.index,
    required this.isCurrent,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: track.thumbnailUrl != null
            ? CachedNetworkImage(
                imageUrl: track.thumbnailUrl!,
                width: 44,
                height: 44,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => _placeholder(),
              )
            : _placeholder(),
      ),
      title: Text(
        track.title,
        style: TextStyle(
          color: isCurrent ? AppColors.primaryBeige : Colors.white,
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        track.artist,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.5),
          fontFamily: 'Inter',
          fontSize: 12,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (track.duration != null)
            Text(
              track.duration!.shortFormatted,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 12,
                fontFamily: 'Inter',
              ),
            ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onRemove,
            child: Icon(
              Icons.close_rounded,
              color: Colors.white.withValues(alpha: 0.4),
              size: 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() => Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.primaryBeige.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(
          Icons.music_note_rounded,
          color: AppColors.primaryBeige,
          size: 20,
        ),
      );
}
