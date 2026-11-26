import 'package:flutter/material.dart';
import 'package:game_ai/game_ai.dart';
import 'package:game_engine/game_engine.dart';

import '../data/game_record.dart';
import '../ui/mark.dart';

/// Replays a finished game move by move, with the AI marking the best and
/// worst move (REQ-AI-11).
class ReplayScreen extends StatefulWidget {
  const ReplayScreen({super.key, required this.game});

  final GameRecord game;

  @override
  State<ReplayScreen> createState() => _ReplayScreenState();
}

class _ReplayScreenState extends State<ReplayScreen> {
  late final _rating = bestAndWorstMoves(widget.game.moves,
      size: widget.game.boardSize, winLength: widget.game.winLength);
  late int _step = widget.game.moves.length;

  int get _total => widget.game.moves.length;

  // The board after the first [_step] moves.
  // Rebuilding from the move history keeps stepping backward and forward deterministic.
  Game get _board {
    final g = widget.game;
    final game = Game(
        size: g.boardSize,
        winLength: g.winLength,
        firstToMove: g.firstMark == 'O' ? Mark.o : Mark.x);
    for (final (r, c) in g.moves.take(_step)) {
      game.play(r, c);
    }
    return game;
  }

  String _tag(int i) => i == _rating.best
      ? ' · Best move'
      : i == _rating.worst
          ? ' · Worst move'
          : '';

  @override
  Widget build(BuildContext context) {
    final board = _board;
    final size = widget.game.boardSize;
    final colors = Theme.of(context).colorScheme;
    final current = _step == 0 ? null : widget.game.moves[_step - 1];
    final ring = _step - 1 == _rating.best
        ? Colors.green
        : _step - 1 == _rating.worst
            ? colors.error
            : colors.primary;
    final caption = current == null
        ? 'Start'
        : 'Move $_step of $_total · ${board.at(current.$1, current.$2)!.symbol} '
            'at row ${current.$1 + 1}, column ${current.$2 + 1}${_tag(_step - 1)}';
    final worst = _rating.worst;
    return Scaffold(
      appBar: AppBar(title: Text('Replay · vs ${widget.game.opponent}')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(caption,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700)),
              ),
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Card(
                      child: GridView.count(
                        padding: const EdgeInsets.all(6),
                        crossAxisCount: size,
                        mainAxisSpacing: 4,
                        crossAxisSpacing: 4,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          for (var r = 0; r < size; r++)
                            for (var c = 0; c < size; c++)
                              Container(
                                decoration: BoxDecoration(
                                  color: colors.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(6),
                                  border: current == (r, c)
                                      ? Border.all(color: ring, width: 3)
                                      : null,
                                ),
                                child: board.at(r, c) == null
                                    ? null
                                    : MarkView(mark: board.at(r, c)!),
                              ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Wrap(alignment: WrapAlignment.center, spacing: 8, children: [
                TextButton(
                    onPressed: () => setState(() => _step = _rating.best + 1),
                    child: const Text('Show best move')),
                TextButton(
                    onPressed: worst == null
                        ? null
                        : () => setState(() => _step = worst + 1),
                    child: Text(worst == null
                        ? 'No mistakes'
                        : 'Show worst move')),
              ]),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed:
                          _step == 0 ? null : () => setState(() => _step--),
                      icon: const Icon(Icons.chevron_left_rounded),
                      label: const Text('Back'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _step == _total
                          ? null
                          : () => setState(() => _step++),
                      icon: const Icon(Icons.chevron_right_rounded),
                      label: const Text('Next'),
                    ),
                  ),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
