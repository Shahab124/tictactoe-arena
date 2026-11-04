// Run from the repo root: firebase emulators:exec --only firestore "npm test --prefix firestore"
import { readFileSync } from 'node:fs';
import { after, beforeEach, test } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc } from 'firebase/firestore';

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
