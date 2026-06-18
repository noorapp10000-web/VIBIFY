import 'package:flutter_test/flutter_test.dart';
import 'package:vibify/features/player/domain/entities/track.dart';
import 'package:vibify/features/playlists/domain/entities/playlist.dart';

void main() {
  group('Playlist', () {
    final now = DateTime(2024, 1, 1);
    const track1 = Track(
      id: 't1',
      title: 'Song One',
      artist: 'Artist A',
      source: TrackSource.youtube,
      duration: Duration(minutes: 3, seconds: 30),
    );
    const track2 = Track(
      id: 't2',
      title: 'Song Two',
      artist: 'Artist B',
      source: TrackSource.youtube,
      duration: Duration(minutes: 4, seconds: 15),
    );

    test('empty playlist has zero count and zero duration', () {
      final playlist = Playlist(
        id: 'p1',
        name: 'My Playlist',
        createdAt: now,
        updatedAt: now,
      );
      expect(playlist.trackCount, 0);
      expect(playlist.totalDuration, Duration.zero);
    });

    test('trackCount returns correct count', () {
      final playlist = Playlist(
        id: 'p1',
        name: 'My Playlist',
        tracks: const [track1, track2],
        createdAt: now,
        updatedAt: now,
      );
      expect(playlist.trackCount, 2);
    });

    test('totalDuration sums track durations', () {
      final playlist = Playlist(
        id: 'p1',
        name: 'My Playlist',
        tracks: const [track1, track2],
        createdAt: now,
        updatedAt: now,
      );
      expect(
        playlist.totalDuration,
        const Duration(minutes: 7, seconds: 45),
      );
    });

    test('copyWith updates name', () {
      final original = Playlist(
        id: 'p1',
        name: 'Old Name',
        createdAt: now,
        updatedAt: now,
      );
      final updated = original.copyWith(name: 'New Name');
      expect(updated.name, 'New Name');
      expect(updated.id, 'p1');
    });
  });
}
