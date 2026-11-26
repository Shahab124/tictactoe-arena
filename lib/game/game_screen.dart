import 'package:flutter/material.dart';
import 'package:game_engine/game_engine.dart';

import '../data/game_record.dart';
import '../data/game_store.dart';
import '../ui/app_settings.dart';
import '../ui/mark.dart';
import '../ui/theme.dart';
import 'ai_client.dart';
import 'replay_screen.dart';

/// A game on one device: two local players (REQ-MODE-02), or the player as X
/// against the computer as O when [difficulty] is set (REQ-MODE-01). Shows
/// the board, whose turn it is, the winning line and one-tap rematch
/// (REQ-PLAT-05, 07, 08, 13). Also covers 4 or 5 in a row on 8×8, the
/// last-move marker, undo against the computer, X/O and who starts, and
/// best-of-3/5 matches (REQ-PLAT-04, 12, 14, 15, REQ-MODE-06).
class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    required this.size,
    required this.store,
    this.uid,
    this.difficulty,
    this.ai = localAi,
    this.winLength,
    this.playerMark = Mark.x,
    this.firstToMove = Mark.x,
    this.bestOf = 1,
    this.resumeMoves = const [],
    this.resumeWins = const {},
  });

  /// Continues an unfinished game saved by the game screen (REQ-DATA-06).
  factory GameScreen.resume(Map<String, dynamic> saved,
      {required GameStore store, String? uid, AiClient ai = localAi}) {
    Mark mark(Object? s) => s == 'O' ? Mark.o : Mark.x;
    final wins = (saved['wins'] as Map?) ?? {};
    return GameScreen(
      size: saved['size'] as int,
      store: store,
      uid: uid,
      ai: ai,
      difficulty: saved['difficulty'] as String?,
      winLength: saved['winLength'] as int?,
      playerMark: mark(saved['playerMark']),
      firstToMove: mark(saved['firstToMove']),
      bestOf: saved['bestOf'] as int? ?? 1,
      resumeMoves: [
        for (final m in saved['moves'] as List)
          ((m as Map)['r'] as int, m['c'] as int)
      ],
      resumeWins: {
        Mark.x: wins['X'] as int? ?? 0,
        Mark.o: wins['O'] as int? ?? 0,
      },
    );
  }

  /// Moves already played and the match score, when continuing a game.
  final List<(int, int)> resumeMoves;
  final Map<Mark, int> resumeWins;

  final int size;

  /// 4 or 5 on 8×8; null for the default.
  final int? winLength;

  /// The player's mark against the computer.
  final Mark playerMark;
  final Mark firstToMove;

  /// 1 for a single game, or 3 or 5 for a match.
  final int bestOf;
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
  late Game _game = _newGame();
  bool _thinking = false;
  bool _aiFailed = false;

  /// The cell the Hint button suggests, until the next move (REQ-AI-09).
  (int, int)? _hint;
  GameRecord? _record; // the finished game, for Replay
  final _wins = {Mark.x: 0, Mark.o: 0};

  bool get _vsComputer => widget.difficulty != null;
  Mark get _aiMark => widget.playerMark.other;

  Game _newGame() => Game(
      size: widget.size,
      winLength: widget.winLength,
      firstToMove: widget.firstToMove);

  bool get _matchOver =>
      widget.bestOf > 1 && _wins.values.any((w) => w > widget.bestOf ~/ 2);

  @override
  void initState() {
    super.initState();
    for (final (r, c) in widget.resumeMoves) {
      _game.play(r, c);
    }
    _wins.addAll(widget.resumeWins);
    if (_vsComputer && !_game.isOver && _game.sideToMove == _aiMark) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _computerTurn());
    }
  }

  void _tap(int row, int col) {
    if (_thinking || _aiFailed) return; // it is the computer's turn
    if (_vsComputer && _game.sideToMove == _aiMark) return;
    final result = _game.play(row, col);
    if (result == MoveResult.occupied) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
            const SnackBar(content: Text('That cell is already taken')));
      return;
    }
    if (result != MoveResult.ok) return; // game over: ignore (D3 REQ-PLAT 6.1)
    setState(() => _hint = null);
    AppSettings.of(context).feedback(gameOver: _game.isOver);
    _persist();
    if (_game.isOver) {
      _finish();
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
        'sideToMove': _aiMark.symbol,
        'difficulty': widget.difficulty,
      }).timeout(Duration(seconds: game.size == 3 ? 1 : 2)); // D3 5.1
    } catch (_) {
      reply = null; // too slow or crashed: handled like an AI error
    }
    if (!mounted || game != _game) return; // left or restarted meanwhile
    final row = reply?['row'], col = reply?['col'];
    final played = row is int &&
        col is int &&
        game.play(row, col, mark: _aiMark) == MoveResult.ok;
    setState(() {
      _thinking = false;
      _aiFailed = !played;
    });
    if (played) AppSettings.of(context).feedback(gameOver: game.isOver);
    _persist();
    if (game.isOver) _finish();
  }

  // Asks the AI, at its strongest, what it would play for the side to move.
  Future<void> _showHint() async {
    final game = _game;
    final reply = await widget.ai({
      'board': game.toBoard(),
      'winLength': game.winLength,
      'sideToMove': game.sideToMove.symbol,
      'difficulty': 'expert',
    });
    final row = reply['row'], col = reply['col'];
    if (!mounted || game != _game || row is! int || col is! int) return;
    setState(() => _hint = (row, col));
  }

  bool get _canHint =>
      !_thinking &&
      !_aiFailed &&
      !_game.isOver &&
      (!_vsComputer || _game.sideToMove == widget.playerMark);

  void _finish() {
    _save();
    final winner = switch (_game.status) {
      GameStatus.xWon => Mark.x,
      GameStatus.oWon => Mark.o,
      _ => null,
    };
    setState(() {
      if (winner != null) _wins[winner] = _wins[winner]! + 1;
    });
    _persist();
  }

  // Keeps the unfinished game in the store after every change, so it can be
  // continued after closing the app or on another device (REQ-DATA-06).
  // Between games of a match only the score is kept.
  void _persist() {
    final moves = _game.isOver ? const <(int, int)>[] : _game.moves;
    final done = _game.isOver && (widget.bestOf == 1 || _matchOver);
    final fresh = moves.isEmpty && _wins.values.every((w) => w == 0);
    widget.store.saveCurrent(done || fresh ? null : _toSaved(moves),
        uid: widget.uid);
  }

  Map<String, dynamic> _toSaved(List<(int, int)> moves) => {
        'size': widget.size,
        'winLength': widget.winLength,
        'difficulty': widget.difficulty,
        'playerMark': widget.playerMark.symbol,
        'firstToMove': widget.firstToMove.symbol,
        'bestOf': widget.bestOf,
        'moves': [for (final (r, c) in moves) {'r': r, 'c': c}],
        'wins': {'X': _wins[Mark.x], 'O': _wins[Mark.o]},
      };

  // Rematch, Restart, Next game or New match.
  void _restart() {
    setState(() {
      if (_matchOver) _wins.updateAll((_, __) => 0);
      _game = _newGame();
      _thinking = false;
      _aiFailed = false;
      _hint = null;
    });
    _persist();
    if (_vsComputer && widget.firstToMove == _aiMark) _computerTurn();
  }

  // Undo against the computer takes back the player's last move and the
  // computer's reply to it (REQ-PLAT-14).
  bool get _canUndo =>
      _vsComputer &&
      !_thinking &&
      !_game.isOver &&
      _game.moves.length > (widget.firstToMove == _aiMark ? 1 : 0);

  void _undo() {
    setState(() {
      if (_game.sideToMove == widget.playerMark) _game.undo();
      _game.undo();
      _aiFailed = false;
      _hint = null;
    });
    _persist();
  }

  String get _opponent {
    final d = widget.difficulty!;
    return 'Computer (${d[0].toUpperCase()}${d.substring(1)})';
  }

  // Against the computer results are from the player's side; in a local
  // game the signed-in player is X.
  void _save() {
    final me = _vsComputer ? widget.playerMark : Mark.x;
    _record = GameRecord(
        boardSize: _game.size,
        winLength: _game.winLength,
        mode: _vsComputer ? 'computer' : 'local',
        opponent: _vsComputer ? _opponent : 'Local player',
        moves: _game.moves,
        result: switch (_game.status) {
          GameStatus.draw => 'draw',
          GameStatus.xWon => me == Mark.x ? 'win' : 'loss',
          _ => me == Mark.o ? 'win' : 'loss',
        },
        playedAt: DateTime.now(),
        firstMark: _game.firstToMove.symbol,
    );
    widget.store.save(_record!, uid: widget.uid);
  }

  String _name(Mark m) => !_vsComputer
      ? m.symbol
      : m == widget.playerMark
          ? 'You'
          : 'Computer';

  String get _statusText {
    if (_aiFailed) return 'The computer could not make a move';
    if (_thinking) return 'Computer is thinking…';
    final winner = switch (_game.status) {
      GameStatus.inProgress => null,
      GameStatus.draw => null,
      GameStatus.xWon => Mark.x,
      GameStatus.oWon => Mark.o,
    };
    if (!_game.isOver) {
      return _vsComputer ? 'Your turn' : "${_game.sideToMove.symbol}'s turn";
    }
    if (winner == null) return "It's a draw";
    final name = _name(winner);
    final verb = name == 'You' ? 'win' : 'wins';
    return _matchOver ? '$name $verb the match!' : '$name $verb!';
  }

  /// The running score of a best-of-3 or best-of-5 match (REQ-MODE-06).
  String get _scoreText =>
      'Best of ${widget.bestOf} · ${_name(Mark.x)} ${_wins[Mark.x]} – '
      '${_wins[Mark.o]} ${_name(Mark.o)}';

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final winning = _game.winningCells.toSet();
    final last = _game.moves.isEmpty ? null : _game.moves.last;
    final gap = widget.size == 3 ? 10.0 : 4.0;
    final turn = _game.isOver ? null : _game.sideToMove;
    final header = Row(children: [
      Expanded(
          child: _PlayerChip(
              mark: Mark.x,
              label: _vsComputer ? _name(Mark.x) : 'Player X',
              active: turn == Mark.x)),
      const SizedBox(width: 12),
      Expanded(
          child: _PlayerChip(
              mark: Mark.o,
              label: _vsComputer ? _name(Mark.o) : 'Player O',
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
                  lastMove: last == (r, c),
                  hinted: _hint == (r, c),
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
      if (widget.bestOf > 1)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(_scoreText,
              style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
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
        : Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
                if (!_game.isOver)
                  OutlinedButton.icon(
                    onPressed: _canHint ? _showHint : null,
                    icon: const Icon(Icons.lightbulb_outline_rounded),
                    label: const Text('Hint'),
                  ),
                if (_game.isOver && _record != null)
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => ReplayScreen(game: _record!))),
                    icon: const Icon(Icons.slideshow_rounded),
                    label: const Text('Replay'),
                  ),
                if (_vsComputer)
                  OutlinedButton.icon(
                    onPressed: _canUndo ? _undo : null,
                    icon: const Icon(Icons.undo_rounded),
                    label: const Text('Undo'),
                  ),
                FilledButton.icon(
                  onPressed: _restart,
                  icon: Icon(_game.isOver
                      ? Icons.replay_rounded
                      : Icons.restart_alt_rounded),
                  label: Text(!_game.isOver
                      ? 'Restart'
                      : widget.bestOf == 1
                          ? 'Rematch'
                          : _matchOver
                              ? 'New match'
                              : 'Next game'),
                ),
              ]);
    return Scaffold(
      appBar: AppBar(
        title: Text(
            widget.size == 3
                ? 'Classic 3×3'
                : 'Big 8×8 · ${_game.winLength == 4 ? 'four' : 'five'} in a row',
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
    required this.lastMove,
    required this.hinted,
    required this.radius,
    required this.colors,
    required this.onTap,
  });

  final Mark? mark;
  final int row, col;
  final bool highlighted;

  /// Marked with a ring so the player sees the latest move (REQ-PLAT-12).
  final bool lastMove;

  /// Suggested by the Hint button.
  final bool hinted;
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
      value: hinted
          ? 'hint'
          : lastMove
              ? 'last move'
              : null,
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: motion(context, 350),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          borderRadius: shape,
          color: highlighted
              ? ArenaColors.win.withValues(alpha: 0.45)
              : colors.surfaceContainerHighest,
          border: hinted || lastMove
              ? Border.all(
                  color: hinted ? Colors.green : colors.primary,
                  width: radius > 10 ? 3 : 2)
              : null,
          boxShadow: highlighted
              ? [
                  BoxShadow(
                      color: ArenaColors.win.withValues(alpha: 0.5),
                      blurRadius: 12)
                ]
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
    final skin = AppSettings.of(context).skin;
    final color = mark == Mark.x ? skin.x : skin.o;
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
          border:
              Border.all(color: active ? color : Colors.transparent, width: 2),
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
