import 'package:flutter/material.dart';
import 'package:game_engine/game_engine.dart';

import 'mark.dart';
import 'strings.dart';
import 'theme.dart';

/// A short tutorial on the first launch, and from Settings (REQ-UX-09).
class TutorialScreen extends StatefulWidget {
  const TutorialScreen({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  final _pages = PageController();
  int _page = 0;

  static const _steps = [
    (
      'Welcome to TicTacToe Arena',
      'Take turns placing X and O. Tap an empty cell to play.',
      ['X', '', '', '', 'O', '', '', '', ''],
      <int>[],
    ),
    (
      'Three in a row wins on 3×3',
      'Get three marks in a row, column or diagonal before the other player.',
      ['X', 'O', '', '', 'X', 'O', '', '', 'X'],
      [0, 4, 8],
    ),
    (
      'Five in a row wins on 8×8',
      'The big board needs five in a row (or four, if you choose it). Pinch to zoom on a phone.',
      ['X', 'X', 'X', 'X', 'X', '', 'O', 'O', 'O'],
      [0, 1, 2, 3, 4],
    ),
    (
      'Play your way',
      'Play a friend on one device, the computer from Easy to Expert, or online with a room code.',
      ['O', '', 'X', '', 'X', '', 'O', '', ''],
      <int>[],
    ),
  ];

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final last = _page == _steps.length - 1;
    return Scaffold(
      appBar: AppBar(
        actions: [
          if (!last)
            TextButton(
                onPressed: widget.onDone, child: Text(context.tr('Skip'))),
        ],
      ),
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: PageView(
              controller: _pages,
              onPageChanged: (p) => setState(() => _page = p),
              children: [
                for (final (title, body, cells, line) in _steps)
                  Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Column(children: [
                          _MiniBoard(cells: cells, line: line),
                          const SizedBox(height: 28),
                          Text(context.tr(title),
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 12),
                          Text(context.tr(body),
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyLarge),
                        ]),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var i = 0; i < _steps.length; i++)
              AnimatedContainer(
                duration: motion(context, 200),
                margin: const EdgeInsets.all(4),
                width: i == _page ? 22 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: i == _page ? 1 : 0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
          ]),
          Padding(
            padding: const EdgeInsets.all(20),
            child: FilledButton(
              onPressed: last
                  ? widget.onDone
                  : () => _pages.nextPage(
                      duration: motion(context, 300), curve: Curves.easeOut),
              child: Text(context.tr(last ? "Let's play" : 'Next')),
            ),
          ),
        ]),
      ),
    );
  }
}

class _MiniBoard extends StatelessWidget {
  const _MiniBoard({required this.cells, required this.line});

  final List<String> cells;
  final List<int> line;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: 180,
        child: GridView.count(
          crossAxisCount: 3,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (var i = 0; i < 9; i++)
              DecoratedBox(
                decoration: BoxDecoration(
                  color: line.contains(i)
                      ? ArenaColors.win.withValues(alpha: 0.45)
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: cells[i].isEmpty
                    ? null
                    : MarkView(mark: cells[i] == 'X' ? Mark.x : Mark.o),
              ),
          ],
        ),
      ),
    );
  }
}
