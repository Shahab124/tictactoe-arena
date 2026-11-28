import 'dart:math';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_engine/game_engine.dart';
import 'package:tictactoe_arena/online/online_rooms.dart';
import 'package:tictactoe_arena/online/ratings.dart';
import 'package:tictactoe_arena/online/online_screen.dart';
import 'package:tictactoe_arena/ui/app_settings.dart';
import 'package:tictactoe_arena/ui/strings.dart';

void main() {
  late FakeFirebaseFirestore db;
  late OnlineRooms rooms;

  setUp(() {
    db = FakeFirebaseFirestore();
    rooms = OnlineRooms(db, random: Random(1));
  });

  Future<Room> load(String code) async => Room.fromMap(
    code,
    (await db.collection('rooms').doc(code).get()).data()!,
  );

  test('two players join with a short code and play to a win', () async {
    final code = await rooms.create('ayesha');
    expect(code, matches(RegExp(r'^[A-Z2-9]{5}$')));
    expect((await load(code)).status, 'waiting');

    await rooms.join(
      code.toLowerCase(),
      'omar',
    ); // Codes aren't case-sensitive.
    var room = await load(code);
    expect(room.status, 'playing');
    expect(room.markOf('omar'), Mark.o);

    // X: top row. O: middle row.
    for (final (uid, row, col) in [
      ('ayesha', 0, 0),
      ('omar', 1, 0),
      ('ayesha', 0, 1),
      ('omar', 1, 1),
      ('ayesha', 0, 2),
    ]) {
      await rooms.move(await load(code), uid, row, col);
    }
    room = await load(code);
    expect(room.status, 'over');
    expect(room.winner, 'X');
    expect(room.reason, 'line');
    expect(room.completedAt, isNotNull);
  });

  test('moves out of turn or on a taken cell are ignored', () async {
    final code = await rooms.create('ayesha');
    await rooms.join(code, 'omar');
    await rooms.move(await load(code), 'omar', 0, 0); // X moves first.
    expect((await load(code)).moves, isEmpty);
    await rooms.move(await load(code), 'ayesha', 0, 0);
    await rooms.move(await load(code), 'omar', 0, 0);
    expect((await load(code)).moves, [0]);
  });

  test('wrong code and full room give a clear message', () async {
    await expectLater(
      rooms.join('ZZZZZ', 'omar'),
      throwsA(
        isA<RoomException>().having(
          (e) => e.message,
          'message',
          'No room with that code.',
        ),
      ),
    );
    final code = await rooms.create('ayesha');
    await rooms.join(code, 'omar');
    await expectLater(
      rooms.join(code, 'zara'),
      throwsA(
        isA<RoomException>().having(
          (e) => e.message,
          'message',
          'That room is full.',
        ),
      ),
    );
  });

  test('a player who dropped can find and rejoin their game', () async {
    final code = await rooms.create('ayesha');
    await rooms.join(code, 'omar');
    await rooms.move(await load(code), 'ayesha', 1, 1);
    expect((await rooms.unfinished('omar'))?.code, code);
    await rooms.join(code, 'omar'); // Rejoining doesn't change the game.
    final room = await load(code);
    expect(room.moves, [4]);
    expect(room.status, 'playing');
  });

  test('a player who leaves loses', () async {
    final code = await rooms.create('ayesha');
    await rooms.join(code, 'omar');
    await rooms.leave(await load(code), 'ayesha');
    final room = await load(code);
    expect((room.status, room.winner, room.reason), ('over', 'O', 'left'));
    expect(room.completedAt, isNotNull);
    expect(await rooms.unfinished('omar'), isNull);
  });

  test('a player who runs out of time loses', () async {
    final code = await rooms.create('ayesha');
    await rooms.join(code, 'omar');
    final room = await load(code);
    // Too early: nothing happens.
    await rooms.claimTimeout(room, 'omar');
    expect((await load(code)).status, 'playing');
    // The player whose turn it is can't claim their own timeout.
    final late = room.lastMoveAt!.add(turnLimit + const Duration(seconds: 1));
    await rooms.claimTimeout(room, 'ayesha', now: late);
    expect((await load(code)).status, 'playing');
    await rooms.claimTimeout(room, 'omar', now: late);
    final over = await load(code);
    expect((over.winner, over.reason), ('O', 'timeout'));
    expect(over.completedAt, isNotNull);
  });

  testWidgets('a move on one device shows on the other', (tester) async {
    final code = (await tester.runAsync(() async {
      final code = await rooms.create('ayesha');
      await rooms.join(code, 'omar');
      return code;
    }))!;
    await tester.pumpWidget(
      MaterialApp(
        home: RoomScreen(
          rooms: rooms,
          ratings: Ratings(rooms.firestore),
          uid: 'omar',
          code: code,
        ),
      ),
    );
    await tester.pump();
    expect(find.text('You are O'), findsOneWidget);
    expect(find.textContaining('Their turn'), findsOneWidget);

    await tester.runAsync(
      () async => rooms.move(await load(code), 'ayesha', 0, 0),
    );
    await tester.pump();
    expect(find.textContaining('Your turn'), findsOneWidget);
    expect(find.bySemanticsLabel('Row 1, column 1, X'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Row 2, column 2, empty'));
    await tester.pump();
    final moves = await tester.runAsync(() async => (await load(code)).moves);
    expect(moves, [0, 4]);
  });

  testWidgets('lobby creates a room and shows its code', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: OnlineLobby(
          rooms: rooms,
          ratings: Ratings(rooms.firestore),
          uid: 'ayesha',
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Create room'));
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    final code = (await tester.runAsync(
      () async => (await db.collection('rooms').get()).docs.single.id,
    ))!;
    await tester.pump();
    expect(find.text('Room $code'), findsOneWidget);
    expect(find.text(code), findsOneWidget);
    expect(find.textContaining('Waiting for a player'), findsOneWidget);
  });

  testWidgets('online lobby labels are translated when Urdu is selected', (
    tester,
  ) async {
    final settings = AppSettings();
    await tester.pumpWidget(
      AppSettingsScope(
        settings: settings,
        child: MaterialApp(
          home: OnlineLobby(
            rooms: rooms,
            ratings: Ratings(rooms.firestore),
            uid: 'ayesha',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Play online'), findsOneWidget);

    settings.urdu = true;
    await tester.pumpAndSettle();

    expect(find.text('آن لائن کھیلیں'), findsOneWidget);
    expect(find.text('میچ تلاش کریں'), findsOneWidget);
    expect(find.text('کمرہ بنائیں'), findsOneWidget);
    expect(find.text('کمرے کا کوڈ'), findsOneWidget);
    expect(find.text('کمرے میں شامل ہوں'), findsOneWidget);
  });

  test('online labels with ratings, rooms and turns are translated', () {
    expect(toUrdu('Your rating: 1200'), 'آپ کی درجہ بندی: 1200');
    expect(toUrdu('Room ABCDE'), 'کمرہ ABCDE');
    expect(toUrdu('Your turn · 60s'), 'آپ کی باری · 60 سیکنڈ');
    expect(toUrdu('Reported player: omar'), 'رپورٹ کیا گیا کھلاڑی: omar');
  });
}
