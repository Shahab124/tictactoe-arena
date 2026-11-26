import 'dart:async';

import 'package:flutter/material.dart';
import 'package:game_engine/game_engine.dart';

import '../ui/mark.dart';
import 'admin_screen.dart';
import 'leaderboard_screen.dart';
import 'match_screen.dart';
import 'matchmaking.dart';
import 'moderation.dart';
import 'online_rooms.dart';
import 'ratings.dart';

/// Create a room, join one with a code, or rejoin an unfinished game.
class OnlineLobby extends StatefulWidget {
  const OnlineLobby(
      {super.key, required this.rooms, required this.ratings, required this.uid});

  final OnlineRooms rooms;
  final Ratings ratings;
  final String uid;

  @override
  State<OnlineLobby> createState() => _OnlineLobbyState();
}

class _OnlineLobbyState extends State<OnlineLobby> {
  final _code = TextEditingController();
  int _size = 3;
  String? _error;
  Room? _unfinished;
  Rating? _rating;
  late final _moderation = Moderation(widget.rooms.firestore);
  bool _suspended = false, _admin = false;

  @override
  void initState() {
    super.initState();
    widget.rooms.unfinished(widget.uid).then((room) {
      if (mounted) setState(() => _unfinished = room);
    });
    _loadRating();
    _moderation.isSuspended(widget.uid).then((s) {
      if (mounted) setState(() => _suspended = s);
    });
    _moderation.isAdmin(widget.uid).then((a) {
      if (mounted) setState(() => _admin = a);
    });
  }

  static const _suspendedText =
      'Your account is suspended, so you cannot play online.';

