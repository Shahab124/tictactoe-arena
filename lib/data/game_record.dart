/// A finished game, as saved to history (D3 section 2.4, REQ-DATA-01).
///
/// [result] is from the saving player's side: 'win', 'loss' or 'draw'.
class GameRecord {
  const GameRecord({
    required this.boardSize,
    required this.winLength,
    required this.mode,
    required this.opponent,
    required this.moves,
    required this.result,
    required this.playedAt,
  });

  final int boardSize;
  final int winLength;

  /// 'computer', 'local' or 'online'.
  final String mode;

  /// Shown in history, e.g. 'Computer (Hard)' or 'Local player'.
  final String opponent;

  /// Moves in order as (row, col).
  final List<(int, int)> moves;
  final String result;
  final DateTime playedAt;

  // Firestore can't store nested lists, so each move is a {r, c} map.
  Map<String, dynamic> toMap() => {
        'boardSize': boardSize,
        'winLength': winLength,
        'mode': mode,
        'opponent': opponent,
        'moves': [for (final (r, c) in moves) {'r': r, 'c': c}],
        'result': result,
        'playedAt': playedAt.toUtc().toIso8601String(),
      };

  factory GameRecord.fromMap(Map<String, dynamic> m) => GameRecord(
        boardSize: m['boardSize'] as int,
        winLength: m['winLength'] as int,
        mode: m['mode'] as String,
        opponent: m['opponent'] as String,
        moves: [
          for (final move in m['moves'] as List)
            ((move as Map)['r'] as int, move['c'] as int)
        ],
        result: m['result'] as String,
        playedAt: DateTime.parse(m['playedAt'] as String),
      );
}

/// Games played, wins, losses, draws and win rate for one board size and mode
/// (REQ-DATA-03).
class Stats {
  int played = 0, wins = 0, losses = 0, draws = 0;

  double get winRate => played == 0 ? 0 : wins / played;

  /// Groups games by board size and mode, e.g. '3×3 computer'.
  // ponytail: computed from the full history on each read; store running
  // totals in Firestore if players reach thousands of games.
  static Map<String, Stats> byBoardAndMode(List<GameRecord> games) {
    final stats = <String, Stats>{};
    for (final g in games) {
      final s = stats.putIfAbsent(
          '${g.boardSize}×${g.boardSize} ${g.mode}', Stats.new);
      s.played++;
      switch (g.result) {
        case 'win':
          s.wins++;
        case 'loss':
          s.losses++;
        default:
          s.draws++;
      }
    }
    return stats;
  }
}
