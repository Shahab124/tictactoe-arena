import 'package:flutter/material.dart';
import 'package:game_engine/game_engine.dart';

import 'app_settings.dart';
import 'mark.dart';
import 'tutorial_screen.dart';
import 'strings.dart';

/// Theme, skin, sound and vibration (REQ-UX-04, 05).
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppSettings.of(context);
    final heading = Theme.of(context).textTheme.titleMedium;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Settings'))),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(context.tr('Theme'), style: heading),
              const SizedBox(height: 8),
              SegmentedButton<ThemeMode>(
                segments: [
                  ButtonSegment(
                      value: ThemeMode.system,
                      label: Text(context.tr('System'))),
                  ButtonSegment(
                      value: ThemeMode.light, label: Text(context.tr('Light'))),
                  ButtonSegment(
                      value: ThemeMode.dark, label: Text(context.tr('Dark'))),
                ],
                selected: {s.themeMode},
                onSelectionChanged: (v) => s.themeMode = v.first,
              ),
              const SizedBox(height: 24),
              Text(context.tr('Skin'), style: heading),
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
                title: Text(context.tr('Sound')),
                subtitle: Text(context.tr('A click when a mark is placed')),
                value: s.sound,
                onChanged: (v) => s.sound = v,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(context.tr('Vibration')),
                subtitle:
                    Text(context.tr('A short buzz on phones that support it')),
                value: s.vibration,
                onChanged: (v) => s.vibration = v,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(context.tr('Colour-blind friendly colours')),
                subtitle: Text(context.tr(
                    'Blue and orange, which almost everyone can tell apart')),
                value: s.colourBlind,
                onChanged: (v) => s.colourBlind = v,
              ),
              const SizedBox(height: 16),
              Text(context.tr('Language'), style: heading),
              const SizedBox(height: 8),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('English')),
                  ButtonSegment(value: true, label: Text('اردو')),
                ],
                selected: {s.urdu},
                onSelectionChanged: (v) => s.urdu = v.first,
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.school_outlined),
                title: Text(context.tr('How to play')),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => TutorialScreen(
                        onDone: () => Navigator.of(context).pop()))),
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
  Widget build(BuildContext context) => MarkView(mark: Mark.x, color: skin.x);
}
