import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'game_record.dart';

/// Saves and loads finished games (the Data Manager in D3 section 3.4).
///
/// Signed-in players' games go to Firestore at `users/<uid>/games`. Firestore
/// keeps a local copy and uploads it after reconnecting, so a game finished
/// offline is not lost (D3 REQ-DATA 1.1 exception 1, section 5.5).
/// Guests' games stay on the device only (D3 REQ-DATA 1.1b).
class GameStore {
  GameStore({required this.firestore, required this.prefs});

  final FirebaseFirestore firestore;
  final SharedPreferences prefs;

  static const _guestKey = 'guest_games';

  CollectionReference<Map<String, dynamic>> _games(String uid) =>
      firestore.collection('users').doc(uid).collection('games');

  /// Saves [game] for [uid], or on the device when [uid] is null (guest).
  ///
  /// Doesn't wait for the server, so the result screen isn't held up
  /// (D3 REQ-DATA 1.1a step 4); Firestore syncs in the background.
  Future<void> save(GameRecord game, {String? uid}) async {
    if (uid == null) {
      final saved = prefs.getStringList(_guestKey) ?? [];
      await prefs.setStringList(
          _guestKey, [...saved, jsonEncode(game.toMap())]);
      return;
    }
    _games(uid).doc(_id(game)).set(game.toMap()).ignore();
  }

  // The same game always gets the same id, so an upload that is retried after
  // reconnecting, or guest games moved twice, can't make duplicates
  // (REQ-DATA-05).
  // ponytail: two different games only clash if they end in the same
  // microsecond with the same result and move count.
  static String _id(GameRecord game) =>
      '${game.playedAt.toUtc().microsecondsSinceEpoch}'
      '-${game.result}-${game.moves.length}';

  DocumentReference<Map<String, dynamic>> _state(String uid, String name) =>
      firestore.collection('users').doc(uid).collection('state').doc(name);

  Future<Map<String, dynamic>?> _read(String name, String? uid) async {
    if (uid == null) {
      final s = prefs.getString(name);
      return s == null ? null : jsonDecode(s) as Map<String, dynamic>;
    }
    return (await _state(uid, name).get()).data();
  }

  Future<void> _write(String name, Map<String, dynamic>? data, String? uid) {
    if (uid == null) {
      return data == null
          ? prefs.remove(name)
          : prefs.setString(name, jsonEncode(data));
    }
    // Not awaited, like [save]: Firestore uploads it once back online.
    final doc = _state(uid, name);
    (data == null ? doc.delete() : doc.set(data)).ignore();
    return Future.value();
  }

  /// The player's last game setup choices, kept in their account so they
  /// follow them to a new device (REQ-DATA-04).
  Future<Map<String, dynamic>?> loadSettings({String? uid}) =>
      _read('settings', uid);

  Future<void> saveSettings(Map<String, dynamic> settings, {String? uid}) =>
      _write('settings', settings, uid);

  /// The unfinished game, so it can be continued after closing the app or on
  /// another device (REQ-DATA-06). Null clears it.
  Future<Map<String, dynamic>?> loadCurrent({String? uid}) =>
      _read('current', uid);

  Future<void> saveCurrent(Map<String, dynamic>? game, {String? uid}) =>
      _write('current', game, uid);

  /// Moves games played as a guest on this device into [uid]'s account, so a
  /// guest who signs up keeps their history (REQ-ACC-03).
  Future<void> moveGuestGames(String uid) async {
    final saved = prefs.getStringList(_guestKey) ?? [];
    if (saved.isEmpty) return;
    final batch = firestore.batch();
    for (final s in saved) {
      final game = jsonDecode(s) as Map<String, dynamic>;
      batch.set(_games(uid).doc(_id(GameRecord.fromMap(game))), game);
    }
    await prefs.remove(_guestKey);
    batch.commit().ignore(); // Synced in the background, like [save].
  }

  /// Deletes every saved game of [uid] (REQ-ACC-07).
  Future<void> deleteAll(String uid) async {
    // ponytail: one batch holds 500 writes; chunk it if players pass 500 games.
    final batch = firestore.batch();
    for (final doc in (await _games(uid).get()).docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_state(uid, 'settings'));
    batch.delete(_state(uid, 'current'));
    await batch.commit();
  }

  /// All saved games, newest first.
  Future<List<GameRecord>> history({String? uid}) async {
    final games = uid == null
        ? [
            for (final s in prefs.getStringList(_guestKey) ?? <String>[])
              GameRecord.fromMap(jsonDecode(s) as Map<String, dynamic>)
          ]
        : [
            for (final doc in (await _games(uid).get()).docs)
              GameRecord.fromMap(doc.data())
          ];
    return games..sort((a, b) => b.playedAt.compareTo(a.playedAt));
  }
}
