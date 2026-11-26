import 'dart:async';

import 'package:flutter/material.dart';

import 'matchmaking.dart';
import 'online_rooms.dart';
import 'online_screen.dart';
import 'ratings.dart';

/// "Find a match": waits for a player of similar rating, then opens the game
/// (REQ-ONL-01). Cancel or going back leaves the queue.
class MatchScreen extends StatefulWidget {
  const MatchScreen({
    super.key,
    required this.matchmaker,
    required this.rooms,
    required this.ratings,
    required this.uid,
    this.size = 3,
  });

  final Matchmaker matchmaker;
  final OnlineRooms rooms;
  final Ratings ratings;
  final String uid;
  final int size;

  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen> {
  StreamSubscription<String?>? _sub;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _search();
  }

  Future<void> _search() async {
    final code = await widget.matchmaker.findOrWait(widget.uid, size: widget.size);
    if (code != null) return _open(code);
    _sub = widget.matchmaker.matched(widget.uid).listen((code) async {
      if (code == null || _done) return;
      await widget.rooms.join(code, widget.uid);
      await widget.matchmaker.leave(widget.uid);
      _open(code);
    });
  }

  void _open(String code) {
    if (_done || !mounted) return;
    _done = true;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => RoomScreen(
            rooms: widget.rooms,
            ratings: widget.ratings,
            uid: widget.uid,
            code: code)));
  }

  @override
  void dispose() {
    _sub?.cancel();
    if (!_done) widget.matchmaker.leave(widget.uid).ignore();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Find a match')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            Text('Looking for a player near your rating…',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text('The range widens the longer you wait.'),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}
