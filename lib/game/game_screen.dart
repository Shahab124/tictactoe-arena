import 'package:flutter/material.dart';
import 'package:game_engine/game_engine.dart';

import '../data/game_record.dart';
import '../data/game_store.dart';
import '../ui/mark.dart';
import '../ui/theme.dart';
import 'ai_client.dart';

/// A game on one device: two local players (REQ-MODE-02), or the player as X
/// against the computer as O when [difficulty] is set (REQ-MODE-01). Shows
/// the board, whose turn it is, the winning line and one-tap rematch
/// (REQ-PLAT-05, 07, 08, 13).
class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    required this.size,
    required this.store,
    this.uid,
    this.difficulty,
    this.ai = localAi,
  });

  final int size;
  final GameStore store;

  /// 'easy', 'medium', 'hard' or 'expert' to play the computer; null for two
  /// local players.
  final String? difficulty;
  final AiClient ai;

  /// Null for a guest.
  final String? uid;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late Game _game = Game(size: widget.size);
  bool _thinking = false;
  bool _aiFailed = false;

  bool get _vsComputer => widget.difficulty != null;

  void _tap(int row, int col) {
    if (_thinking || _aiFailed) return; // it is the computer's turn
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
    if (_game.isOver) {
      _save();
    } else if (_vsComputer) {
      _computerTurn();
    }
  }

  // REQ-INT-02.1: ask the AI for one move and play it only if the Game
  // Engine accepts it. An error, an illegal move or no answer in time leaves
  // the board unchanged and offers Retry or End game.
  Future<void> _computerTurn() async {
    final game = _game;
    setState(() {
      _thinking = true;
      _aiFailed = false;
    });
    Map<String, Object>? reply;
    try {
      // A short pause so the player sees the computer take its turn.
      await Future<void>.delayed(const Duration(milliseconds: 400));
      reply = await widget.ai({
        'board': game.toBoard(),
        'winLength': game.winLength,
        'sideToMove': Mark.o.symbol,
        'difficulty': widget.difficulty,
      }).timeout(Duration(seconds: game.size == 3 ? 1 : 2)); // D3 5.1
    } catch (_) {
      reply = null; // too slow or crashed: handled like an AI error
    }
    if (!mounted || game != _game) return; // left or restarted meanwhile
    final row = reply?['row'], col = reply?['col'];
    final played = row is int &&
        col is int &&
        game.play(row, col, mark: Mark.o) == MoveResult.ok;
    setState(() {
      _thinking = false;
      _aiFailed = !played;
    });
    if (game.isOver) _save();
  }

  void _restart() => setState(() {
        _game = Game(size: widget.size);
        _thinking = false;
        _aiFailed = false;
      });

  String get _opponent {
    final d = widget.difficulty!;
    return 'Computer (${d[0].toUpperCase()}${d.substring(1)})';
  }

  // The player is X in local and computer games, so results are from X's side.
  void _save() {
    widget.store.save(
      GameRecord(
        boardSize: _game.size,
        winLength: _game.winLength,
        mode: _vsComputer ? 'computer' : 'local',
        opponent: _vsComputer ? _opponent : 'Local player',
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

  String get _statusText {
    if (_aiFailed) return 'The computer could not make a move';
    if (_thinking) return 'Computer is thinking…';
    return switch (_game.status) {
      GameStatus.inProgress =>
        _vsComputer ? 'Your turn' : "${_game.sideToMove.symbol}'s turn",
      GameStatus.xWon => _vsComputer ? 'You win!' : 'X wins!',
      GameStatus.oWon => _vsComputer ? 'Computer wins!' : 'O wins!',
      GameStatus.draw => "It's a draw",
    };
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final winning = _game.winningCells.toSet();
    final gap = widget.size == 3 ? 10.0 : 4.0;
    final turn = _game.isOver ? null : _game.sideToMove;
    final header = Row(children: [
      Expanded(
          child: _PlayerChip(
              mark: Mark.x,
              label: _vsComputer ? 'You' : 'Player X',
              active: turn == Mark.x)),
      const SizedBox(width: 12),
      Expanded(
          child: _PlayerChip(
              mark: Mark.o,
              label: _vsComputer ? 'Computer' : 'Player O',
              active: turn == Mark.o)),
    ]);
    final status = Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: AnimatedSwitcher(
        duration: motion(context, 250),
        transitionBuilder: (child, a) => FadeTransition(
          opacity: a,
          child: ScaleTransition(
              scale: Tween(begin: 0.85, end: 1.0).animate(a), child: child),
        ),
        child: Text(
          _statusText,
          key: ValueKey(_statusText),
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
    );
    Widget grid = Card(
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
    );
    // The 8×8 cells are small on a phone, so the player can pinch to zoom
    // and drag to move around the board (REQ-PLAT-11).
    if (widget.size == 8) {
      grid = InteractiveViewer(minScale: 1, maxScale: 4, child: grid);
    }
    final board = Center(child: AspectRatio(aspectRatio: 1, child: grid));
    final hint = [
      if (widget.size == 8)
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text('Pinch to zoom, drag to move'),
        ),
    ];
    final button = _aiFailed
        ? Row(children: [
            Expanded(
              child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('End game')),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                  onPressed: _computerTurn, child: const Text('Retry')),
            ),
          ])
        : FilledButton.icon(
            onPressed: _restart,
            icon: Icon(_game.isOver
                ? Icons.replay_rounded
                : Icons.restart_alt_rounded),
            label: Text(_game.isOver ? 'Rematch' : 'Restart'),
          );
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.size == 3 ? 'Classic 3×3' : 'Big 8×8 · five in a row',
            style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: SafeArea(
        child: LayoutBuilder(builder: (context, box) {
          // Landscape phones and tablets: board on the left, controls on the
          // right, so the board uses the full height (REQ-UX-02).
          if (box.maxWidth > box.maxHeight) {
            return Row(children: [
              Expanded(
                child: Padding(padding: const EdgeInsets.all(12), child: board),
              ),
              SizedBox(
                width: 300,
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(children: [header, status, ...hint, button]),
                  ),
                ),
              ),
            ]);
          }
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: header,
                ),
                status,
                ...hint,
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: board,
                  ),
                ),
                Padding(padding: const EdgeInsets.all(16), child: button),
              ]),
            ),
          );
        }),
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
  const _PlayerChip(
      {required this.mark, required this.label, required this.active});

  final Mark mark;
  final String label;
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
            child: Text(label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontWeight: active ? FontWeight.w800 : FontWeight.w500)),
          ),
        ]),
      ),
    );
  }
}
