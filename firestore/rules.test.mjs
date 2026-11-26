// Run from the repo root: firebase emulators:exec --only firestore "npm test --prefix firestore"
import { readFileSync } from 'node:fs';
import { after, beforeEach, test } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import { deleteDoc, doc, getDoc, serverTimestamp, setDoc, updateDoc } from 'firebase/firestore';

const env = await initializeTestEnvironment({
  projectId: 'demo-tictactoe-arena',
  firestore: { rules: readFileSync(new URL('./firestore.rules', import.meta.url), 'utf8') },
});

beforeEach(() => env.clearFirestore());
after(() => env.cleanup());

const db = (uid) => (uid ? env.authenticatedContext(uid) : env.unauthenticatedContext()).firestore();

test('a player can write and read their own profile and games', async () => {
  await assertSucceeds(setDoc(doc(db('ayesha'), 'users/ayesha'), { email: 'a@example.com' }));
  await assertSucceeds(setDoc(doc(db('ayesha'), 'users/ayesha/games/g1'), { result: 'win' }));
  await assertSucceeds(getDoc(doc(db('ayesha'), 'users/ayesha/games/g1')));
});

test("a player cannot read or change another player's data", async () => {
  await env.withSecurityRulesDisabled((ctx) =>
    setDoc(doc(ctx.firestore(), 'users/omar/games/g1'), { result: 'loss' }));
  await assertFails(getDoc(doc(db('ayesha'), 'users/omar')));
  await assertFails(getDoc(doc(db('ayesha'), 'users/omar/games/g1')));
  await assertFails(setDoc(doc(db('ayesha'), 'users/omar/games/g1'), { result: 'win' }));
});

test('signed-out users can read and write nothing', async () => {
  await assertFails(getDoc(doc(db(null), 'users/omar')));
  await assertFails(setDoc(doc(db(null), 'users/omar'), { email: 'x' }));
});

test('collections outside users/ are closed', async () => {
  await assertFails(setDoc(doc(db('ayesha'), 'leaderboard/top'), { score: 1 }));
});

test('a player can claim a free username and release it', async () => {
  await assertSucceeds(setDoc(doc(db('ayesha'), 'usernames/ayesha_k'), { uid: 'ayesha' }));
  await assertSucceeds(getDoc(doc(db('omar'), 'usernames/ayesha_k')));
  await assertSucceeds(deleteDoc(doc(db('ayesha'), 'usernames/ayesha_k')));
});

test("usernames are unique and can't be taken or claimed for someone else", async () => {
  await env.withSecurityRulesDisabled((ctx) =>
    setDoc(doc(ctx.firestore(), 'usernames/omar'), { uid: 'omar' }));
  await assertFails(setDoc(doc(db('ayesha'), 'usernames/omar'), { uid: 'ayesha' }));
  await assertFails(deleteDoc(doc(db('ayesha'), 'usernames/omar')));
  await assertFails(setDoc(doc(db('ayesha'), 'usernames/zara'), { uid: 'zara' }));
  await assertFails(setDoc(doc(db('ayesha'), 'usernames/Bad Name!'), { uid: 'ayesha' }));
  await assertFails(getDoc(doc(db(null), 'usernames/omar')));
});

// Online rooms (SCRUM-29).
const room = (extra = {}) => ({
  size: 3, winLength: 3, x: 'ayesha', o: null, players: ['ayesha'],
  moves: [], status: 'waiting', winner: null, reason: null, lastMoveAt: null, ...extra,
});
const playing = (extra = {}) =>
  room({ o: 'omar', players: ['ayesha', 'omar'], status: 'playing', lastMoveAt: new Date(), ...extra });
const seed = (data) => env.withSecurityRulesDisabled((ctx) => setDoc(doc(ctx.firestore(), 'rooms/ABCDE'), data));

test('a player can create a room and another can join it with the code', async () => {
  await assertSucceeds(setDoc(doc(db('ayesha'), 'rooms/ABCDE'), room()));
  await assertSucceeds(getDoc(doc(db('omar'), 'rooms/ABCDE')));
  await assertSucceeds(updateDoc(doc(db('omar'), 'rooms/ABCDE'), {
    o: 'omar', players: ['ayesha', 'omar'], status: 'playing', lastMoveAt: serverTimestamp(),
  }));
});

test('a room cannot be created in someone else\'s name', async () => {
  await assertFails(setDoc(doc(db('omar'), 'rooms/ABCDE'), room()));
});

test('players move only on their own turn, one empty cell at a time', async () => {
  await seed(playing());
  const move = (uid, moves) => updateDoc(doc(db(uid), 'rooms/ABCDE'), { moves, lastMoveAt: serverTimestamp() });
  await assertFails(move('omar', [4]));        // X moves first.
  await assertFails(move('ayesha', [4, 5]));   // Two moves at once.
  await assertSucceeds(move('ayesha', [4]));
  await assertFails(move('ayesha', [4, 0]));   // Not X's turn now.
  await assertFails(move('omar', [4, 4]));     // Cell taken.
  await assertFails(move('omar', [4, 9]));     // Off the board.
  await assertSucceeds(move('omar', [4, 0]));
});

test('someone not in the game cannot change it or join a full room', async () => {
  await seed(playing());
  await assertFails(updateDoc(doc(db('zara'), 'rooms/ABCDE'), { moves: [4], lastMoveAt: serverTimestamp() }));
  await assertFails(updateDoc(doc(db('zara'), 'rooms/ABCDE'), { status: 'over', winner: 'X', reason: 'left' }));
  await assertFails(updateDoc(doc(db('zara'), 'rooms/ABCDE'), {
    o: 'zara', players: ['ayesha', 'zara'], status: 'playing', lastMoveAt: serverTimestamp(),
  }));
});

test('a player who leaves loses, and cannot hand themselves the win', async () => {
  await seed(playing());
  await assertFails(updateDoc(doc(db('omar'), 'rooms/ABCDE'), { status: 'over', winner: 'O', reason: 'left' }));
  await assertSucceeds(updateDoc(doc(db('omar'), 'rooms/ABCDE'), { status: 'over', winner: 'X', reason: 'left' }));
});

test('a win on time can be claimed only after 60 seconds', async () => {
  const claim = () => updateDoc(doc(db('omar'), 'rooms/ABCDE'), { status: 'over', winner: 'O', reason: 'timeout' });
  await seed(playing());                                          // X to move, just started.
  await assertFails(claim());
  await seed(playing({ lastMoveAt: new Date(Date.now() - 61000) }));
  await assertSucceeds(claim());
});
