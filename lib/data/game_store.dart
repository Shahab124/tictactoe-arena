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
    _games(uid).add(game.toMap()).ignore();
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
