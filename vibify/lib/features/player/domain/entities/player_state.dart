import 'package:equatable/equatable.dart';

import 'track.dart';

enum RepeatMode { none, one, all }

enum PlayerStatus { idle, loading, playing, paused, stopped, error }

class VibifyPlayerState extends Equatable {
  final Track? currentTrack;
  final List<Track> queue;
  final int currentIndex;
  final PlayerStatus status;
  final Duration position;
  final Duration duration;
  final bool isShuffling;
  final RepeatMode repeatMode;
  final double volume;
  final double playbackSpeed;
  final bool isFavorite;
  final String? errorMessage;

  const VibifyPlayerState({
    this.currentTrack,
    this.queue = const [],
    this.currentIndex = 0,
    this.status = PlayerStatus.idle,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.isShuffling = false,
    this.repeatMode = RepeatMode.none,
    this.volume = 1.0,
    this.playbackSpeed = 1.0,
    this.isFavorite = false,
    this.errorMessage,
  });

  bool get isPlaying => status == PlayerStatus.playing;
  bool get isPaused => status == PlayerStatus.paused;
  bool get isLoading => status == PlayerStatus.loading;
  bool get hasTrack => currentTrack != null;
  bool get hasPrevious => currentIndex > 0;
  bool get hasNext => currentIndex < queue.length - 1;

  double get progressPercentage {
    if (duration.inMilliseconds == 0) return 0;
    return position.inMilliseconds / duration.inMilliseconds;
  }

  VibifyPlayerState copyWith({
    Track? currentTrack,
    List<Track>? queue,
    int? currentIndex,
    PlayerStatus? status,
    Duration? position,
    Duration? duration,
    bool? isShuffling,
    RepeatMode? repeatMode,
    double? volume,
    double? playbackSpeed,
    bool? isFavorite,
    String? errorMessage,
  }) =>
      VibifyPlayerState(
        currentTrack: currentTrack ?? this.currentTrack,
        queue: queue ?? this.queue,
        currentIndex: currentIndex ?? this.currentIndex,
        status: status ?? this.status,
        position: position ?? this.position,
        duration: duration ?? this.duration,
        isShuffling: isShuffling ?? this.isShuffling,
        repeatMode: repeatMode ?? this.repeatMode,
        volume: volume ?? this.volume,
        playbackSpeed: playbackSpeed ?? this.playbackSpeed,
        isFavorite: isFavorite ?? this.isFavorite,
        errorMessage: errorMessage,
      );

  @override
  List<Object?> get props => [
        currentTrack,
        queue,
        currentIndex,
        status,
        position,
        duration,
        isShuffling,
        repeatMode,
        volume,
        playbackSpeed,
        isFavorite,
        errorMessage,
      ];
}
