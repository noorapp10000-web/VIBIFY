import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:palette_generator/palette_generator.dart';

import '../../../../core/extensions/duration_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/add_to_playlist_sheet.dart';
import '../../../../core/widgets/download_option.dart';
import '../../../../features/library/presentation/providers/library_provider.dart';
import '../../domain/entities/player_state.dart';
import '../../domain/entities/track.dart';
import '../providers/player_provider.dart';
import '../widgets/queue_panel.dart';
import '../widgets/sleep_timer_dialog.dart';
import '../widgets/playback_speed_dialog.dart';

class PlayerPage extends ConsumerStatefulWidget {
  const PlayerPage({super.key});

  @override
  ConsumerState<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends ConsumerState<PlayerPage>
    with TickerProviderStateMixin {
  Color _dominantColor = AppColors.darkBackground;
  bool _showQueue = false;
  late AnimationController _artworkController;
  late Animation<double> _artworkScale;

  @override
  void initState() {
    super.initState();
    _artworkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _artworkScale = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _artworkController, curve: Curves.easeOutBack),
    );
    _artworkController.forward();
  }

  @override
  void dispose() {
    _artworkController.dispose();
    super.dispose();
  }

  Future<void> _updatePalette(String? imageUrl) async {
    if (imageUrl == null) return;
    try {
      final generator = await PaletteGenerator.fromImageProvider(
        CachedNetworkImageProvider(imageUrl),
        maximumColorCount: 8,
      );
      final color = generator.dominantColor?.color ??
          generator.mutedColor?.color ??
          AppColors.darkBackground;
      if (mounted) {
        setState(() => _dominantColor = color);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(playerNotifierProvider);
    final track = state.currentTrack;

    ref.listen<VibifyPlayerState>(playerNotifierProvider, (prev, next) {
      if (prev?.currentTrack?.id != next.currentTrack?.id) {
        _artworkController.reset();
        _artworkController.forward();
        _updatePalette(next.currentTrack?.thumbnailUrl);
      }
    });

    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 800),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _dominantColor.withValues(alpha: 0.85),
              Colors.black.withValues(alpha: 0.95),
              Colors.black,
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _PlayerHeader(onClose: () => context.pop()),
              Expanded(
                child: _showQueue
                    ? QueuePanel(
                        queue: state.queue,
                        currentIndex: state.currentIndex,
                        onClose: () => setState(() => _showQueue = false),
                      )
                    : _PlayerContent(
                        track: track,
                        state: state,
                        artworkScale: _artworkScale,
                        onQueueTap: () =>
                            setState(() => _showQueue = true),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayerHeader extends ConsumerWidget {
  final VoidCallback onClose;

  const _PlayerHeader({required this.onClose});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final track = ref.watch(playerNotifierProvider).currentTrack;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: onClose,
            icon: const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
          const Expanded(
            child: Text(
              'Now Playing',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Inter',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
          IconButton(
            onPressed: track == null
                ? null
                : () => _showMenu(context, ref, track!),
            icon: const Icon(
              Icons.more_vert_rounded,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _showMenu(BuildContext context, WidgetRef ref, Track track) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.playlist_add_rounded),
              title: const Text('Add to Playlist'),
              onTap: () {
                Navigator.pop(context);
                showAddToPlaylistSheet(context, ref, track);
              },
            ),
            ListTile(
              leading: const Icon(Icons.queue_music_rounded),
              title: const Text('View Queue'),
              onTap: () => Navigator.pop(context),
            ),
            DownloadOption(
              track: track,
              onDownloadStarted: () => Navigator.pop(context),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _PlayerContent extends ConsumerWidget {
  final Track? track;
  final VibifyPlayerState state;
  final Animation<double> artworkScale;
  final VoidCallback onQueueTap;

  const _PlayerContent({
    required this.track,
    required this.state,
    required this.artworkScale,
    required this.onQueueTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(playerNotifierProvider.notifier);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 16),

          // Artwork
          ScaleTransition(
            scale: artworkScale,
            child: AspectRatio(
              aspectRatio: 1,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: state.isPlaying
                    ? EdgeInsets.zero
                    : const EdgeInsets.all(24),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: track?.thumbnailUrl != null
                      ? CachedNetworkImage(
                          imageUrl: track!.thumbnailUrl!,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => _artPlaceholder(),
                          errorWidget: (_, __, ___) => _artPlaceholder(),
                        )
                      : _artPlaceholder(),
                ),
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Title + Favorite
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track?.title ?? 'No Track',
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'Inter',
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      track?.artist ?? '',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontFamily: 'Inter',
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {
                  ref.read(playerNotifierProvider.notifier).toggleFavorite();
                  ref.read(favoritesVersionProvider.notifier).state++;
                },
                icon: Icon(
                  state.isFavorite
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: state.isFavorite
                      ? AppColors.primaryBeige
                      : Colors.white.withValues(alpha: 0.6),
                  size: 28,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Seek bar
          _SeekBar(state: state),

          const SizedBox(height: 16),

          // Main controls
          _MainControls(state: state, notifier: notifier),

          const SizedBox(height: 16),

          // Secondary controls
          _SecondaryControls(
            state: state,
            notifier: notifier,
            onQueueTap: onQueueTap,
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _artPlaceholder() => Container(
        decoration: BoxDecoration(
          color: AppColors.primaryBeige.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(
          Icons.music_note_rounded,
          color: AppColors.primaryBeige,
          size: 80,
        ),
      );
}

class _SeekBar extends ConsumerWidget {
  final VibifyPlayerState state;

  const _SeekBar({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: AppColors.primaryBeige,
            inactiveTrackColor: Colors.white.withValues(alpha: 0.15),
            thumbColor: Colors.white,
            overlayColor: Colors.white.withValues(alpha: 0.1),
            trackHeight: 3.5,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
          ),
          child: Slider(
            value: state.progressPercentage.clamp(0.0, 1.0),
            onChanged: (value) {
              final ms =
                  (value * state.duration.inMilliseconds).toInt();
              ref
                  .read(playerNotifierProvider.notifier)
                  .seek(Duration(milliseconds: ms));
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                state.position.shortFormatted,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 12,
                  fontFamily: 'Inter',
                ),
              ),
              Text(
                state.duration.shortFormatted,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 12,
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MainControls extends StatelessWidget {
  final VibifyPlayerState state;
  final PlayerNotifier notifier;

  const _MainControls({required this.state, required this.notifier});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _IconBtn(
          icon: Icons.skip_previous_rounded,
          size: 40,
          onTap: notifier.skipToPrevious,
          opacity: state.hasPrevious ? 1.0 : 0.4,
        ),
        GestureDetector(
          onTap: state.isPlaying ? notifier.pause : notifier.resume,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: AppColors.primaryBeige,
              shape: BoxShape.circle,
            ),
            child: state.isLoading
                ? const Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Icon(
                    state.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 36,
                  ),
          ),
        ),
        _IconBtn(
          icon: Icons.skip_next_rounded,
          size: 40,
          onTap: notifier.skipToNext,
          opacity: state.hasNext ? 1.0 : 0.4,
        ),
      ],
    );
  }
}

class _SecondaryControls extends StatelessWidget {
  final VibifyPlayerState state;
  final PlayerNotifier notifier;
  final VoidCallback onQueueTap;

  const _SecondaryControls({
    required this.state,
    required this.notifier,
    required this.onQueueTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _IconBtn(
          icon: state.isShuffling
              ? Icons.shuffle_on_rounded
              : Icons.shuffle_rounded,
          size: 22,
          onTap: notifier.toggleShuffle,
          color: state.isShuffling
              ? AppColors.primaryBeige
              : Colors.white.withValues(alpha: 0.6),
        ),
        _IconBtn(
          icon: _repeatIcon(state.repeatMode),
          size: 22,
          onTap: notifier.toggleRepeat,
          color: state.repeatMode != RepeatMode.none
              ? AppColors.primaryBeige
              : Colors.white.withValues(alpha: 0.6),
        ),
        _IconBtn(
          icon: Icons.queue_music_rounded,
          size: 22,
          onTap: onQueueTap,
          color: Colors.white.withValues(alpha: 0.6),
        ),
        _IconBtn(
          icon: Icons.bedtime_outlined,
          size: 22,
          onTap: () => showDialog(
            context: context,
            builder: (_) => SleepTimerDialog(notifier: notifier),
          ),
          color: Colors.white.withValues(alpha: 0.6),
        ),
        _IconBtn(
          icon: Icons.speed_rounded,
          size: 22,
          onTap: () => showDialog(
            context: context,
            builder: (_) => PlaybackSpeedDialog(
              currentSpeed: state.playbackSpeed,
              notifier: notifier,
            ),
          ),
          color: Colors.white.withValues(alpha: 0.6),
        ),
      ],
    );
  }

  IconData _repeatIcon(RepeatMode mode) {
    switch (mode) {
      case RepeatMode.one:
        return Icons.repeat_one_rounded;
      case RepeatMode.all:
        return Icons.repeat_on_rounded;
      case RepeatMode.none:
        return Icons.repeat_rounded;
    }
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final double size;
  final VoidCallback onTap;
  final double opacity;
  final Color? color;

  const _IconBtn({
    required this.icon,
    required this.size,
    required this.onTap,
    this.opacity = 1.0,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Opacity(
        opacity: opacity,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(
            icon,
            size: size,
            color: color ?? Colors.white,
          ),
        ),
      ),
    );
  }
}
