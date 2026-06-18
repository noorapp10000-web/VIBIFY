import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vibify/features/player/domain/entities/player_state.dart';
import 'package:vibify/features/player/domain/entities/track.dart';
import 'package:vibify/features/player/presentation/widgets/mini_player.dart';

void main() {
  const track = Track(
    id: 'test-id',
    title: 'Test Track',
    artist: 'Test Artist',
    source: TrackSource.youtube,
  );

  testWidgets('MiniPlayer shows track title and artist', (tester) async {
    final state = const VibifyPlayerState().copyWith(
      currentTrack: track,
      status: PlayerStatus.paused,
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: MiniPlayer(state: state),
          ),
        ),
      ),
    );

    expect(find.text('Test Track'), findsOneWidget);
    expect(find.text('Test Artist'), findsOneWidget);
  });

  testWidgets('MiniPlayer shows play icon when paused', (tester) async {
    final state = const VibifyPlayerState().copyWith(
      currentTrack: track,
      status: PlayerStatus.paused,
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: MiniPlayer(state: state),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
  });
}
