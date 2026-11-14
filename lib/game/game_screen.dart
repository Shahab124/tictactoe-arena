import 'package:flutter/material.dart';
import 'package:game_engine/game_engine.dart';

import '../data/game_record.dart';
import '../data/game_store.dart';

/// Local two-player game on one device (REQ-MODE-02): the board, whose turn
/// it is, the winning line and one-tap rematch (REQ-PLAT-05, 07, 08, 13).
class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    required this.size,
    required this.store,
    this.uid,
  });

  final int size;
  final GameStore store;

  /// Null for a guest.
  final String? uid;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late Game _game = Game(size: widget.size);

  void _tap(int row, int col) {
    final result = _game.play(row, col);
    if (result == MoveResult.occupied) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
            const SnackBar(content: Text('That cell is already taken')));
      return;
    }
    if (result != MoveResult.ok) return; // game over: ignore (D3 REQ-PLAT 6.1)
    setState(() {});
    if (_game.isOver) _save();
  }

  // The signed-in player is X in a local game, so results are from X's side.
  void _save() {
    widget.store.save(
      GameRecord(
        boardSize: _game.size,
        winLength: _game.winLength,
        mode: 'local',
        opponent: 'Local player',
        moves: _game.moves,
        result: switch (_game.status) {
          GameStatus.xWon => 'win',
          GameStatus.oWon => 'loss',
          _ => 'draw',
        },
        playedAt: DateTime.now(),
      ),
      uid: widget.uid,
    );
  }

  String get _statusText => switch (_game.status) {
        GameStatus.inProgress => "${_game.sideToMove.symbol}'s turn",
        GameStatus.xWon => 'X wins!',
        GameStatus.oWon => 'O wins!',
        GameStatus.draw => "It's a draw",
      };

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final winning = _game.winningCells.toSet();
    return Scaffold(
      appBar: AppBar(title: Text('${widget.size}×${widget.size} · two players')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_statusText,
                  style: Theme.of(context).textTheme.headlineSmall),
            ),
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: GridView.count(
                      crossAxisCount: widget.size,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 2,
                      crossAxisSpacing: 2,
                      children: [
                        for (var r = 0; r < widget.size; r++)
                          for (var c = 0; c < widget.size; c++)
                            _Cell(
                              mark: _game.at(r, c),
                              row: r,
                              col: c,
                              highlighted: winning.contains((r, c)),
                              colors: colors,
                              onTap: () => _tap(r, c),
                            ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton(
                onPressed: () => setState(() => _game = Game(size: widget.size)),
                child: Text(_game.isOver ? 'Rematch' : 'Restart'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.mark,
    required this.row,
    required this.col,
    required this.highlighted,
    required this.colors,
    required this.onTap,
  });

  final Mark? mark;
  final int row, col;
  final bool highlighted;
  final ColorScheme colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // X and O differ by shape, not only colour, and each cell has a
    // screen-reader label (D3 5.8).
    return Semantics(
      button: true,
      label: 'Row ${row + 1}, column ${col + 1}, ${mark?.symbol ?? 'empty'}',
      excludeSemantics: true,
      child: Material(
        color: highlighted ? colors.tertiaryContainer : colors.surfaceContainerHighest,
        child: InkWell(
          onTap: onTap,
          child: Center(
            child: FittedBox(
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Text(
                  mark?.symbol ?? '',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: mark == Mark.x ? colors.primary : colors.error,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
