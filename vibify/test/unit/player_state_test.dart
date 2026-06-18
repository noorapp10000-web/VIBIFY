import 'package:flutter_test/flutter_test.dart';
import 'package:vibify/features/player/domain/entities/player_state.dart';
import 'package:vibify/features/player/domain/entities/track.dart';

void main() {
  group('VibifyPlayerState', () {
    const track = Track(
      id: 'test-id',
      title: 'Test Track',
      artist: 'Test Artist',
      source: TrackSource.youtube,
      youtubeVideoId: 'test-video-id',
    );

    test('initial state is idle with no track', () {
      const state = VibifyPlayerState();
      expect(state.status, PlayerStatus.idle);
      expect(state.currentTrack, isNull);
      expect(state.queue, isEmpty);
      expect(state.isPlaying, isFalse);
      expect(state.isLoading, isFalse);
      expect(state.hasTrack, isFalse);
    });

    test('copyWith updates fields correctly', () {
      const initial = VibifyPlayerState();
      final updated = initial.copyWith(
        currentTrack: track,
        status: PlayerStatus.playing,
        position: const Duration(seconds: 30),
        duration: const Duration(minutes: 3),
      );

      expect(updated.currentTrack, track);
      expect(updated.status, PlayerStatus.playing);
      expect(updated.position, const Duration(seconds: 30));
      expect(updated.duration, const Duration(minutes: 3));
      expect(updated.isPlaying, isTrue);
      expect(updated.hasTrack, isTrue);
    });

    test('progressPercentage returns correct ratio', () {
      final state = const VibifyPlayerState().copyWith(
        position: const Duration(seconds: 30),
        duration: const Duration(minutes: 2),
      );
      expect(state.progressPercentage, closeTo(0.25, 0.01));
    });

    test('progressPercentage is 0 when duration is zero', () {
      const state = VibifyPlayerState();
      expect(state.progressPercentage, 0.0);
    });

    test('hasPrevious and hasNext reflect queue position', () {
      final state = const VibifyPlayerState().copyWith(
        queue: [track, track, track],
        currentIndex: 1,
      );
      expect(state.hasPrevious, isTrue);
      expect(state.hasNext, isTrue);
    });

    test('hasPrevious is false at start of queue', () {
      final state = const VibifyPlayerState().copyWith(
        queue: [track, track],
        currentIndex: 0,
      );
      expect(state.hasPrevious, isFalse);
      expect(state.hasNext, isTrue);
    });

    test('hasNext is false at end of queue', () {
      final state = const VibifyPlayerState().copyWith(
        queue: [track, track],
        currentIndex: 1,
      );
      expect(state.hasPrevious, isTrue);
      expect(state.hasNext, isFalse);
    });

    test('equality is based on props', () {
      const s1 = VibifyPlayerState();
      const s2 = VibifyPlayerState();
      expect(s1, s2);
    });
  });

  group('Track', () {
    test('copyWith preserves unchanged fields', () {
      const original = Track(
        id: 'id1',
        title: 'Song',
        artist: 'Artist',
        source: TrackSource.local,
        localPath: '/music/song.mp3',
      );
      final updated = original.copyWith(isFavorite: true);
      expect(updated.id, 'id1');
      expect(updated.title, 'Song');
      expect(updated.artist, 'Artist');
      expect(updated.localPath, '/music/song.mp3');
      expect(updated.isFavorite, isTrue);
    });

    test('equality is based on props', () {
      const t1 = Track(
        id: 'same',
        title: 'Track',
        artist: 'Artist',
        source: TrackSource.youtube,
      );
      const t2 = Track(
        id: 'same',
        title: 'Track',
        artist: 'Artist',
        source: TrackSource.youtube,
      );
      expect(t1, t2);
    });
  });
}
