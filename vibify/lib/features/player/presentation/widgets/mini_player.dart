import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/player_state.dart';
import '../providers/player_provider.dart';

class MiniPlayer extends ConsumerWidget {
  final VibifyPlayerState state;

  const MiniPlayer({super.key, required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final track = state.currentTrack;
    if (track == null) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final progress = state.progressPercentage;

    return GestureDetector(
      onTap: () => context.push(AppRoutes.player),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: track.thumbnailUrl != null
                        ? CachedNetworkImage(
                            imageUrl: track.thumbnailUrl!,
                            width: 46,
                            height: 46,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => _artPlaceholder(),
                            errorWidget: (_, __, ___) => _artPlaceholder(),
                          )
                        : _artPlaceholder(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          track.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  _ControlButton(
                    icon: Icons.skip_previous_rounded,
                    onTap: () => ref
                        .read(playerNotifierProvider.notifier)
                        .skipToPrevious(),
                    size: 20,
                  ),
                  const SizedBox(width: 4),
                  _PlayPauseButton(state: state),
                  const SizedBox(width: 4),
                  _ControlButton(
                    icon: Icons.skip_next_rounded,
                    onTap: () =>
                        ref.read(playerNotifierProvider.notifier).skipToNext(),
                    size: 20,
                  ),
                ],
              ),
            ),
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(16),
              ),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 2,
                backgroundColor: scheme.onSurface.withOpacity(0.08),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.primaryBeige),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _artPlaceholder() => Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: AppColors.primaryBeige.withOpacity(0.2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(
          Icons.music_note_rounded,
          color: AppColors.primaryBeige,
          size: 22,
        ),
      );
}

class _PlayPauseButton extends ConsumerWidget {
  final VibifyPlayerState state;

  const _PlayPauseButton({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () {
        final notifier = ref.read(playerNotifierProvider.notifier);
        if (state.isPlaying) {
          notifier.pause();
        } else {
          notifier.resume();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 36,
        height: 36,
        decoration: const BoxDecoration(
          color: AppColors.primaryBeige,
          shape: BoxShape.circle,
        ),
        child: state.isLoading
            ? const Padding(
                padding: EdgeInsets.all(8),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Icon(
                state.isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 20,
              ),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;

  const _ControlButton({
    required this.icon,
    required this.onTap,
    this.size = 24,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(
          icon,
          size: size,
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
        ),
      ),
    );
  }
}
