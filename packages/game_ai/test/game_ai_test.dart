import 'dart:math';

import 'package:game_ai/game_ai.dart';
import 'package:test/test.dart';

List<List<String>> empty(int n) => List.generate(n, (_) => List.filled(n, ''));

Map<String, dynamic> req(List<List<String>> board,
        {Object? winLength, Object side = 'X', Object? difficulty = 'easy'}) =>
    {
      'board': board,
      'winLength': winLength ?? (board.length == 3 ? 3 : 5),
      'sideToMove': side,
      if (difficulty != null) 'difficulty': difficulty,
    };

void main() {
  group('easy', () {
    test('always returns an empty cell (many random games)', () {
      final random = Random(1);
      for (var i = 0; i < 200; i++) {
        final board = [
          ['X', 'O', ''],
          ['', 'X', 'O'],
          ['O', '', ''],
        ];
        final move = requestMove(req(board, side: 'X'), random: random);
        expect(board[move['row'] as int][move['col'] as int], '',
            reason: '$move');
      }
    });

    test('returns the only empty cell', () {
      final board = [
        ['X', 'O', 'X'],
        ['X', 'O', 'O'],
        ['O', 'X', ''],
      ];
      expect(requestMove(req(board)), {'row': 2, 'col': 2});
    });

    test('works on 8×8 and does not change the input board', () {
      final board = empty(8);
      board[3][3] = 'X';
      final before = board.toString();
      final move = requestMove(req(board, side: 'O'));
      expect(move.keys, containsAll(['row', 'col']));
      expect(board.toString(), before);
    });

    test('plays different moves, so it is beatable', () {
      final random = Random(7);
      final moves = {
        for (var i = 0; i < 50; i++) requestMove(req(empty(3)), random: random).toString()
      };
      expect(moves.length, greaterThan(3));
    });
  });

  group('errors (REQ-INT-04.1)', () {
    void expectError(Map<String, dynamic> request, String code) {
      final result = requestMove(request);
      expect(result['error'], code, reason: '$result');
      expect(result['message'], isA<String>());
      expect(result.containsKey('row'), isFalse);
    }

    test('wrong board size', () {
      expectError(req(empty(4)), 'INVALID_BOARD');
      expectError({'board': 'nope', 'winLength': 3, 'sideToMove': 'X'},
          'INVALID_BOARD');
    });

    test('a row of the wrong length names the row', () {
      final board = empty(3)..[2] = ['', ''];
      final result = requestMove(req(board));
      expect(result, {'error': 'INVALID_BOARD', 'message': 'Row 2 has the wrong length.'});
    });

    test('bad cell value', () {
      expectError(req(empty(3)..[1][1] = 'Z'), 'INVALID_CELL');
    });

    test('bad win length', () {
      expectError(req(empty(3), winLength: 5), 'INVALID_WIN_LENGTH');
      expectError(req(empty(8), winLength: 3), 'INVALID_WIN_LENGTH');
    });

    test('bad side', () {
      expectError(req(empty(3), side: 'Y'), 'INVALID_SIDE');
    });

    test('unknown difficulty', () {
      expectError(req(empty(3), difficulty: 'insane'), 'INVALID_DIFFICULTY');
    });

    test('impossible mark counts', () {
      expectError(
          req([
            ['X', 'X', ''],
            ['', '', ''],
            ['', '', ''],
          ]),
          'INVALID_BOARD');
    });

    test('game already won', () {
      expectError(
          req([
            ['X', 'X', 'X'],
            ['O', 'O', ''],
            ['', '', ''],
          ], side: 'O'),
          'GAME_OVER');
    });

    test('board full', () {
      expectError(
          req([
            ['X', 'O', 'X'],
            ['X', 'O', 'O'],
            ['O', 'X', 'X'],
          ], side: 'O'),
          'GAME_OVER');
    });

  });

  for (final level in ['medium', 'hard', 'expert']) {
    group(level, () {
      test('takes a winning move', () {
        final board = [
          ['O', 'O', ''],
          ['X', 'X', ''],
          ['X', '', ''],
        ];
        expect(requestMove(req(board, side: 'O', difficulty: level)),
            {'row': 0, 'col': 2});
      });

      test("blocks the opponent's winning move", () {
        final board = [
          ['X', 'X', ''],
          ['', 'O', ''],
          ['', '', ''],
        ];
        expect(requestMove(req(board, side: 'O', difficulty: level)),
            {'row': 0, 'col': 2});
      });
    });
  }

  test('medium takes a win and blocks on 8×8 too', () {
    final board = empty(8);
    for (var c = 0; c < 4; c++) {
      board[2][c] = 'X';
    }
    for (var c = 0; c < 3; c++) {
      board[6][c] = 'O';
    }
    board[7][7] = 'O';
    expect(requestMove(req(board, side: 'O', difficulty: 'medium')),
        {'row': 2, 'col': 4}, reason: 'must block X\'s five');

    // With 4 in a row, O's win comes before blocking X's three.
    board[2][3] = '';
    board[0][7] = 'X';
    expect(requestMove(req(board, winLength: 4, side: 'O', difficulty: 'medium')),
        {'row': 6, 'col': 3}, reason: 'O wins with four');
  });

  test('medium makes mistakes that hard does not', () {
    // After X takes a corner, only the centre saves O.
    final board = empty(3)..[0][0] = 'X';
    final random = Random(3);
    final medium = {
      for (var i = 0; i < 30; i++)
        requestMove(req(board, side: 'O', difficulty: 'medium'), random: random)
            .toString()
    };
    expect(medium.length, greaterThan(1));
    expect(requestMove(req(board, side: 'O', difficulty: 'hard')),
        {'row': 1, 'col': 1});
  });

  test('no difficulty means medium', () {
    final board = [
      ['X', 'X', ''],
      ['', 'O', ''],
      ['', '', ''],
    ];
    expect(requestMove(req(board, side: 'O', difficulty: null)),
        {'row': 0, 'col': 2});
  });

  group('expert on 8×8', () {
    Map<String, Object> expert(List<List<String>> b, String side, {int win = 5}) =>
        requestMove(req(b, winLength: win, side: side, difficulty: 'expert'));

    test('stops an open three before it becomes an open four', () {
      final board = empty(8);
      for (var c = 2; c <= 4; c++) {
        board[3][c] = 'O';
      }
      board[7][0] = 'X';
      board[7][7] = 'X';
      expect(expert(board, 'X').toString(),
          anyOf('{row: 3, col: 1}', '{row: 3, col: 5}'));
    });

    test('with 4 in a row, blocks an open two before it becomes an open three', () {
      final board = empty(8);
      board[4][3] = 'O';
      board[4][4] = 'O';
      board[0][0] = 'X';
      expect(expert(board, 'X', win: 4).toString(),
          anyOf('{row: 4, col: 2}', '{row: 4, col: 5}'));
    });

    test('builds its own open three into an open four', () {
      final board = empty(8);
      for (var r = 2; r <= 4; r++) {
        board[r][5] = 'X';
      }
      board[0][0] = 'O';
      board[7][1] = 'O';
      expect(expert(board, 'X').toString(),
          anyOf('{row: 1, col: 5}', '{row: 5, col: 5}'));
    });

    test('takes its own win before blocking', () {
      final board = empty(8);
      for (var c = 0; c < 4; c++) {
        board[1][c] = 'O';
        board[6][c] = 'X';
      }
      expect(expert(board, 'X'), {'row': 6, 'col': 4});
    });

    for (final win in [4, 5]) {
      test('never loses to Easy, each move well under 2 s ($win in a row)', () {
        final random = Random(win);
        var slowest = Duration.zero, wins = 0;
        for (var game = 0; game < 20; game++) {
          final board = empty(8);
          final expertSide = game.isEven ? 'X' : 'O';
          var turn = 'X';
          while (true) {
            final watch = Stopwatch()..start();
            final move = requestMove(
                req(board,
                    winLength: win,
                    side: turn,
                    difficulty: turn == expertSide ? 'expert' : 'easy'),
                random: random);
            if (turn == expertSide && watch.elapsed > slowest) {
              slowest = watch.elapsed;
            }
            if (move['error'] == 'GAME_OVER') break;
            board[move['row'] as int][move['col'] as int] = turn;
            turn = turn == 'X' ? 'O' : 'X';
          }
          // Game over with empty cells left means the side that just moved won.
          // ponytail: a full board is counted as neither (rare against Easy).
          if (board.any((row) => row.contains(''))) {
            final last = turn == 'X' ? 'O' : 'X';
            expect(last, expertSide, reason: 'Expert lost game $game: $board');
            wins++;
          }
        }
        expect(wins, greaterThan(15), reason: 'Expert won $wins/20');
        expect(slowest, lessThan(const Duration(seconds: 2)));
      });
    }
  });

  group('hard never loses on 3×3', () {
    // Plays Hard against every possible sequence of opponent moves.
    var games = 0;
    void explore(List<List<String>> board, String turn, String hard) {
      final result = requestMove(req(board, side: turn, difficulty: 'hard'));
      if (result['error'] == 'GAME_OVER') {
        games++;
        expect(_winner(board), isNot(hard == 'X' ? 'O' : 'X'),
            reason: 'Hard lost: $board');
        return;
      }
      final next = turn == 'X' ? 'O' : 'X';
      if (turn == hard) {
        board[result['row'] as int][result['col'] as int] = turn;
        explore(board, next, hard);
        board[result['row'] as int][result['col'] as int] = '';
      } else {
        for (var r = 0; r < 3; r++) {
          for (var c = 0; c < 3; c++) {
            if (board[r][c] != '') continue;
            board[r][c] = turn;
            explore(board, next, hard);
            board[r][c] = '';
          }
        }
      }
    }

    test('playing X', () {
      games = 0;
      explore(empty(3), 'X', 'X');
      expect(games, greaterThan(0));
    });

    test('playing O', () {
      games = 0;
      explore(empty(3), 'X', 'O');
      expect(games, greaterThan(100));
    });
  });
}

String? _winner(List<List<String>> b) {
  const lines = [
    [(0, 0), (0, 1), (0, 2)], [(1, 0), (1, 1), (1, 2)], [(2, 0), (2, 1), (2, 2)],
    [(0, 0), (1, 0), (2, 0)], [(0, 1), (1, 1), (2, 1)], [(0, 2), (1, 2), (2, 2)],
    [(0, 0), (1, 1), (2, 2)], [(0, 2), (1, 1), (2, 0)],
  ];
  for (final line in lines) {
    final (r, c) = line[0];
    final m = b[r][c];
    if (m != '' && line.every((p) => b[p.$1][p.$2] == m)) return m;
  }
  return null;
}
