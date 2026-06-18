import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/download_item.dart';
import '../providers/downloads_provider.dart';

class DownloadsPage extends ConsumerWidget {
  const DownloadsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloadsAsync = ref.watch(downloadsNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Downloads'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'clear_completed') {
                ref.read(downloadsNotifierProvider.notifier).clearCompleted();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'clear_completed',
                child: Text('Clear Completed'),
              ),
            ],
          ),
        ],
      ),
      body: downloadsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(AppColors.primaryBeige),
          ),
        ),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (downloads) => downloads.isEmpty
            ? _EmptyDownloads()
            : ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: downloads.length,
                separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
                itemBuilder: (context, index) => _DownloadTile(
                  item: downloads[index],
                  onPause: () => ref
                      .read(downloadsNotifierProvider.notifier)
                      .pause(downloads[index].id),
                  onResume: () => ref
                      .read(downloadsNotifierProvider.notifier)
                      .resume(downloads[index].id),
                  onCancel: () => ref
                      .read(downloadsNotifierProvider.notifier)
                      .cancel(downloads[index].id),
                  onRetry: () => ref
                      .read(downloadsNotifierProvider.notifier)
                      .retry(downloads[index].id),
                  onDelete: () => ref
                      .read(downloadsNotifierProvider.notifier)
                      .delete(downloads[index].id),
                ),
              ),
      ),
    );
  }
}

class _DownloadTile extends StatelessWidget {
  final DownloadItem item;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onCancel;
  final VoidCallback onRetry;
  final VoidCallback onDelete;

  const _DownloadTile({
    required this.item,
    required this.onPause,
    required this.onResume,
    required this.onCancel,
    required this.onRetry,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: _statusColor().withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(_statusIcon(), color: _statusColor(), size: 24),
      ),
      title: Text(
        item.track.title,
        style: Theme.of(context).textTheme.titleSmall,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.track.artist,
            style: Theme.of(context).textTheme.bodySmall,
            maxLines: 1,
          ),
          if (item.isDownloading || item.isPaused) ...[
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: item.progress,
              backgroundColor:
                  Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
              valueColor:
                  AlwaysStoppedAnimation<Color>(AppColors.primaryBeige),
              minHeight: 2,
            ),
            const SizedBox(height: 2),
            Text(
              '${(item.progress * 100).toInt()}%',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.primaryBeige,
                    fontSize: 11,
                  ),
            ),
          ],
          if (item.isFailed)
            Text(
              item.errorMessage ?? 'Download failed',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.error,
                  ),
            ),
        ],
      ),
      trailing: _buildActions(context),
      isThreeLine: item.isDownloading || item.isPaused || item.isFailed,
    );
  }

  Widget _buildActions(BuildContext context) {
    if (item.isDownloading) {
      return IconButton(
        onPressed: onPause,
        icon: const Icon(Icons.pause_rounded),
        color: AppColors.primaryBeige,
      );
    }
    if (item.isPaused) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: onResume,
            icon: const Icon(Icons.play_arrow_rounded),
            color: AppColors.primaryBeige,
          ),
          IconButton(
            onPressed: onCancel,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      );
    }
    if (item.isFailed) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            color: AppColors.primaryBeige,
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      );
    }
    if (item.isCompleted) {
      return IconButton(
        onPressed: onDelete,
        icon: const Icon(Icons.delete_outline_rounded),
      );
    }
    return const SizedBox.shrink();
  }

  Color _statusColor() {
    switch (item.status) {
      case DownloadStatus.completed:
        return AppColors.success;
      case DownloadStatus.downloading:
        return AppColors.primaryBeige;
      case DownloadStatus.paused:
        return AppColors.warning;
      case DownloadStatus.failed:
        return AppColors.error;
      default:
        return AppColors.primaryBeige;
    }
  }

  IconData _statusIcon() {
    switch (item.status) {
      case DownloadStatus.completed:
        return Icons.check_circle_rounded;
      case DownloadStatus.downloading:
        return Icons.downloading_rounded;
      case DownloadStatus.paused:
        return Icons.pause_circle_rounded;
      case DownloadStatus.failed:
        return Icons.error_rounded;
      case DownloadStatus.queued:
        return Icons.queue_rounded;
      default:
        return Icons.download_rounded;
    }
  }
}

class _EmptyDownloads extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.download_done_rounded,
              size: 72, color: AppColors.primaryBeige),
          const SizedBox(height: 16),
          Text('No downloads yet',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Download songs for offline listening',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
