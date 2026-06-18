import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/extensions/duration_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../player/domain/entities/track.dart';

class TrackListItem extends StatelessWidget {
  final Track track;
  final VoidCallback onTap;
  final VoidCallback? onMoreTap;

  const TrackListItem({
    super.key,
    required this.track,
    required this.onTap,
    this.onMoreTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: track.thumbnailUrl != null
            ? CachedNetworkImage(
                imageUrl: track.thumbnailUrl!,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => _placeholder(),
              )
            : _placeholder(),
      ),
      title: Text(
        track.title,
        style: Theme.of(context).textTheme.titleSmall,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${track.artist}${track.album != null ? ' • ${track.album}' : ''}',
        style: Theme.of(context).textTheme.bodySmall,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (track.duration != null)
            Text(
              track.duration!.shortFormatted,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.4),
                  ),
            ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onMoreTap,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                Icons.more_vert_rounded,
                size: 20,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() => Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.primaryBeige.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(
          Icons.music_note_rounded,
          color: AppColors.primaryBeige,
          size: 22,
        ),
      );
}
