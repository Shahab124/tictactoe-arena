/// Game AI: returns one legal move through a documented interface
/// (D3 sections 2.4, REQ-INT-01.1 and REQ-INT-04.1).
///
/// Pure Dart with no database or network access, so another group can call
/// it from their own platform.
library;

import 'dart:math';

/// The difficulties the AI accepts.
const difficulties = ['easy', 'medium', 'hard', 'expert'];

/// One AI request, as in D3 section 2.4:
///
/// ```json
/// { "board": [["X","",""], ["","O",""], ["","",""]],
///   "winLength": 3, "sideToMove": "X", "difficulty": "medium" }
/// ```
///
/// Returns either `{"row": r, "col": c}` or `{"error": CODE, "message": text}`.
/// It never throws and never changes the input board.
Map<String, Object> requestMove(Map<String, dynamic> request, {Random? random}) {
  final board = request['board'];
  final winLength = request['winLength'];
  final side = request['sideToMove'];
  final difficulty = request['difficulty'] ?? 'medium';

  final error = _validate(board, winLength, side, difficulty);
  if (error != null) return error;

  final cells = [for (final row in board as List) List<String>.from(row as List)];
  if (_hasLine(cells, winLength as int) || _empty(cells).isEmpty) {
    return _error('GAME_OVER', 'The game is already won or the board is full.');
  }

  final rnd = random ?? Random();
  final win = winLength;
  final me = side as String;
  final (row, col) = switch (difficulty) {
    'easy' => _easy(cells, rnd),
    'medium' => _medium(cells, me, win, rnd),
    'hard' => cells.length == 3 ? _hard3x3(cells, me) : _medium(cells, me, win, rnd),
    _ => cells.length == 3 ? _hard3x3(cells, me) : _expert(cells, me, win),
  };
  return {'row': row, 'col': col};
}

// Easy: any empty cell at random, so a beginner can win (REQ-AI-02).
(int, int) _easy(List<List<String>> cells, Random random) {
  final empty = _empty(cells);
  return empty[random.nextInt(empty.length)];
}

// Medium: takes a win, else blocks the opponent's win, else plays at random,
// so it misses forks and can still lose (REQ-AI-03).
(int, int) _medium(List<List<String>> cells, String me, int win, Random random) =>
    _winningMove(cells, me, win) ??
    _winningMove(cells, _other(me), win) ??
    _easy(cells, random);

(int, int)? _winningMove(List<List<String>> cells, String mark, int win) {
  for (final (r, c) in _empty(cells)) {
    cells[r][c] = mark;
    final wins = _hasLine(cells, win);
    cells[r][c] = '';
    if (wins) return (r, c);
  }
  return null;
}

// Hard on 3×3: full minimax search, so it never loses (REQ-AI-04).
// ponytail: on 8×8 Hard plays like Medium; Expert is the strong 8×8 level.
(int, int) _hard3x3(List<List<String>> cells, String me) {
  var best = -1000;
  late (int, int) bestMove;
  for (final (r, c) in _empty(cells)) {
    cells[r][c] = me;
    final score = -_negamax(cells, _other(me), 1, -1000, 1000);
    cells[r][c] = '';
    if (score > best) {
      best = score;
      bestMove = (r, c);
    }
  }
  return bestMove;
}

// Score for [toMove] with perfect play; faster wins and slower losses score
// higher, so Hard wins as soon as it can.
int _negamax(List<List<String>> cells, String toMove, int depth, int alpha, int beta) {
  if (_hasLine(cells, 3)) return depth - 10; // the player who just moved won
  final empty = _empty(cells);
  if (empty.isEmpty) return 0;
  for (final (r, c) in empty) {
    cells[r][c] = toMove;
    final score = -_negamax(cells, _other(toMove), depth + 1, -beta, -alpha);
    cells[r][c] = '';
    if (score > alpha) alpha = score;
    if (alpha >= beta) break;
  }
  return alpha;
}

