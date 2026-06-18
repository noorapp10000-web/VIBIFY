import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../providers/player_provider.dart';

class PlaybackSpeedDialog extends StatelessWidget {
  final double currentSpeed;
  final PlayerNotifier notifier;

  const PlaybackSpeedDialog({
    super.key,
    required this.currentSpeed,
    required this.notifier,
  });

  @override
  Widget build(BuildContext context) {
    const speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

    return AlertDialog(
      backgroundColor: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        'Playback Speed',
        style: TextStyle(
          color: Colors.white,
          fontFamily: 'Inter',
          fontWeight: FontWeight.w700,
        ),
      ),
      content: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: speeds.map((speed) {
          final isSelected = (speed - currentSpeed).abs() < 0.01;
          return GestureDetector(
            onTap: () {
              notifier.setPlaybackSpeed(speed);
              Navigator.pop(context);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primaryBeige
                    : Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${speed}x',
                style: TextStyle(
                  color: isSelected ? Colors.black : Colors.white,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
