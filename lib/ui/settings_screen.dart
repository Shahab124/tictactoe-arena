import 'package:flutter/material.dart';
import 'package:game_engine/game_engine.dart';

import 'app_settings.dart';
import 'mark.dart';

/// Theme, skin, sound and vibration (REQ-UX-04, 05).
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppSettings.of(context);
    final heading = Theme.of(context).textTheme.titleMedium;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text('Theme', style: heading),
              const SizedBox(height: 8),
              SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(value: ThemeMode.system, label: Text('System')),
                  ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                  ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
                ],
                selected: {s.themeMode},
                onSelectionChanged: (v) => s.themeMode = v.first,
              ),
              const SizedBox(height: 24),
              Text('Skin', style: heading),
              const SizedBox(height: 8),
              Wrap(spacing: 12, runSpacing: 12, children: [
                for (final skin in Skin.values)
                  ChoiceChip(
                    selected: s.skin == skin,
                    onSelected: (_) => s.skin = skin,
                    avatar: SizedBox.square(
                      dimension: 22,
                      child: AppSettingsPreview(skin: skin),
                    ),
                    label: Text(skin.label),
                  ),
              ]),
              const SizedBox(height: 24),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Sound'),
                subtitle: const Text('A click when a mark is placed'),
                value: s.sound,
                onChanged: (v) => s.sound = v,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Vibration'),
                subtitle: const Text('A short buzz on phones that support it'),
                value: s.vibration,
                onChanged: (v) => s.vibration = v,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small X drawn in [skin]'s colours, for the skin picker.
class AppSettingsPreview extends StatelessWidget {
  const AppSettingsPreview({super.key, required this.skin});

  final Skin skin;

  @override
  Widget build(BuildContext context) =>
      MarkView(mark: Mark.x, color: skin.x);
}
