import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tictactoe_arena/online/matchmaking.dart';
import 'package:tictactoe_arena/online/online_rooms.dart';
import 'package:tictactoe_arena/online/ratings.dart';

void main() {
  late FakeFirebaseFirestore fs;
  late Matchmaker mm;
  final now = DateTime(2026, 11, 26, 18);

  Future<void> waiting(String uid, int rating,
          {int size = 3, Duration ago = Duration.zero}) =>
      fs.doc('queue/$uid').set({
        'rating': rating,
        'size': size,
        'since': Timestamp.fromDate(now.subtract(ago)),
        'room': null,
      });

  setUp(() {
    fs = FakeFirebaseFirestore();
    mm = Matchmaker(fs, Ratings(fs));
  });

  test('the allowed rating gap widens the longer someone waits', () {
    expect(allowedGap(Duration.zero), 100);
    expect(allowedGap(const Duration(seconds: 25)), 200);
    expect(allowedGap(const Duration(minutes: 1)), 400);
    expect(allowedGap(const Duration(seconds: -30)), 100); // Clock skew.
  });

  test('nobody waiting: the player joins the queue', () async {
    expect(await mm.findOrWait('ayesha', now: now), isNull);
    final q = (await fs.doc('queue/ayesha').get()).data()!;
    expect([q['rating'], q['size'], q['room']], [startRating, 3, null]);
  });

  test('pairs with the closest waiting player and creates the room', () async {
    await waiting('far', 1290);
    await waiting('near', 1230);
    final code = await mm.findOrWait('me', now: now);

    expect(code, isNotNull);
    expect((await fs.doc('queue/near').get()).data()!['room'], code);
    expect((await fs.doc('queue/far').get()).data()!['room'], isNull);
    final room = (await fs.doc('rooms/$code').get()).data()!;
    expect([room['x'], room['status']], ['me', 'waiting']);
  });

  test('a player too far apart is matched only after waiting longer', () async {
    await waiting('pro', 1500);
    expect(await mm.findOrWait('me', now: now), isNull);
    await mm.leave('me');

    await waiting('pro', 1500, ago: const Duration(seconds: 70)); // gap 450
    expect(await mm.findOrWait('me', now: now), isNotNull);
  });

  test('board sizes are matched separately', () async {
    await waiting('big', 1200, size: 8);
    expect(await mm.findOrWait('me', size: 3, now: now), isNull);
    expect(await mm.findOrWait('me2', size: 8, now: now), isNotNull);
  });

  test('both players end up in the same game; cancel leaves the queue', () async {
    final rooms = OnlineRooms(fs);
    expect(await mm.findOrWait('ayesha', now: now), isNull);
    final code = await mm.findOrWait('omar', now: now.add(const Duration(seconds: 1)));

    final handedOver = await mm.matched('ayesha').firstWhere((c) => c != null);
    expect(handedOver, code);
    await rooms.join(code!, 'ayesha');
    await mm.leave('ayesha');

    final room = Room.fromMap(code, (await fs.doc('rooms/$code').get()).data()!);
    expect([room.x, room.o, room.status], ['omar', 'ayesha', 'playing']);
    expect((await fs.doc('queue/ayesha').get()).exists, isFalse);

    expect(await mm.findOrWait('zara', now: now), isNull);
    await mm.leave('zara');
    expect((await fs.doc('queue/zara').get()).exists, isFalse);
  });
}
