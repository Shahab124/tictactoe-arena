// The example calls from the README. Run with: dart run example/main.dart
import 'dart:convert';

import 'package:game_ai/game_ai.dart';

void main() {
  final empty8 = [for (var r = 0; r < 8; r++) List.filled(8, '')];
  final requests = <Map<String, dynamic>>[
    // 3×3, Hard: O must block X's top row.
    {
      'board': [
        ['X', 'X', ''],
        ['', 'O', ''],
        ['', '', ''],
      ],
      'winLength': 3,
      'sideToMove': 'O',
      'difficulty': 'hard',
    },
    // 8×8, five in a row, Expert, empty board.
    {'board': empty8, 'winLength': 5, 'sideToMove': 'X', 'difficulty': 'expert'},
    // One request for every error code.
    {'board': [<String>[]], 'winLength': 3, 'sideToMove': 'X'},
    {
      'board': [
        ['X', 'Z', ''],
        ['', '', ''],
        ['', '', ''],
      ],
      'winLength': 3,
      'sideToMove': 'O',
    },
    {'board': empty8, 'winLength': 3, 'sideToMove': 'X'},
    {'board': empty8, 'winLength': 5, 'sideToMove': 'A'},
    {'board': empty8, 'winLength': 5, 'sideToMove': 'X', 'difficulty': 'god'},
    {
      'board': [
        ['X', 'X', 'X'],
        ['O', 'O', ''],
        ['', '', ''],
      ],
      'winLength': 3,
      'sideToMove': 'O',
    },
  ];
  for (final request in requests) {
    print(jsonEncode(requestMove(request)));
  }
}
