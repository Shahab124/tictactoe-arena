import 'package:flutter/material.dart';

import 'game_record.dart';
import 'game_store.dart';

/// Match history and statistics (REQ-DATA-02 and 03).
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key, required this.store, this.uid});

  final GameStore store;

  /// Null for a guest.
  final String? uid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('History & statistics')),
      body: FutureBuilder<List<GameRecord>>(
        future: store.history(uid: uid),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Could not load your games.'));
          }
          final games = snapshot.data;
          if (games == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (games.isEmpty) {
            return const Center(child: Text('No games played yet.'));
          }
          final stats = Stats.byBoardAndMode(games);
          return ListView(
            children: [
              for (final MapEntry(key: group, value: s) in stats.entries)
                ListTile(
                  title: Text(group),
                  subtitle: Text('${s.played} played · ${s.wins} won · '
                      '${s.losses} lost · ${s.draws} drawn · '
                      '${(s.winRate * 100).round()}% win rate'),
                ),
              const Divider(),
              for (final g in games)
                ListTile(
                  leading: Text(g.result.toUpperCase()),
                  title: Text('vs ${g.opponent}'),
                  subtitle: Text('${g.boardSize}×${g.boardSize}, '
                      '${g.winLength} in a row · '
                      '${MaterialLocalizations.of(context).formatMediumDate(g.playedAt.toLocal())}'),
                ),
            ],
          );
        },
      ),
    );
  }
}
