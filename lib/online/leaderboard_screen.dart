import 'package:flutter/material.dart';

import 'ratings.dart';

/// Global and weekly leaderboards (REQ-RANK-02). There is no friends list
/// yet, so there is no friends leaderboard.
class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({
    super.key,
    required this.ratings,
    required this.uid,
  });

  final Ratings ratings;
  final String uid;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Leaderboards'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'All time'),
              Tab(text: 'This week'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _Board(load: ratings.global, uid: uid, value: (r) => '${r.rating}'),
            _Board(
              load: () => ratings.weekly(uid: uid),
              uid: uid,
              value: (r) => '${r.weekPoints} pts',
            ),
          ],
        ),
      ),
    );
  }
}

class _Board extends StatelessWidget {
  const _Board({required this.load, required this.uid, required this.value});

  final Future<List<Rating>> Function() load;
  final String uid;
  final String Function(Rating) value;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Rating>>(
      future: load(),
      builder: (context, snap) {
        if (snap.hasError) {
          return const Center(child: Text('Could not load the leaderboard.'));
        }
        final rows = snap.data;
        if (rows == null)
          return const Center(child: CircularProgressIndicator());
        if (rows.isEmpty) {
          return const Center(
            child: Text(
              'No ranked games yet. Play online to get on the board.',
            ),
          );
        }
        return ListView(
          children: [
            for (var i = 0; i < rows.length; i++)
              ListTile(
                selected: rows[i].uid == uid,
                leading: CircleAvatar(child: Text('${i + 1}')),
                title: Text(
                  rows[i].uid == uid ? '${rows[i].name} (you)' : rows[i].name,
                ),
                subtitle: Text('${rows[i].games} games'),
                trailing: Text(
                  value(rows[i]),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