  void _loadRating() => widget.ratings.of(widget.uid).then((r) {
        if (mounted) setState(() => _rating = r);
      });

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _go(Future<String> Function() getCode) async {
    if (_suspended) return setState(() => _error = _suspendedText);
    try {
      final code = await getCode();
      if (!mounted) return;
      setState(() => _error = null);
      await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => RoomScreen(
              rooms: widget.rooms,
              ratings: widget.ratings,
              uid: widget.uid,
              code: code)));
      _loadRating();
      final room = await widget.rooms.unfinished(widget.uid);
      if (mounted) setState(() => _unfinished = room);
    } on RoomException catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Play online')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_rating != null)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.emoji_events_rounded, size: 32),
                      title: Text('Your rating: ${_rating!.rating}',
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text('${_rating!.games} ranked games'),
                      trailing: TextButton(
                        onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => LeaderboardScreen(
                                    ratings: widget.ratings, uid: widget.uid))),
                        child: const Text('Leaderboards'),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                if (_admin) ...[
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => AdminScreen(
                            moderation: _moderation, uid: widget.uid))),
                    icon: const Icon(Icons.admin_panel_settings_rounded),
                    label: const Text('Admin dashboard'),
                  ),
                  const SizedBox(height: 16),
                ],
                if (_suspended) ...[
                  Card(
                    color: Theme.of(context).colorScheme.errorContainer,
                    child: const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(_suspendedText),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (_unfinished != null) ...[
                  FilledButton.tonalIcon(
                    onPressed: () => _go(() async => _unfinished!.code),
                    icon: const Icon(Icons.replay_rounded),
                    label: Text('Rejoin game ${_unfinished!.code}'),
                  ),
                  const SizedBox(height: 24),
                ],
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 3, label: Text('3×3')),
                    ButtonSegment(value: 8, label: Text('8×8')),
                  ],
                  selected: {_size},
                  onSelectionChanged: (s) => setState(() => _size = s.first),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () async {
                    if (_suspended) {
                      return setState(() => _error = _suspendedText);
                    }
                    await Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => MatchScreen(
                            matchmaker: Matchmaker(
                                widget.rooms.firestore, widget.ratings),
                            rooms: widget.rooms,
                            ratings: widget.ratings,
                            uid: widget.uid,
                            size: _size)));
                    _loadRating();
                  },
                  icon: const Icon(Icons.bolt_rounded),
                  label: const Text('Find a match'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () =>
                      _go(() => widget.rooms.create(widget.uid, size: _size)),
                  child: const Text('Create room'),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _code,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                      labelText: 'Room code', errorText: _error),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => _go(() async {
                    final code = _code.text.trim().toUpperCase();
                    await widget.rooms.join(code, widget.uid);
                    return code;
                  }),
                  child: const Text('Join room'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One online game, kept up to date as either player moves.
class RoomScreen extends StatefulWidget {
  const RoomScreen({
    super.key,
    required this.rooms,
    required this.ratings,
    required this.uid,
    required this.code,
  });

  final OnlineRooms rooms;
  final Ratings ratings;
  final String uid, code;

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  late final Stream<Room?> _room = widget.rooms.watch(widget.code);
  // Ticks once a second so the turn clock counts down.
  late final Timer _tick;
  bool _rated = false;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  String _status(Room room, Mark me) {
    if (room.status == 'waiting') return 'Waiting for a player. Share the code.';
    if (room.status == 'over') {
      final why = switch (room.reason) {
        'left' => ' (a player left)',
        'timeout' => ' (out of time)',
        _ => '',
      };
      if (room.winner == 'draw') return 'Draw';
      return (room.winner == me.symbol ? 'You win' : 'You lose') + why;
    }
    final left = room.lastMoveAt == null
        ? turnLimit.inSeconds
        : (turnLimit - DateTime.now().difference(room.lastMoveAt!))
            .inSeconds
            .clamp(0, turnLimit.inSeconds);
    return room.turn == me ? 'Your turn · ${left}s' : 'Their turn · ${left}s';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Room?>(
      stream: _room,
      builder: (context, snap) {
        final room = snap.data;
        final me = room?.markOf(widget.uid);
        if (room == null || me == null) {
          return Scaffold(
              appBar: AppBar(),
              body: const Center(child: CircularProgressIndicator()));
        }
        final game = room.toGame();
        final playing = room.status == 'playing';
        // Every online game is ranked; counted once when it ends (REQ-RANK-01).
        if (room.status == 'over' && !_rated) {
          _rated = true;
          widget.ratings.record(room, widget.uid).ignore();
        }
        return Scaffold(
          appBar: AppBar(
            title: Text('Room ${room.code}'),
            actions: [
              if (playing)
                TextButton(
                  onPressed: () async {
                    await widget.rooms.leave(room, widget.uid);
                    if (context.mounted) Navigator.of(context).pop();
                  },
                  child: const Text('Leave (you lose)'),
                ),
            ],
          ),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('You are ${me.symbol}'),
                  const SizedBox(height: 8),
                  Text(_status(room, me),
                      style: Theme.of(context).textTheme.titleLarge),
                  if (room.status == 'waiting')
                    SelectableText(room.code,
                        style: Theme.of(context).textTheme.displayMedium),
                  if (playing &&
                      room.turn != me &&
                      room.timedOut(DateTime.now()))
                    FilledButton(
                      onPressed: () =>
                          widget.rooms.claimTimeout(room, widget.uid),
                      child: const Text('Claim win'),
                    ),
                  if (room.status == 'over' && room.o != null)
                    _ReportBlock(
                      uid: widget.uid,
                      other: me == Mark.x ? room.o! : room.x,
                      room: room.code,
                      moderation: Moderation(widget.rooms.firestore),
                    ),
                  const SizedBox(height: 16),
                  Flexible(
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: GridView.count(
                        crossAxisCount: room.size,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 4,
                        crossAxisSpacing: 4,
                        children: [
                          for (var i = 0; i < room.size * room.size; i++)
                            _cell(context, room, game, i),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _cell(BuildContext context, Room room, Game game, int i) {
    final (row, col) = (i ~/ room.size, i % room.size);
    final mark = game.at(row, col);
    return Semantics(
      button: true,
      label: 'Row ${row + 1}, column ${col + 1}, ${mark?.symbol ?? 'empty'}',
      excludeSemantics: true,
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () => widget.rooms.move(room, widget.uid, row, col),
          child: mark == null ? null : MarkView(mark: mark),
        ),
      ),
    );
  }
}

/// Report or block the other player after an online game (REQ-ONL-08).
class _ReportBlock extends StatefulWidget {
  const _ReportBlock({
    required this.uid,
    required this.other,
    required this.room,
    required this.moderation,
  });

  final String uid, other, room;
  final Moderation moderation;

  @override
  State<_ReportBlock> createState() => _ReportBlockState();
}

class _ReportBlockState extends State<_ReportBlock> {
  String? _done;

  Future<void> _report() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) {
        final text = TextEditingController();
        return AlertDialog(
          title: const Text('Report player'),
          content: TextField(
            controller: text,
            decoration: const InputDecoration(labelText: 'What happened? (optional)'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(context, text.text.trim()),
                child: const Text('Report')),
          ],
        );
      },
    );
    if (reason == null) return;
    await widget.moderation.report(widget.uid, widget.other, room: widget.room, reason: reason);
    if (mounted) setState(() => _done = 'Reported. An admin will review it.');
  }

  Future<void> _block() async {
    await widget.moderation.block(widget.uid, widget.other);
    if (mounted) setState(() => _done = 'Blocked. You won\'t be matched with them again.');
  }

  @override
  Widget build(BuildContext context) {
    if (_done != null) return Padding(padding: const EdgeInsets.only(top: 8), child: Text(_done!));
    return Wrap(spacing: 8, children: [
      TextButton.icon(
          onPressed: _report, icon: const Icon(Icons.flag_outlined), label: const Text('Report')),
      TextButton.icon(
          onPressed: _block, icon: const Icon(Icons.block), label: const Text('Block')),
    ]);
  }
}