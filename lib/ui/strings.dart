import 'package:flutter/widgets.dart';

import 'app_settings.dart';

/// English and Urdu text (REQ-UX-06). Screens write `context.tr('English')`;
/// in Urdu that English text is looked up here, and a few sentences with a
/// name or number in them are matched by pattern. Anything missing stays in
/// English rather than breaking.
extension Translate on BuildContext {
  String tr(String en) => AppSettings.of(this).urdu ? toUrdu(en) : en;
}

String toUrdu(String en) {
  final exact = _ur[en];
  if (exact != null) return exact;
  for (final (pattern, urdu) in _patterns) {
    final m = pattern.firstMatch(en);
    if (m != null) {
      return urdu.replaceAllMapped(
          RegExp(r'\$(\d)'), (g) => m.group(int.parse(g.group(1)!)) ?? '');
    }
  }
  return en;
}

final _patterns = [
  (RegExp(r"^([XO])'s turn$"), r'$1 کی باری'),
  (RegExp(r'^You win the match!$'), 'آپ میچ جیت گئے!'),
  (RegExp(r'^(.+) wins the match!$'), r'$1 میچ جیت گیا!'),
  (RegExp(r'^You win!$'), 'آپ جیت گئے!'),
  (RegExp(r'^(.+) wins!$'), r'$1 جیت گیا!'),
  (RegExp(r'^Playing as (.+)$'), r'$1 کے طور پر کھیل رہے ہیں'),
  (RegExp(r'^vs (.+)$'), r'مقابلہ: $1'),
  (
    RegExp(r'^Password reset email sent to (.+)\.$'),
    r'پاس ورڈ ری سیٹ ای میل $1 پر بھیج دی گئی۔'
  ),
];

const _ur = {
  // App and sign-in
  'TicTacToe Arena': 'ٹک ٹیک ٹو ایرینا',
  'Classic 3×3 or the big 8×8 board.': 'کلاسک 3×3 یا بڑا 8×8 بورڈ۔',
  'Email': 'ای میل',
  'Password': 'پاس ورڈ',
  'Sign in': 'سائن ان',
  'Sign out': 'سائن آؤٹ',
  'Sign up': 'سائن اپ',
  'Create account': 'اکاؤنٹ بنائیں',
  'Continue with Google': 'گوگل کے ساتھ جاری رکھیں',
  'Forgot password?': 'پاس ورڈ بھول گئے؟',
  'Play as guest': 'مہمان کے طور پر کھیلیں',
  'Enter your email first.': 'پہلے اپنی ای میل لکھیں۔',
  'Wrong email or password.': 'ای میل یا پاس ورڈ غلط ہے۔',
  // Home
  'Ready to play?': 'کھیلنے کے لیے تیار؟',
  'Classic 3×3': 'کلاسک 3×3',
  'Big 8×8': 'بڑا 8×8',
  'Three in a row. Two players, one device.':
      'لگاتار تین۔ دو کھلاڑی، ایک ڈیوائس۔',
  'Five in a row on the large board.': 'بڑے بورڈ پر لگاتار پانچ۔',
  'History & statistics': 'ریکارڈ اور اعداد و شمار',
  'Your games, wins and win rate': 'آپ کے کھیل، جیتیں اور جیت کی شرح',
  'Profile': 'پروفائل',
  'Settings': 'ترتیبات',
  // Setup
  'New game': 'نیا کھیل',
  'Continue unfinished game': 'ادھورا کھیل جاری رکھیں',
  'Board': 'بورڈ',
  'Mode': 'طریقہ',
  'Two players': 'دو کھلاڑی',
  'Computer': 'کمپیوٹر',
  'Difficulty': 'مشکل',
  'Easy': 'آسان',
  'Medium': 'درمیانہ',
  'Hard': 'مشکل',
  'Expert': 'ماہر',
  'You play': 'آپ کھیلیں گے',
  'Who starts': 'پہلے کون',
  'Match': 'میچ',
  'Start game': 'کھیل شروع کریں',
  // Game
  'Your turn': 'آپ کی باری',
  "It's a draw": 'برابر رہا',
  'Computer is thinking…': 'کمپیوٹر سوچ رہا ہے…',
  'The computer could not make a move': 'کمپیوٹر چال نہیں چل سکا',
  'That cell is already taken': 'یہ خانہ پہلے ہی بھرا ہوا ہے',
  'Pinch to zoom, drag to move':
      'بڑا کرنے کے لیے چٹکی لیں، ہلانے کے لیے کھینچیں',
  'Retry': 'دوبارہ کوشش',
  'End game': 'کھیل ختم کریں',
  'Hint': 'اشارہ',
  'Replay': 'دوبارہ دیکھیں',
  'Undo': 'واپس لیں',
  'Restart': 'دوبارہ شروع',
  'Rematch': 'دوبارہ کھیلیں',
  'New match': 'نیا میچ',
  'Next game': 'اگلا کھیل',
  'Player X': 'کھلاڑی X',
  'Player O': 'کھلاڑی O',
  // History
  'Could not load your games.': 'آپ کے کھیل لوڈ نہیں ہو سکے۔',
  'No games played yet.': 'ابھی کوئی کھیل نہیں کھیلا گیا۔',
  // Settings
  'Theme': 'تھیم',
  'System': 'سسٹم',
  'Light': 'روشن',
  'Dark': 'گہرا',
  'Skin': 'رنگ',
  'Sound': 'آواز',
  'A click when a mark is placed': 'نشان لگانے پر کلک کی آواز',
  'Vibration': 'وائبریشن',
  'A short buzz on phones that support it': 'فون پر ہلکی سی وائبریشن',
  'Language': 'زبان',
  'English': 'انگریزی',
  'Urdu': 'اردو',
  'Colour-blind friendly colours': 'رنگ نہ پہچاننے والوں کے لیے رنگ',
  'Blue and orange, which almost everyone can tell apart':
      'نیلا اور نارنجی، جو تقریباً سب پہچان سکتے ہیں',
  'How to play': 'کھیلنے کا طریقہ',
  // Tutorial
  'Welcome to TicTacToe Arena': 'ٹک ٹیک ٹو ایرینا میں خوش آمدید',
  'Take turns placing X and O. Tap an empty cell to play.':
      'باری باری X اور O لگائیں۔ کھیلنے کے لیے خالی خانے پر ٹیپ کریں۔',
  'Three in a row wins on 3×3': '3×3 پر لگاتار تین جیتتے ہیں',
  'Get three marks in a row, column or diagonal before the other player.':
      'دوسرے کھلاڑی سے پہلے قطار، کالم یا ترچھی لائن میں تین نشان بنائیں۔',
  'Five in a row wins on 8×8': '8×8 پر لگاتار پانچ جیتتے ہیں',
  'The big board needs five in a row (or four, if you choose it). Pinch to zoom on a phone.':
      'بڑے بورڈ پر لگاتار پانچ چاہئیں (یا چار، اگر آپ چنیں)۔ فون پر بڑا کرنے کے لیے چٹکی لیں۔',
  'Play your way': 'اپنی مرضی سے کھیلیں',
  'Play a friend on one device, the computer from Easy to Expert, or online with a room code.':
      'ایک ڈیوائس پر دوست کے ساتھ، آسان سے ماہر تک کمپیوٹر کے ساتھ، یا روم کوڈ سے آن لائن کھیلیں۔',
  'Next': 'آگے',
  'Skip': 'چھوڑیں',
  "Let's play": 'چلیں کھیلیں',
};
