/// Game rules: boards, legal moves, and win and draw detection (D3 section 2.2).
///
/// Pure Dart with no interface or network code, so it can be tested alone
/// (D3 section 3.4).
library;

/// A mark a player places.
enum Mark {
  x('X'),
  o('O');

  const Mark(this.symbol);

  /// 'X' or 'O', as in the AI request format (D3 section 2.4).
  final String symbol;

  Mark get other => this == x ? o : x;
}

enum GameStatus { inProgress, xWon, oWon, draw }

/// What happened to a move (D3 REQ-PLAT-06.1).
enum MoveResult {
  /// The mark was placed.
  ok,

  /// The game is already won or drawn; the move is ignored.
  gameOver,

  /// The cell is outside the board.
  offBoard,

  /// The cell already holds a mark.
  occupied,

  /// The mark doesn't belong to the side to move.
  wrongTurn,
}

/// One game of 3×3 or 8×8 Tic-Tac-Toe.
class Game {
  /// Starts a game. On 3×3 the win length is 3; on 8×8 it is 5 unless 4 is
  /// chosen (D3 rule 1).
  Game({this.size = 3, int? winLength, this.firstToMove = Mark.x})
      : winLength = winLength ?? (size == 3 ? 3 : 5),
        _cells = List.generate(size, (_) => List<Mark?>.filled(size, null)),
        _sideToMove = firstToMove {
    if (size != 3 && size != 8) {
      throw ArgumentError.value(size, 'size', 'must be 3 or 8');
    }
    final allowed = size == 3 ? const [3] : const [4, 5];
    if (!allowed.contains(this.winLength)) {
      throw ArgumentError.value(
          this.winLength, 'winLength', 'must be one of $allowed on $size×$size');
    }
  }

  final int size;
  final int winLength;
  final Mark firstToMove;

  final List<List<Mark?>> _cells;
  final List<(int, int)> _moves = [];
  Mark _sideToMove;
  GameStatus _status = GameStatus.inProgress;
  List<(int, int)> _winningCells = const [];

  Mark get sideToMove => _sideToMove;
  GameStatus get status => _status;
  bool get isOver => _status != GameStatus.inProgress;

  /// Moves so far, in order, as (row, col).
  List<(int, int)> get moves => List.unmodifiable(_moves);

  /// The cells of the winning line, or empty if nobody has won.
  List<(int, int)> get winningCells => _winningCells;

  /// The mark at ([row], [col]), or null if the cell is empty.
  Mark? at(int row, int col) => _cells[row][col];

  /// Places the side to move's mark at ([row], [col]).
  ///
  /// Pass [mark] to check it belongs to the side to move (for example, a move
  /// from the Game AI). Any result other than [MoveResult.ok] leaves the game
  /// unchanged (D3 rule 3).
  MoveResult play(int row, int col, {Mark? mark}) {
    if (isOver) return MoveResult.gameOver;
    if (row < 0 || row >= size || col < 0 || col >= size) {
      return MoveResult.offBoard;
    }
    if (_cells[row][col] != null) return MoveResult.occupied;
    if (mark != null && mark != _sideToMove) return MoveResult.wrongTurn;

    _cells[row][col] = _sideToMove;
    _moves.add((row, col));
    _updateStatus(row, col);
    if (!isOver) _sideToMove = _sideToMove.other;
    return MoveResult.ok;
  }

  /// The board as rows of 'X', 'O' or '' (the AI request format, D3 2.4).
  List<List<String>> toBoard() => [
        for (final row in _cells) [for (final m in row) m?.symbol ?? '']
      ];

  // Counts matching marks through the last move in each of the four
  // directions (D3 REQ-PLAT-08.1).
  void _updateStatus(int row, int col) {
    final mark = _cells[row][col];
    for (final (dr, dc) in const [(0, 1), (1, 0), (1, 1), (1, -1)]) {
      final line = [(row, col)];
      for (final sign in const [1, -1]) {
        var r = row + dr * sign, c = col + dc * sign;
        while (r >= 0 && r < size && c >= 0 && c < size && _cells[r][c] == mark) {
          line.add((r, c));
          r += dr * sign;
          c += dc * sign;
        }
      }
      if (line.length >= winLength) {
        _winningCells = line..sort((a, b) => a.$1 != b.$1 ? a.$1 - b.$1 : a.$2 - b.$2);
        _status = mark == Mark.x ? GameStatus.xWon : GameStatus.oWon;
        return;
      }
    }
    if (_moves.length == size * size) _status = GameStatus.draw;
  }
}
