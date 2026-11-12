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

    test('levels not built yet say so instead of crashing', () {
      expectError(req(empty(3), difficulty: 'hard'), 'UNSUPPORTED_DIFFICULTY');
    });
  });
}
