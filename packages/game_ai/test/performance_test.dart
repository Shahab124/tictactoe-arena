import 'package:game_ai/game_ai.dart';
import 'package:test/test.dart';

void main() {
  final scenarios = [
    (
      name: 'empty 3x3',
      board: _emptyBoard(3),
      winLength: 3,
      limit: const Duration(seconds: 1),
    ),
    (
      name: 'empty 8x8',
      board: _emptyBoard(8),
      winLength: 5,
      limit: const Duration(seconds: 2),
    ),
    (
      name: 'crowded 8x8 with open threes and fours',
      board: _crowdedBoard(),
      winLength: 5,
      limit: const Duration(seconds: 2),
    ),
  ];

  test('requestMove meets its response-time limits on worst-case boards', () {
    for (final difficulty in difficulties) {
      for (final scenario in scenarios) {
        final request = <String, Object>{
          'board': scenario.board,
          'winLength': scenario.winLength,
          'sideToMove': 'X',
          'difficulty': difficulty,
        };

        // Keep one-time runtime setup out of the measured response time.
        requestMove(request);
        for (var sample = 0; sample < 3; sample++) {
          final stopwatch = Stopwatch()..start();
          final result = requestMove(request);
          stopwatch.stop();
          final elapsed = stopwatch.elapsed;

          expect(
            result.keys,
            containsAll(['row', 'col']),
            reason: '$difficulty on ${scenario.name} returned $result',
          );
          expect(
            elapsed,
            lessThanOrEqualTo(scenario.limit),
            reason:
                '$difficulty on ${scenario.name} took $elapsed; limit is ${scenario.limit}',
          );
        }
      }
    }
  });
}

List<List<String>> _emptyBoard(int size) =>
    List.generate(size, (_) => List.filled(size, ''));

List<List<String>> _crowdedBoard() {
  final board = _emptyBoard(8);

  for (var col = 1; col <= 4; col++) {
    board[0][col] = 'X';
  }
  for (var col = 2; col <= 5; col++) {
    board[2][col] = 'O';
  }
  for (var col = 2; col <= 4; col++) {
    board[4][col] = 'X';
    board[6][col] = 'O';
  }

  return board;
}
