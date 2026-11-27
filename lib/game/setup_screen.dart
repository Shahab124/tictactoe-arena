import 'package:flutter/material.dart';
import 'package:game_engine/game_engine.dart';

import '../data/game_store.dart';
import 'ai_client.dart';
import 'game_screen.dart';
import '../ui/strings.dart';

/// Game setup: the player picks the board size, win length on 8×8, the mode,
/// X or O and who starts, and a single game or a best-of-3/5 match
/// (REQ-PLAT-01, 04, 15, REQ-MODE-06).
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
  int _winLength = 5;
  Mark _playerMark = Mark.x;
  bool _youStart = true;
  int _bestOf = 1;

  /// The unfinished game saved by [GameScreen], if any (REQ-DATA-06).
  Map<String, dynamic>? _current;

  bool get _vsComputer => _mode == 'computer';

  @override
  void initState() {
    super.initState();
    _load();
  }

  // The last choices come from the account, so they follow the player to a
  // new device (REQ-DATA-04).
  Future<void> _load() async {
    final s = await widget.store.loadSettings(uid: widget.uid);
    final current = await widget.store.loadCurrent(uid: widget.uid);
    if (!mounted) return;
    setState(() {
      _current = current;
      if (s == null) return;
      _mode = s['mode'] as String? ?? _mode;
      _difficulty = s['difficulty'] as String? ?? _difficulty;
      _winLength = s['winLength'] as int? ?? _winLength;
      _playerMark = s['playerMark'] == 'O' ? Mark.o : Mark.x;
      _youStart = s['youStart'] as bool? ?? _youStart;
      _bestOf = s['bestOf'] as int? ?? _bestOf;
    });
  }

  Future<void> _open(GameScreen game) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => game));
    _load(); // the game may have finished or been left unfinished
  }

  void _start() {
    widget.store.saveSettings({
      'mode': _mode,
      'difficulty': _difficulty,
      'winLength': _winLength,
      'playerMark': _playerMark.symbol,
      'youStart': _youStart,
      'bestOf': _bestOf,
    }, uid: widget.uid);
    _open(GameScreen(
        size: _size,
        store: widget.store,
        uid: widget.uid,
        difficulty: _vsComputer ? _difficulty : null,
        winLength: _size == 8 ? _winLength : null,
        playerMark: _playerMark,
        firstToMove: _firstToMove,
        bestOf: _bestOf));
  }

  // Against the computer "who starts" is you or the computer; in a local
  // game it is X or O.
  Mark get _firstToMove => _vsComputer
      ? (_youStart ? _playerMark : _playerMark.other)
      : (_youStart ? Mark.x : Mark.o);

  Widget _choice<T>(List<(T, String)> options, T value, ValueChanged<T> set) =>
      SegmentedButton<T>(
        segments: [
          for (final (v, text) in options)
            ButtonSegment(value: v, label: Text(text)),
        ],
        selected: {value},
        onSelectionChanged: (s) => setState(() => set(s.single)),
      );

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final label = text.titleMedium?.copyWith(fontWeight: FontWeight.w700);
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('New game'),
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
                  if (_current != null) ...[
                    FilledButton.tonalIcon(
                      onPressed: () => _open(GameScreen.resume(_current!,
                          store: widget.store, uid: widget.uid)),
                      icon: const Icon(Icons.play_circle_outline_rounded),
                      label: Text(context.tr('Continue unfinished game')),
                    ),
                    const SizedBox(height: 24),
                  ],
                  Text(context.tr('Board'), style: label),
                  const SizedBox(height: 8),
                  SegmentedButton<int>(
                    segments: [
                      ButtonSegment(
                          value: 3,
                          icon: Icon(Icons.grid_3x3_rounded),
                          label: Text(context.tr('Classic 3×3'))),
                      ButtonSegment(
                          value: 8,
                          icon: Icon(Icons.grid_4x4_rounded),
                          label: Text(context.tr('Big 8×8'))),
                    ],
                    selected: {_size},
                    onSelectionChanged: (s) => setState(() => _size = s.single),
                  ),
                  const SizedBox(height: 8),
                  if (_size == 8) ...[
                    _choice(
                        [
                          (4, context.tr('4 in a row')),
                          (5, context.tr('5 in a row')),
                        ],
                        _winLength,
                        (v) => _winLength = v),
                    const SizedBox(height: 8),
                  ],
                  Text(context.tr(_size == 3
                      ? 'Three in a row wins.'
                      : '${_winLength == 4 ? 'Four' : 'Five'} in a row wins. Pinch the board to zoom.')),
                  const SizedBox(height: 24),
                  Text(context.tr('Mode'), style: label),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: [
                      ButtonSegment(
                          value: 'local',
                          icon: Icon(Icons.people_alt_rounded),
                          label: Text(context.tr('Two players'))),
                      ButtonSegment(
                          value: 'computer',
                          icon: Icon(Icons.smart_toy_rounded),
                          label: Text(context.tr('Computer'))),
                    ],
                    selected: {_mode},
                    onSelectionChanged: (s) => setState(() => _mode = s.single),
                  ),
                  const SizedBox(height: 8),
                  Text(_mode == 'local'
                      ? 'Two players take turns on this device.'
                      : 'Works without internet.'),
                  if (_mode == 'computer') ...[
                    const SizedBox(height: 24),
                    Text(context.tr('Difficulty'), style: label),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final d in difficulties)
                        ChoiceChip(
                          label: Text(context
                              .tr('${d[0].toUpperCase()}${d.substring(1)}')),
                          selected: _difficulty == d,
                          onSelected: (_) => setState(() => _difficulty = d),
                        ),
                    ]),
                    const SizedBox(height: 24),
                    Text(context.tr('You play'), style: label),
                    const SizedBox(height: 8),
                    _choice([(Mark.x, 'X'), (Mark.o, 'O')], _playerMark,
                        (v) => _playerMark = v),
                  ],
                  const SizedBox(height: 24),
                  Text(context.tr('Who starts'), style: label),
                  const SizedBox(height: 8),
                  _choice(
                      _vsComputer
                          ? [(true, 'You'), (false, 'Computer')]
                          : [(true, 'X'), (false, 'O')],
                      _youStart,
                      (v) => _youStart = v),
                  const SizedBox(height: 24),
                  Text(context.tr('Match'), style: label),
                  const SizedBox(height: 8),
                  _choice([(1, 'Single'), (3, 'Best of 3'), (5, 'Best of 5')],
                      _bestOf, (v) => _bestOf = v),
                  const SizedBox(height: 32),
                  FilledButton.icon(
                    onPressed: _start,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text(context.tr('Start game')),
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
