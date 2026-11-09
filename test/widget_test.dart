import 'package:firebase_auth/firebase_auth.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mock_exceptions/mock_exceptions.dart';
import 'package:tictactoe_arena/auth/sign_in_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tictactoe_arena/data/game_store.dart';
import 'package:tictactoe_arena/main.dart';

Future<void> enter(WidgetTester tester, String email, String password) async {
  await tester.enterText(find.widgetWithText(TextField, 'Email'), email);
  await tester.enterText(find.widgetWithText(TextField, 'Password'), password);
}

Future<Widget> app(FirebaseAuth auth) async {
  SharedPreferences.setMockInitialValues({});
  return TicTacToeArenaApp(
    auth: auth,
    store: GameStore(
      firestore: FakeFirebaseFirestore(),
      prefs: await SharedPreferences.getInstance(),
    ),
  );
}

void main() {
  testWidgets('starts on the sign-in screen', (tester) async {
    await tester.pumpWidget(await app(MockFirebaseAuth()));
    await tester.pump();
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Play as guest'), findsOneWidget);
  });

  testWidgets('create account signs the player in', (tester) async {
    final auth = MockFirebaseAuth();
    await tester.pumpWidget(await app(auth));
    await tester.pump();
    await enter(tester, 'ayesha@example.com', 'secret123');
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();
    expect(auth.currentUser?.email, 'ayesha@example.com');
    expect(find.text('Playing as ayesha@example.com'), findsOneWidget);
  });

  testWidgets('sign in with email works and sign out returns', (tester) async {
    final auth = MockFirebaseAuth(mockUser: MockUser(email: 'omar@example.com'));
    await tester.pumpWidget(await app(auth));
    await tester.pump();
    await enter(tester, 'omar@example.com', 'secret123');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Playing as omar@example.com'), findsOneWidget);

    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(find.text('Sign in'), findsOneWidget);
    expect(auth.currentUser, isNull);
  });

  testWidgets('a signed-in player stays signed in on launch', (tester) async {
    final auth = MockFirebaseAuth(
        signedIn: true, mockUser: MockUser(email: 'sara@example.com'));
    await tester.pumpWidget(await app(auth));
    await tester.pumpAndSettle();
    expect(find.text('Playing as sara@example.com'), findsOneWidget);
  });

  testWidgets('wrong password shows a clear message', (tester) async {
    final auth = MockFirebaseAuth();
    whenCalling(Invocation.method(#signInWithEmailAndPassword, null))
        .on(auth)
        .thenThrow(FirebaseAuthException(code: 'invalid-credential'));
    await tester.pumpWidget(await app(auth));
    await tester.pump();
    await enter(tester, 'omar@example.com', 'nope');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Wrong email or password.'), findsOneWidget);
    expect(auth.currentUser, isNull);
  });

  testWidgets('guest play opens the app without an account', (tester) async {
    final auth = MockFirebaseAuth();
    await tester.pumpWidget(await app(auth));
    await tester.pump();
    await tester.tap(find.text('Play as guest'));
    await tester.pumpAndSettle();
    expect(find.text('Playing as Guest'), findsOneWidget);
    expect(auth.currentUser, isNull);
  });

  testWidgets('password reset needs an email, then confirms', (tester) async {
    await tester.pumpWidget(await app(MockFirebaseAuth()));
    await tester.pump();
    await tester.tap(find.text('Forgot password?'));
    await tester.pump();
    expect(find.text('Enter your email first.'), findsOneWidget);

    await enter(tester, 'zain@example.com', '');
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();
    expect(find.text('Password reset email sent to zain@example.com.'),
        findsOneWidget);
  });

  test('unknown error codes still give a readable message', () {
    expect(authErrorMessage('weak-password'),
        'Use a password of at least 6 characters.');
    expect(authErrorMessage('odd-code'), contains('odd-code'));
  });
}
