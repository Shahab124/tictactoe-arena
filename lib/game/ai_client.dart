import 'package:game_ai/game_ai.dart';

export 'package:game_ai/game_ai.dart' show difficulties;

/// The AI Client: the only part of the Platform that calls the Game AI
/// (D3 section 2.3). Takes one AI request and returns a move or an error in
/// the format of D3 section 2.4, so another group's AI can be plugged in by
/// passing a different function to the game screen.
typedef AiClient = Future<Map<String, Object>> Function(
    Map<String, dynamic> request);

/// Our own Game AI. It runs on the device, so games against the computer
/// work with no internet connection (REQ-MODE-07).
// ponytail: runs on the UI thread because it answers in milliseconds; move it
// to an isolate with compute() if a slower AI is ever plugged in.
Future<Map<String, Object>> localAi(Map<String, dynamic> request) async =>
    requestMove(request);
