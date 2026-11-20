import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/game_store.dart';
import 'sign_in_screen.dart';

/// Avatars a player can pick from (REQ-ACC-05).
const avatars = ['🦊', '🐼', '🐯', '🐸', '🐙', '🦄', '🐧', '🐲'];

/// Thrown when a username is taken or not allowed.
class UsernameException implements Exception {
  const UsernameException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Username and avatar, stored at `users/<uid>` (REQ-ACC-05).
///
/// Usernames are unique: each one owns a `usernames/<lowercase name>` doc, and
/// the database rules refuse to create one that already exists.
class Profiles {
  Profiles(this.firestore);

  final FirebaseFirestore firestore;

  static final _valid = RegExp(r'^[a-zA-Z0-9_]{3,15}$');

  DocumentReference<Map<String, dynamic>> _user(String uid) =>
      firestore.collection('users').doc(uid);
  DocumentReference<Map<String, dynamic>> _name(String name) =>
      firestore.collection('usernames').doc(name.toLowerCase());

  Future<Map<String, dynamic>> load(String uid) async =>
      (await _user(uid).get()).data() ?? {};

  /// Gives [uid] the username [name], freeing their old one.
  Future<void> setUsername(String uid, String name) async {
    if (!_valid.hasMatch(name)) {
      throw const UsernameException(
          'Use 3 to 15 letters, numbers or underscores.');
    }
    await firestore.runTransaction((t) async {
      final taken = await t.get(_name(name));
      if (taken.exists && taken.data()!['uid'] != uid) {
        throw const UsernameException('That username is taken.');
      }
      final old = (await t.get(_user(uid))).data()?['username'] as String?;
      if (old != null && old.toLowerCase() != name.toLowerCase()) {
        t.delete(_name(old));
      }
      if (!taken.exists) t.set(_name(name), {'uid': uid});
      t.set(_user(uid), {'username': name}, SetOptions(merge: true));
    });
  }

  Future<void> setAvatar(String uid, int avatar) =>
      _user(uid).set({'avatar': avatar}, SetOptions(merge: true));

  /// Removes the profile, username and all games of [uid] (REQ-ACC-07).
  Future<void> deleteData(String uid, GameStore store) async {
    await store.deleteAll(uid);
    final name = (await load(uid))['username'] as String?;
    if (name != null) await _name(name).delete();
    await _user(uid).delete();
  }
}

/// Username, avatar and account deletion for a signed-in player.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.auth,
    required this.profiles,
    required this.store,
  });

  final FirebaseAuth auth;
  final Profiles profiles;
  final GameStore store;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _name = TextEditingController();
  int? _avatar;
  String? _message;
  bool _busy = true;

  String get _uid => widget.auth.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    widget.profiles.load(_uid).then((p) {
      if (!mounted) return;
      setState(() {
        _name.text = p['username'] as String? ?? '';
        _avatar = p['avatar'] as int?;
        _busy = false;
      });
    });
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action, String done) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action();
      _message = done;
    } on UsernameException catch (e) {
      _message = e.message;
    } on FirebaseException catch (e) {
      _message = 'Could not save (${e.code}). Please try again.';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _save() => _run(() async {
        final name = _name.text.trim();
        if (name.isNotEmpty) await widget.profiles.setUsername(_uid, name);
        if (_avatar != null) {
          await widget.profiles.setAvatar(_uid, _avatar!);
        }
      }, 'Profile saved.');

  Future<void> _delete() async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
            'This removes your account, username and all your games. It cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (sure != true || !mounted) return;
    setState(() => _busy = true);
    final navigator = Navigator.of(context);
    try {
      final user = widget.auth.currentUser!;
      // Data first: once the account is gone the rules no longer let us in.
      await widget.profiles.deleteData(user.uid, widget.store);
      await user.delete();
      await widget.auth.signOut();
      navigator.pop();
    } on FirebaseAuthException catch (e) {
      setState(() {
        _busy = false;
        _message = e.code == 'requires-recent-login'
            ? 'Your games were deleted. For safety, sign out, sign in again and tap Delete account once more.'
            : authErrorMessage(e.code);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Username'),
                ),
                const SizedBox(height: 16),
                Text('Avatar', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var i = 0; i < avatars.length; i++)
                      ChoiceChip(
                        label: Text(avatars[i],
                            style: const TextStyle(fontSize: 26)),
                        selected: _avatar == i,
                        onSelected: _busy
                            ? null
                            : (_) => setState(() => _avatar = i),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_message != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(_message!, textAlign: TextAlign.center),
                  ),
                FilledButton(
                    onPressed: _busy ? null : _save,
                    child: const Text('Save')),
                const Divider(height: 40),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _delete,
                  icon: const Icon(Icons.delete_forever_outlined),
                  label: const Text('Delete account'),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
