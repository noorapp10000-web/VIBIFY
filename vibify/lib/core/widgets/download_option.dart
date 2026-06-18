import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/downloads/presentation/providers/downloads_provider.dart';
import '../../features/player/domain/entities/track.dart';
import '../theme/app_colors.dart';

/// A ListTile that shows the correct download state for a YouTube track.
/// Shows nothing for local tracks (they're already on device).
class DownloadOption extends ConsumerWidget {
  final Track track;
  final VoidCallback onDownloadStarted;

  const DownloadOption({
    super.key,
    required this.track,
    required this.onDownloadStarted,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (track.source != TrackSource.youtube) return const SizedBox.shrink();

    final item = ref.watch(trackDownloadStatusProvider(track.id));

    if (item != null && item.isCompleted) {
      return ListTile(
        leading: const Icon(Icons.download_done_rounded, color: Colors.green),
        title: const Text('Downloaded'),
        subtitle: const Text('Saved for offline listening',
            style: TextStyle(fontSize: 12)),
        enabled: false,
        textColor: Colors.green.withValues(alpha: 0.8),
      );
    }

    if (item != null && (item.isDownloading || item.isQueued)) {
      return ListTile(
        leading: const Icon(Icons.downloading_rounded,
            color: AppColors.primaryBeige),
        title: const Text('Downloading…'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: item.isQueued ? null : item.progress,
              backgroundColor:
                  AppColors.primaryBeige.withValues(alpha: 0.15),
              valueColor: const AlwaysStoppedAnimation(AppColors.primaryBeige),
              minHeight: 2,
              borderRadius: BorderRadius.circular(2),
            ),
            if (!item.isQueued)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '${(item.progress * 100).toInt()}%',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.primaryBeige),
                ),
              ),
          ],
        ),
        isThreeLine: true,
        enabled: false,
      );
    }

    if (item != null && item.isPaused) {
      return ListTile(
        leading: const Icon(Icons.pause_circle_outline_rounded,
            color: AppColors.primaryBeige),
        title: const Text('Download Paused'),
        subtitle: const Text('Go to Downloads to resume',
            style: TextStyle(fontSize: 12)),
        enabled: false,
      );
    }

    if (item != null && item.isFailed) {
      return ListTile(
        leading: const Icon(Icons.error_outline_rounded, color: Colors.red),
        title: const Text('Retry Download'),
        onTap: () {
          onDownloadStarted();
          ref.read(downloadsNotifierProvider.notifier).retry(item.id);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Retrying "${track.title}"…'),
              duration: const Duration(seconds: 2),
              backgroundColor: AppColors.primaryBeige,
            ),
          );
        },
      );
    }

    return ListTile(
      leading: const Icon(Icons.download_rounded),
      title: const Text('Download'),
      subtitle: const Text('Save for offline listening',
          style: TextStyle(fontSize: 12)),
      onTap: () {
        onDownloadStarted();
        ref.read(downloadsNotifierProvider.notifier).startDownload(track);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.download_rounded,
                    color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Downloading "${track.title}"…',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 3),
            backgroundColor: AppColors.primaryBeige,
          ),
        );
      },
    );
  }
}