// Expert on 8×8 (REQ-AI-05, 06): takes a win, blocks a win, then plays the
// cell with the best line score for both sides, so it blocks open threes
// before they become open fours and builds its own lines. One pass over the
// board, so it answers in milliseconds, well inside the 2-second limit.
// ponytail: scores unbroken runs only (misses split threats like X_XX);
// add a short threat search if Expert needs to be stronger.
(int, int) _expert(List<List<String>> cells, String me, int win) {
  final winNow = _winningMove(cells, me, win) ?? _winningMove(cells, _other(me), win);
  if (winNow != null) return winNow;
  final mid = (cells.length - 1) / 2;
  var best = double.negativeInfinity;
  late (int, int) bestMove;
  for (final (r, c) in _empty(cells)) {
    // Own lines count a little more than blocking, so it attacks on a tie;
    // the centre distance only breaks ties.
    final score = 1.1 * _lineScore(cells, r, c, me, win) +
        _lineScore(cells, r, c, _other(me), win) -
        ((r - mid).abs() + (c - mid).abs()) / 100;
    if (score > best) {
      best = score;
      bestMove = (r, c);
    }
  }
  return bestMove;
}

// How strong [mark]'s lines through the empty cell (r, c) would be.
double _lineScore(List<List<String>> cells, int r, int c, String mark, int win) {
  final n = cells.length;
  var total = 0.0;
  for (final (dr, dc) in const [(0, 1), (1, 0), (1, 1), (1, -1)]) {
    var run = 1, open = 0;
    for (final sign in const [1, -1]) {
      var k = 1;
      while (true) {
        final rr = r + sign * dr * k, cc = c + sign * dc * k;
        if (rr < 0 || rr >= n || cc < 0 || cc >= n) break;
        if (cells[rr][cc] == mark) {
          run++;
          k++;
          continue;
        }
        if (cells[rr][cc] == '') open++;
        break;
      }
    }
    final left = win - run; // stones still missing from a win
    if (open == 0 && left > 0) continue; // dead line
    total += switch (left) {
      <= 1 => open == 2 ? 50000.0 : 5000.0, // makes an open/closed four
      2 => open == 2 ? 2000.0 : 200.0, // open three (for 5) blocks/builds
      3 => open == 2 ? 100.0 : 10.0,
      _ => open.toDouble(),
    };
  }
  return total;
}

String _other(String mark) => mark == 'X' ? 'O' : 'X';

Map<String, Object>? _validate(
    Object? board, Object? winLength, Object? side, Object? difficulty) {
  if (board is! List || (board.length != 3 && board.length != 8)) {
    return _error('INVALID_BOARD', 'The board must have 3 or 8 rows.');
  }
  for (var r = 0; r < board.length; r++) {
    final row = board[r];
    if (row is! List || row.length != board.length) {
      return _error('INVALID_BOARD', 'Row $r has the wrong length.');
    }
    for (var c = 0; c < row.length; c++) {
      if (row[c] != 'X' && row[c] != 'O' && row[c] != '') {
        return _error('INVALID_CELL',
            'Cell ($r, $c) must be "X", "O" or "", not ${_show(row[c])}.');
      }
    }
  }
  final allowed = board.length == 3 ? const [3] : const [4, 5];
  if (!allowed.contains(winLength)) {
    return _error('INVALID_WIN_LENGTH',
        'Win length must be one of $allowed on a ${board.length}×${board.length} board.');
  }
  if (side != 'X' && side != 'O') {
    return _error('INVALID_SIDE', 'sideToMove must be "X" or "O".');
  }
  if (!difficulties.contains(difficulty)) {
    return _error('INVALID_DIFFICULTY',
        'difficulty must be one of ${difficulties.join(', ')}.');
  }
  final flat = [for (final row in board) ...row];
  final xs = flat.where((c) => c == 'X').length;
  final os = flat.where((c) => c == 'O').length;
  if ((xs - os).abs() > 1) {
    return _error('INVALID_BOARD', 'X and O counts differ by more than one.');
  }
  return null;
}

List<(int, int)> _empty(List<List<String>> cells) => [
      for (var r = 0; r < cells.length; r++)
        for (var c = 0; c < cells.length; c++)
          if (cells[r][c] == '') (r, c)
    ];

bool _hasLine(List<List<String>> cells, int winLength) {
  final n = cells.length;
  for (var r = 0; r < n; r++) {
    for (var c = 0; c < n; c++) {
      final mark = cells[r][c];
      if (mark == '') continue;
      for (final (dr, dc) in const [(0, 1), (1, 0), (1, 1), (1, -1)]) {
        var k = 1;
        while (k < winLength) {
          final rr = r + dr * k, cc = c + dc * k;
          if (rr < 0 || rr >= n || cc < 0 || cc >= n || cells[rr][cc] != mark) {
            break;
          }
          k++;
        }
        if (k == winLength) return true;
      }
    }
  }
  return false;
}

Map<String, Object> _error(String code, String message) =>
    {'error': code, 'message': message};

String _show(Object? v) => v is String ? '"$v"' : '$v';
