import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../providers/player_provider.dart';

class SleepTimerDialog extends StatelessWidget {
  final PlayerNotifier notifier;

  const SleepTimerDialog({super.key, required this.notifier});

  @override
  Widget build(BuildContext context) {
    final options = [
      ('5 minutes', const Duration(minutes: 5)),
      ('10 minutes', const Duration(minutes: 10)),
      ('15 minutes', const Duration(minutes: 15)),
      ('30 minutes', const Duration(minutes: 30)),
      ('45 minutes', const Duration(minutes: 45)),
      ('1 hour', const Duration(hours: 1)),
      ('End of track', const Duration(seconds: 1)),
    ];

    return AlertDialog(
      backgroundColor: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        'Sleep Timer',
        style: TextStyle(color: Colors.white, fontFamily: 'Inter', fontWeight: FontWeight.w700),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...options.map((option) => ListTile(
                title: Text(
                  option.$1,
                  style: const TextStyle(color: Colors.white, fontFamily: 'Inter'),
                ),
                onTap: () {
                  notifier.setSleepTimer(option.$2);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Sleep timer set: ${option.$1}')),
                  );
                },
              )),
          const Divider(color: Colors.white24),
          ListTile(
            title: const Text(
              'Cancel Timer',
              style: TextStyle(color: AppColors.primaryBeige, fontFamily: 'Inter'),
            ),
            onTap: () {
              notifier.cancelSleepTimer();
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}
