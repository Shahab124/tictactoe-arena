import 'package:flutter/material.dart';

import '../data/game_store.dart';
import 'ai_client.dart';
import 'game_screen.dart';

/// Game setup: the player picks the board size and the mode, then starts
/// (REQ-PLAT-01).
class SetupScreen extends StatefulWidget {
  const SetupScreen({
    super.key,
    this.initialSize = 3,
    required this.store,
    this.uid,
  });

  final int initialSize;
  final GameStore store;

  /// Null for a guest.
  final String? uid;

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  late int _size = widget.initialSize;
  String _mode = 'local';
  String _difficulty = 'medium';

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final label = text.titleMedium?.copyWith(fontWeight: FontWeight.w700);
    return Scaffold(
      appBar: AppBar(
        title: const Text('New game',
            style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              // Keeps the form a comfortable width on tablets (REQ-UX-02).
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Board', style: label),
                  const SizedBox(height: 8),
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(
                          value: 3,
                          icon: Icon(Icons.grid_3x3_rounded),
                          label: Text('Classic 3×3')),
                      ButtonSegment(
                          value: 8,
                          icon: Icon(Icons.grid_4x4_rounded),
                          label: Text('Big 8×8')),
                    ],
                    selected: {_size},
                    onSelectionChanged: (s) => setState(() => _size = s.single),
                  ),
                  const SizedBox(height: 8),
                  Text(_size == 3
                      ? 'Three in a row wins.'
                      : 'Five in a row wins. Pinch the board to zoom.'),
                  const SizedBox(height: 24),
                  Text('Mode', style: label),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                          value: 'local',
                          icon: Icon(Icons.people_alt_rounded),
                          label: Text('Two players')),
                      ButtonSegment(
                          value: 'computer',
                          icon: Icon(Icons.smart_toy_rounded),
                          label: Text('Computer')),
                    ],
                    selected: {_mode},
                    onSelectionChanged: (s) => setState(() => _mode = s.single),
                  ),
                  const SizedBox(height: 8),
                  Text(_mode == 'local'
                      ? 'Two players take turns on this device.'
                      : 'You play X and move first. Works without internet.'),
                  if (_mode == 'computer') ...[
                    const SizedBox(height: 24),
                    Text('Difficulty', style: label),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final d in difficulties)
                        ChoiceChip(
                          label: Text('${d[0].toUpperCase()}${d.substring(1)}'),
                          selected: _difficulty == d,
                          onSelected: (_) => setState(() => _difficulty = d),
                        ),
                    ]),
                  ],
                  const SizedBox(height: 32),
                  FilledButton.icon(
                    onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => GameScreen(
                                size: _size,
                                store: widget.store,
                                uid: widget.uid,
                                difficulty: _mode == 'computer'
                                    ? _difficulty
                                    : null))),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Start game'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
