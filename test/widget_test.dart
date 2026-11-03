import 'package:flutter_test/flutter_test.dart';
import 'package:tictactoe_arena/main.dart';

void main() {
  testWidgets('app starts and shows its name', (tester) async {
    await tester.pumpWidget(const TicTacToeArenaApp());
    expect(find.text('TicTacToe Arena'), findsOneWidget);
  });
}
