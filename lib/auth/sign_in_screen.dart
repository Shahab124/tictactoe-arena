import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Sign up, sign in, Google sign-in, password reset and guest play
/// (REQ-ACC-01, 02 and 06). Passwords are handled only by Firebase
/// Authentication and never stored by the app (REQ-DATA-07).
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key, required this.auth, required this.onGuest});

  final FirebaseAuth auth;
  final VoidCallback onGuest;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _message;
  bool _busy = false;

  // ponytail: Google sign-in on web and Android only; Windows has no Firebase
  // Google flow, so Windows players use email. Android may also need the app's
  // SHA-1 added in the Firebase console if the Google button fails on a phone.
  bool get _googleSupported =>
      kIsWeb || defaultTargetPlatform == TargetPlatform.android;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action, {String? success}) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action();
      if (success != null) _message = success;
    } on FirebaseAuthException catch (e) {
      _message = authErrorMessage(e.code);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String get _emailText => _email.text.trim();

  void _signIn() => _run(() => widget.auth
      .signInWithEmailAndPassword(email: _emailText, password: _password.text));

  void _signUp() => _run(() => widget.auth.createUserWithEmailAndPassword(
      email: _emailText, password: _password.text));

  void _google() => _run(() => kIsWeb
      ? widget.auth.signInWithPopup(GoogleAuthProvider())
      : widget.auth.signInWithProvider(GoogleAuthProvider()));

  void _reset() {
    if (_emailText.isEmpty) {
      setState(() => _message = 'Enter your email first.');
      return;
    }
    _run(() => widget.auth.sendPasswordResetEmail(email: _emailText),
        success: 'Password reset email sent to $_emailText.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('TicTacToe Arena')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _email,
                    decoration: const InputDecoration(labelText: 'Email'),
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _password,
                    decoration: const InputDecoration(labelText: 'Password'),
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                  ),
                  const SizedBox(height: 12),
                  if (_message != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(_message!, textAlign: TextAlign.center),
                    ),
                  FilledButton(
                    onPressed: _busy ? null : _signIn,
                    child: const Text('Sign in'),
                  ),
                  OutlinedButton(
                    onPressed: _busy ? null : _signUp,
                    child: const Text('Create account'),
                  ),
                  TextButton(
                    onPressed: _busy ? null : _reset,
                    child: const Text('Forgot password?'),
                  ),
                  if (_googleSupported)
                    OutlinedButton(
                      onPressed: _busy ? null : _google,
                      child: const Text('Continue with Google'),
                    ),
                  const Divider(height: 32),
                  TextButton(
                    onPressed: _busy ? null : widget.onGuest,
                    child: const Text('Play as guest'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Turns a Firebase Authentication error code into a message for the player.
String authErrorMessage(String code) => switch (code) {
      'invalid-email' => 'That email address is not valid.',
      'user-not-found' ||
      'wrong-password' ||
      'invalid-credential' =>
        'Wrong email or password.',
      'email-already-in-use' => 'An account already exists for that email.',
      'weak-password' => 'Use a password of at least 6 characters.',
      'too-many-requests' => 'Too many attempts. Try again later.',
      'network-request-failed' => 'No internet connection.',
      'popup-closed-by-user' || 'web-context-canceled' => 'Sign-in cancelled.',
      _ => 'Something went wrong ($code). Please try again.',
    };
