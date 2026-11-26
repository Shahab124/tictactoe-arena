import 'dart:math';

import 'package:game_ai/game_ai.dart';
import 'package:test/test.dart';

void main() {
  test('3×3: a missed block is the worst move and the win is the best', () {
    // X takes the top row because O played (2,2) instead of blocking (0,2).
    final r = bestAndWorstMoves([(0, 0), (1, 1), (0, 1), (2, 2), (0, 2)],
        size: 3, winLength: 3);
    expect(r.worst, 3);
    expect(r.best, 4);
  });
    // X takes the top row because O played (2,2) instead of blocking (0,2).

  test('3×3: a game of perfect moves has no worst move', () {
    final board = List.generate(3, (_) => List.filled(3, ''));
    final moves = <(int, int)>[];
    for (var i = 0; i < 9; i++) {
      final side = i.isEven ? 'X' : 'O';
      final m = requestMove({
        'board': board,
        'winLength': 3,
        'sideToMove': side,
        'difficulty': 'hard',
      });
      if (m.containsKey('error')) break;
      final (row, col) = (m['row'] as int, m['col'] as int);
      board[row][col] = side;
      moves.add((row, col));
    }
    expect(bestAndWorstMoves(moves, size: 3, winLength: 3).worst, isNull);
  });

  test('8×8: leaving four in a row open is the worst move', () {
    final r = bestAndWorstMoves([
      (0, 0), (7, 7), (0, 1), (7, 6), (0, 2), (7, 5), (0, 3), (5, 5), (0, 4),
    ], size: 8, winLength: 5);
    expect(r.worst, 7);
    expect(r.best, 8);
  });

  test('8×8: rating a long game is quick', () {
    final cells = [for (var r = 0; r < 8; r++) for (var c = 0; c < 8; c++) (r, c)]
      ..shuffle(Random(1));
    final watch = Stopwatch()..start();
    bestAndWorstMoves(cells.take(60).toList(), size: 8, winLength: 5);
    expect(watch.elapsed, lessThan(const Duration(seconds: 2)));
  });
}
