import 'package:flutter/material.dart';

void main() => runApp(const TicTacToeArenaApp());

class TicTacToeArenaApp extends StatelessWidget {
  const TicTacToeArenaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TicTacToe Arena',
      theme: ThemeData(colorSchemeSeed: Colors.indigo),
      home: const Scaffold(
        body: Center(child: Text('TicTacToe Arena')),
      ),
    );
  }
}
