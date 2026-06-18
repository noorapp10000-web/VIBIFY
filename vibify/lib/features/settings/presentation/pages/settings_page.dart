import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../providers/settings_provider.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final audioQuality = ref.watch(audioQualityProvider);

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            title: Text(
              'Settings',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            pinned: true,
            floating: true,
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _SectionTitle(title: 'Appearance'),
                _SettingsCard(
                  children: [
                    _ThemeSelector(currentMode: themeMode),
                  ],
                ),

                const SizedBox(height: 24),
                _SectionTitle(title: 'Audio'),
                _SettingsCard(
                  children: [
                    _AudioQualitySelector(currentQuality: audioQuality),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    _SettingsTile(
                      icon: Icons.graphic_eq_rounded,
                      title: 'Equaliser',
                      subtitle: 'Fine-tune audio frequencies',
                      trailing: Switch(
                        value: false,
                        onChanged: (_) {},
                      ),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    _SettingsTile(
                      icon: Icons.timer_rounded,
                      title: 'Sleep Timer',
                      subtitle: 'Auto-stop playback after a set time',
                      onTap: () {},
                    ),
                  ],
                ),

                const SizedBox(height: 24),
                _SectionTitle(title: 'Storage'),
                _SettingsCard(
                  children: [
                    _SettingsTile(
                      icon: Icons.storage_rounded,
                      title: 'Cache Management',
                      subtitle: 'Clear temporary files',
                      onTap: () => _showClearCacheDialog(context),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    _SettingsTile(
                      icon: Icons.folder_rounded,
                      title: 'Download Location',
                      subtitle: 'Choose where to save downloads',
                      onTap: () {},
                    ),
                  ],
                ),

                const SizedBox(height: 24),
                _SectionTitle(title: 'About'),
                _SettingsCard(
                  children: [
                    _SettingsTile(
                      icon: Icons.info_outline_rounded,
                      title: 'Version',
                      subtitle: '1.0.0',
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    _SettingsTile(
                      icon: Icons.privacy_tip_outlined,
                      title: 'Privacy Policy',
                      onTap: () {},
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    _SettingsTile(
                      icon: Icons.description_outlined,
                      title: 'Terms of Service',
                      onTap: () {},
                    ),
                  ],
                ),
                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  void _showClearCacheDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear Cache'),
        content: const Text(
            'This will remove all temporary files. Downloaded music will not be affected.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Cache cleared successfully')),
              );
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.primaryBeige,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;

  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(children: children),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppColors.primaryBeige.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppColors.primaryBeige, size: 20),
      ),
      title: Text(title, style: Theme.of(context).textTheme.titleSmall),
      subtitle: subtitle != null
          ? Text(subtitle!, style: Theme.of(context).textTheme.bodySmall)
          : null,
      trailing: trailing ??
          (onTap != null
              ? Icon(
                  Icons.chevron_right_rounded,
                  color: Theme.of(context)
                      .colorScheme
                      .onBackground
                      .withOpacity(0.3),
                )
              : null),
    );
  }
}

class _ThemeSelector extends ConsumerWidget {
  final ThemeMode currentMode;

  const _ThemeSelector({required this.currentMode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.primaryBeige.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.dark_mode_rounded,
                    color: AppColors.primaryBeige, size: 20),
              ),
              const SizedBox(width: 12),
              Text('Theme', style: Theme.of(context).textTheme.titleSmall),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _ThemeOption(
                label: 'Light',
                icon: Icons.light_mode_rounded,
                isSelected: currentMode == ThemeMode.light,
                onTap: () => ref
                    .read(themeModeProvider.notifier)
                    .setTheme(ThemeMode.light),
              ),
              const SizedBox(width: 8),
              _ThemeOption(
                label: 'Dark',
                icon: Icons.dark_mode_rounded,
                isSelected: currentMode == ThemeMode.dark,
                onTap: () => ref
                    .read(themeModeProvider.notifier)
                    .setTheme(ThemeMode.dark),
              ),
              const SizedBox(width: 8),
              _ThemeOption(
                label: 'System',
                icon: Icons.auto_awesome_rounded,
                isSelected: currentMode == ThemeMode.system,
                onTap: () => ref
                    .read(themeModeProvider.notifier)
                    .setTheme(ThemeMode.system),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primaryBeige
                : Theme.of(context).colorScheme.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? AppColors.primaryBeige
                  : Theme.of(context)
                      .colorScheme
                      .onBackground
                      .withOpacity(0.1),
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 22,
                color: isSelected
                    ? Colors.white
                    : Theme.of(context)
                        .colorScheme
                        .onBackground
                        .withOpacity(0.6),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? Colors.white
                      : Theme.of(context)
                          .colorScheme
                          .onBackground
                          .withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AudioQualitySelector extends ConsumerWidget {
  final AudioQuality currentQuality;

  const _AudioQualitySelector({required this.currentQuality});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppColors.primaryBeige.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.high_quality_rounded,
            color: AppColors.primaryBeige, size: 20),
      ),
      title: Text('Audio Quality',
          style: Theme.of(context).textTheme.titleSmall),
      subtitle: Text(_qualityLabel(currentQuality),
          style: Theme.of(context).textTheme.bodySmall),
      trailing: Icon(Icons.chevron_right_rounded,
          color: Theme.of(context).colorScheme.onBackground.withOpacity(0.3)),
      onTap: () => _showQualityPicker(context, ref),
    );
  }

  String _qualityLabel(AudioQuality q) {
    switch (q) {
      case AudioQuality.low:
        return 'Low (saves data)';
      case AudioQuality.medium:
        return 'Medium';
      case AudioQuality.high:
        return 'High (recommended)';
      case AudioQuality.lossless:
        return 'Lossless (best quality)';
    }
  }

  void _showQualityPicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: AudioQuality.values
              .map((q) => RadioListTile<AudioQuality>(
                    title: Text(_qualityLabel(q)),
                    value: q,
                    groupValue: currentQuality,
                    activeColor: AppColors.primaryBeige,
                    onChanged: (val) {
                      if (val != null) {
                        ref
                            .read(audioQualityProvider.notifier)
                            .setQuality(val);
                      }
                      Navigator.pop(context);
                    },
                  ))
              .toList(),
        ),
      ),
    );
  }
}
