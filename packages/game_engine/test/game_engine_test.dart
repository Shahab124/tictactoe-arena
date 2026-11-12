import 'package:game_engine/game_engine.dart';
import 'package:test/test.dart';

/// Plays moves in order and checks each one is accepted.
Game playAll(Game game, List<(int, int)> moves) {
  for (final (r, c) in moves) {
    expect(game.play(r, c), MoveResult.ok, reason: 'move ($r, $c)');
  }
  return game;
}

void main() {
  group('setup', () {
    test('3×3 defaults to 3 in a row, 8×8 to 5', () {
      expect(Game().winLength, 3);
      expect(Game(size: 8).winLength, 5);
      expect(Game(size: 8, winLength: 4).winLength, 4);
    });

    test('rejects unsupported sizes and win lengths', () {
      expect(() => Game(size: 4), throwsArgumentError);
      expect(() => Game(size: 3, winLength: 4), throwsArgumentError);
      expect(() => Game(size: 8, winLength: 3), throwsArgumentError);
    });

    test('X moves first unless O is chosen', () {
      expect(Game().sideToMove, Mark.x);
      expect(Game(firstToMove: Mark.o).sideToMove, Mark.o);
    });
  });

  group('moves', () {
    test('a move places the mark and switches the side to move', () {
      final g = Game();
      expect(g.play(1, 1), MoveResult.ok);
      expect(g.at(1, 1), Mark.x);
      expect(g.sideToMove, Mark.o);
      expect(g.moves, [(1, 1)]);
    });

    test('a taken cell is refused and nothing changes', () {
      final g = playAll(Game(), [(0, 0)]);
      expect(g.play(0, 0), MoveResult.occupied);
      expect(g.at(0, 0), Mark.x);
      expect(g.sideToMove, Mark.o);
      expect(g.moves.length, 1);
    });

    test('an off-board cell is refused', () {
      final g = Game();
      for (final (r, c) in [(-1, 0), (0, -1), (3, 0), (0, 3)]) {
        expect(g.play(r, c), MoveResult.offBoard);
      }
      expect(g.moves, isEmpty);
    });

    test('a mark out of turn is refused', () {
      final g = Game();
      expect(g.play(0, 0, mark: Mark.o), MoveResult.wrongTurn);
      expect(g.at(0, 0), isNull);
      expect(g.play(0, 0, mark: Mark.x), MoveResult.ok);
    });

    test('no moves are accepted after the game is over', () {
      final g = playAll(Game(), [(0, 0), (1, 0), (0, 1), (1, 1), (0, 2)]);
      expect(g.status, GameStatus.xWon);
      expect(g.play(2, 2), MoveResult.gameOver);
      expect(g.at(2, 2), isNull);
      expect(g.moves.length, 5);
    });
  });

  group('wins on 3×3', () {
    test('row', () {
      final g = playAll(Game(), [(1, 0), (0, 0), (1, 1), (0, 1), (1, 2)]);
      expect(g.status, GameStatus.xWon);
      expect(g.winningCells, [(1, 0), (1, 1), (1, 2)]);
    });

    test('column', () {
      final g = playAll(Game(), [(0, 0), (0, 2), (1, 0), (1, 2), (2, 1), (2, 2)]);
      expect(g.status, GameStatus.oWon);
      expect(g.winningCells, [(0, 2), (1, 2), (2, 2)]);
    });

    test('diagonal', () {
      final g = playAll(Game(), [(0, 0), (0, 1), (1, 1), (0, 2), (2, 2)]);
      expect(g.status, GameStatus.xWon);
      expect(g.winningCells, [(0, 0), (1, 1), (2, 2)]);
    });

    test('anti-diagonal, completed in the middle', () {
      final g = playAll(Game(), [(0, 2), (0, 0), (2, 0), (0, 1), (1, 1)]);
      expect(g.status, GameStatus.xWon);
      expect(g.winningCells, [(0, 2), (1, 1), (2, 0)]);
    });

    test('the winner keeps the turn so the board shows who won', () {
      final g = playAll(Game(), [(0, 0), (1, 0), (0, 1), (1, 1), (0, 2)]);
      expect(g.sideToMove, Mark.x);
    });
  });

  group('8×8', () {
    test('five in a row wins by default', () {
      final g = Game(size: 8);
      for (var c = 0; c < 4; c++) {
        g.play(3, c);
        g.play(7, c);
      }
      expect(g.status, GameStatus.inProgress, reason: 'four is not enough');
      g.play(3, 4);
      expect(g.status, GameStatus.xWon);
      expect(g.winningCells, [for (var c = 0; c < 5; c++) (3, c)]);
    });

    test('four in a row wins when 4 is chosen', () {
      final g = Game(size: 8, winLength: 4);
      for (var r = 2; r < 5; r++) {
        g.play(r, r + 1);
        g.play(0, r);
      }
      g.play(5, 6);
      expect(g.status, GameStatus.xWon);
      expect(g.winningCells, [(2, 3), (3, 4), (4, 5), (5, 6)]);
    });

    test('a line longer than the win length still wins', () {
      final g = Game(size: 8);
      // X fills (0..2, 0) and (4..5, 0), then joins them at (3, 0) to make six.
      for (final r in [0, 1, 2, 4, 5]) {
        g.play(r, 0);
        g.play(r, 7);
      }
      g.play(3, 0);
      expect(g.status, GameStatus.xWon);
      expect(g.winningCells.length, 6);
    });
  });

  test('a full board with no line is a draw', () {
    // X O X
    // X O O
    // O X X
    final g = playAll(Game(), [
      (0, 0), (0, 1), (0, 2), (1, 1), (1, 0), (1, 2), (2, 1), (2, 0), (2, 2),
    ]);
    expect(g.status, GameStatus.draw);
    expect(g.winningCells, isEmpty);
    expect(g.play(0, 0), MoveResult.gameOver);
  });

  test('toBoard gives the AI request format', () {
    final g = playAll(Game(), [(0, 0), (1, 1)]);
    expect(g.toBoard(), [
      ['X', '', ''],
      ['', 'O', ''],
      ['', '', ''],
    ]);
  });
}
