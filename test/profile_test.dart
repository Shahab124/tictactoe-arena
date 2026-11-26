import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mock_exceptions/mock_exceptions.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tictactoe_arena/auth/profile.dart';
import 'package:tictactoe_arena/data/game_store.dart';
import 'package:tictactoe_arena/main.dart';

import 'history_test.dart' show game;
import 'widget_test.dart' show enter, tapText;

Future<GameStore> newStore(FakeFirebaseFirestore firestore) async {
  SharedPreferences.setMockInitialValues({});
  return GameStore(
      firestore: firestore, prefs: await SharedPreferences.getInstance());
}
// Collects saved game results for a specific user from Firestore.
Future<List<String>> results(FakeFirebaseFirestore db, String uid) async => [
      for (final d in (await db.collection('users/$uid/games').get()).docs)
        d.data()['result'] as String
    ];

void main() {
  test('guest games move into the new account and leave the device',
      () async {
    final db = FakeFirebaseFirestore();
    final store = await newStore(db);
    await store.save(game('win'));
    await store.save(game('draw'));

    await store.moveGuestGames('ayesha');
    await Future<void>.delayed(Duration.zero);

    expect(await results(db, 'ayesha'), unorderedEquals(['win', 'draw']));
    expect(await store.history(), isEmpty);
  });
// Tests username uniqueness, validation rules, and username updates.
  testWidgets('a guest who signs up keeps their games', (tester) async {
    final db = FakeFirebaseFirestore();
    final store = await newStore(db);
    final auth = MockFirebaseAuth();
    await tester.pumpWidget(TicTacToeArenaApp(auth: auth, store: store));
    await tester.pump();
    await tapText(tester, 'Play as guest');
    await tester.pumpAndSettle();
    await store.save(game('win')); // As if a game was just finished.

    await tapText(tester, 'Sign up');
    await tester.pumpAndSettle();
    await enter(tester, 'ayesha@example.com', 'secret123');
    await tapText(tester, 'Create account');
    await tester.pumpAndSettle();

    expect(find.text('Playing as ayesha@example.com'), findsOneWidget);
    expect(await results(db, auth.currentUser!.uid), ['win']);
  });

  group('usernames', () {
    late FakeFirebaseFirestore db;
    late Profiles profiles;
    setUp(() {
      db = FakeFirebaseFirestore();
      profiles = Profiles(db);
    });

    test('are unique, ignoring capitals', () async {
      await profiles.setUsername('ayesha', 'Star_1');
      expect(
          () => profiles.setUsername('omar', 'star_1'),
          throwsA(isA<UsernameException>()
              .having((e) => e.message, 'message', 'That username is taken.')));
      expect((await profiles.load('ayesha'))['username'], 'Star_1');
    });

    test('changing a username frees the old one', () async {
      await profiles.setUsername('ayesha', 'first');
      await profiles.setUsername('ayesha', 'second');
      await profiles.setUsername('omar', 'first');
      expect((await profiles.load('omar'))['username'], 'first');
      expect((await db.doc('usernames/second').get()).data(), {'uid': 'ayesha'});
    });

    test('must be 3 to 15 letters, numbers or underscores', () async {
      for (final bad in ['ab', 'has space', 'a' * 16, 'emoji🙂']) {
        expect(() => profiles.setUsername('ayesha', bad),
            throwsA(isA<UsernameException>()));
      }
    });
  });

  Future<(MockFirebaseAuth, FakeFirebaseFirestore, GameStore)> signedIn(
      WidgetTester tester) async {
    final db = FakeFirebaseFirestore();
    final store = await newStore(db);
    final auth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'sara', email: 'sara@example.com'));
    await tester.pumpWidget(TicTacToeArenaApp(auth: auth, store: store));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Profile'));
    await tester.pumpAndSettle();
    return (auth, db, store);
  }

  testWidgets('a player can pick a username and an avatar', (tester) async {
    final (_, db, _) = await signedIn(tester);
    await tester.enterText(
        find.widgetWithText(TextField, 'Username'), 'sara_plays');
    await tester.tap(find.text(avatars[2]));
    await tester.pump();
    await tapText(tester, 'Save');
    await tester.pumpAndSettle();

    expect(find.text('Profile saved.'), findsOneWidget);
    expect((await db.doc('users/sara').get()).data(),
        {'username': 'sara_plays', 'avatar': 2});
  });

  testWidgets('a taken username shows a message', (tester) async {
    final (_, db, _) = await signedIn(tester);
    await db.doc('usernames/omar').set({'uid': 'omar'});
    await tester.enterText(find.widgetWithText(TextField, 'Username'), 'Omar');
    await tapText(tester, 'Save');
    await tester.pumpAndSettle();
    expect(find.text('That username is taken.'), findsOneWidget);
  });

  testWidgets('deleting the account removes all the player data',
      (tester) async {
    final (auth, db, store) = await signedIn(tester);
    await Profiles(db).setUsername('sara', 'sara');
    await store.save(game('win'), uid: 'sara');
    await store.save(game('loss'), uid: 'sara');
    await db.doc('users/omar/games/g1').set({'result': 'win'});

    await tapText(tester, 'Delete account');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(await results(db, 'sara'), isEmpty);
    expect((await db.doc('users/sara').get()).exists, isFalse);
    expect((await db.doc('usernames/sara').get()).exists, isFalse);
    expect(await results(db, 'omar'), ['win']); // Others are untouched.
    expect(auth.currentUser, isNull);
    expect(find.text('Play as guest'), findsOneWidget);
  });

  testWidgets('delete asks to sign in again when Firebase needs it',
      (tester) async {
    final (auth, _, _) = await signedIn(tester);
    whenCalling(Invocation.method(#delete, []))
        .on(auth.currentUser!)
        .thenThrow(FirebaseAuthException(code: 'requires-recent-login'));

    await tapText(tester, 'Delete account');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(find.textContaining('sign in again'), findsOneWidget);
    expect(auth.currentUser, isNotNull);
  });
}
