import 'package:flutter/material.dart';
import 'package:game_engine/game_engine.dart';

import '../data/game_record.dart';
import '../data/game_store.dart';
import '../ui/mark.dart';
import '../ui/theme.dart';

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
    final gap = widget.size == 3 ? 10.0 : 4.0;
    final turn = _game.isOver ? null : _game.sideToMove;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.size == 3 ? 'Classic 3×3' : 'Big 8×8 · five in a row',
            style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(children: [
                    Expanded(child: _PlayerChip(mark: Mark.x, active: turn == Mark.x)),
                    const SizedBox(width: 12),
                    Expanded(child: _PlayerChip(mark: Mark.o, active: turn == Mark.o)),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: AnimatedSwitcher(
                    duration: motion(context, 250),
                    transitionBuilder: (child, a) => FadeTransition(
                      opacity: a,
                      child: ScaleTransition(
                          scale: Tween(begin: 0.85, end: 1.0).animate(a),
                          child: child),
                    ),
                    child: Text(
                      _statusText,
                      key: ValueKey(_statusText),
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Card(
                          child: Padding(
                            padding: EdgeInsets.all(gap),
                            child: GridView.count(
                              crossAxisCount: widget.size,
                              physics: const NeverScrollableScrollPhysics(),
                              mainAxisSpacing: gap,
                              crossAxisSpacing: gap,
                              children: [
                                for (var r = 0; r < widget.size; r++)
                                  for (var c = 0; c < widget.size; c++)
                                    _Cell(
                                      mark: _game.at(r, c),
                                      row: r,
                                      col: c,
                                      highlighted: winning.contains((r, c)),
                                      radius: widget.size == 3 ? 14 : 6,
                                      colors: colors,
                                      onTap: () => _tap(r, c),
                                    ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: FilledButton.icon(
                    onPressed: () => setState(() => _game = Game(size: widget.size)),
                    icon: Icon(_game.isOver
                        ? Icons.replay_rounded
                        : Icons.restart_alt_rounded),
                    label: Text(_game.isOver ? 'Rematch' : 'Restart'),
                  ),
                ),
              ],
            ),
          ),
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
    required this.radius,
    required this.colors,
    required this.onTap,
  });

  final Mark? mark;
  final int row, col;
  final bool highlighted;
  final double radius;
  final ColorScheme colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // X and O differ by shape, not only colour, and each cell has a
    // screen-reader label (D3 5.8).
    final shape = BorderRadius.circular(radius);
    return Semantics(
      button: true,
      label: 'Row ${row + 1}, column ${col + 1}, ${mark?.symbol ?? 'empty'}',
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: motion(context, 350),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          borderRadius: shape,
          color: highlighted
              ? ArenaColors.win.withValues(alpha: 0.45)
              : colors.surfaceContainerHighest,
          boxShadow: highlighted
              ? [BoxShadow(color: ArenaColors.win.withValues(alpha: 0.5), blurRadius: 12)]
              : null,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: shape,
            onTap: onTap,
            child: mark == null ? null : MarkView(mark: mark!),
          ),
        ),
      ),
    );
  }
}

/// Shows a player's mark; lights up when it is their turn.
class _PlayerChip extends StatelessWidget {
  const _PlayerChip({required this.mark, required this.active});

  final Mark mark;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = mark == Mark.x ? ArenaColors.x : ArenaColors.o;
    return ExcludeSemantics(
      child: AnimatedContainer(
        duration: motion(context, 250),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: active
              ? color.withValues(alpha: 0.16)
              : Theme.of(context).colorScheme.surface.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: active ? color : Colors.transparent, width: 2),
        ),
        child: Row(children: [
          SizedBox.square(dimension: 28, child: MarkView(mark: mark)),
          const SizedBox(width: 10),
          Flexible(
            child: Text('Player ${mark.symbol}',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontWeight: active ? FontWeight.w800 : FontWeight.w500)),
          ),
        ]),
      ),
    );
  }
}
