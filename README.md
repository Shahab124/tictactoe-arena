# TicTacToe Arena

A cross-platform 3×3 and 8×8 Tic-Tac-Toe game with a Game AI, player accounts and a cloud database.
Built by Team Alpha for Software Engineering, Fall 2026 (PUCIT).

**Team:** Muhammad Shahab (BSDSF24A032), Daniyal Usman (BSDSF24A025), Muhammad Samiullah (BSDSF24A013)
**Task board:** Jira project `SCRUM` (Kanban)
**Stack:** Flutter + Firebase

## Project structure

- `lib/`: the Game Platform app
- `packages/game_engine/`: game rules
- `packages/game_ai/`: the Game AI, kept separate so groups can exchange components

## Build and run

You need [Git](https://git-scm.com/downloads) and [Flutter](https://docs.flutter.dev/get-started/install) 3.47.9 (the version our CI uses; it includes Dart). Run `flutter doctor` to check the install.

```bash
git clone https://github.com/Shahab124/tictactoe-arena.git
cd tictactoe-arena
flutter create --platforms=android,ios,web,windows --project-name tictactoe_arena .
flutter pub get
flutter run -d chrome
```

- `flutter create` only adds the platform folders (`android/`, `web/`, ...), which are not stored in the repo. It does not change our code.
- To run on an Android phone, turn on USB debugging, plug it in and use `flutter run` instead of `flutter run -d chrome`. To build an installable APK: `flutter build apk --release`.
- No Firebase setup is needed. The app connects to our Firebase project through `lib/firebase_options.dart`. You can sign up with an email, or choose **Play as guest** to play without an account.

Run the tests:

```bash
flutter test
cd packages/game_engine && dart pub get && dart test && cd ../..
cd packages/game_ai && dart pub get && dart test && cd ../..
```

GitHub runs these tests automatically on every pull request.

## Game AI interface

The Game AI is the Dart package `packages/game_ai`. It has no database, network or Flutter code, so any Dart or Flutter platform can use it. It has one function:

```dart
Map<String, Object> requestMove(Map<String, dynamic> request)
```

You give it the board and it returns one legal move. It never throws and never changes your board.

### Use it in your project

Copy the `packages/game_ai` folder into your project and add it to your `pubspec.yaml`:

```yaml
dependencies:
  game_ai:
    path: packages/game_ai
```

```dart
import 'package:game_ai/game_ai.dart';

final reply = requestMove({
  'board': [
    ['X', 'X', ''],
    ['', 'O', ''],
    ['', '', ''],
  ],
  'winLength': 3,
  'sideToMove': 'O',
  'difficulty': 'hard',
});
if (reply.containsKey('error')) {
  print('${reply['error']}: ${reply['message']}');
} else {
  print('AI plays row ${reply['row']}, column ${reply['col']}'); // row 0, column 2
}
```

### Request

| Field | Type | Allowed values |
| --- | --- | --- |
| `board` | list of rows | 3 rows of 3 cells, or 8 rows of 8 cells. Each cell is `"X"`, `"O"` or `""` (empty). |
| `winLength` | number | `3` on a 3×3 board; `4` or `5` on an 8×8 board. |
| `sideToMove` | text | `"X"` or `"O"`: the mark the AI plays. |
| `difficulty` | text | `"easy"`, `"medium"`, `"hard"` or `"expert"`. Optional; `"medium"` if left out. |

**Board format:** `board[row][col]`, counted from 0. Row 0 is the top row and column 0 is the left column. The number of X and O marks may differ by at most one.

```json
{
  "board": [["X", "X", ""], ["", "O", ""], ["", "", ""]],
  "winLength": 3,
  "sideToMove": "O",
  "difficulty": "hard"
}
```
<!--  functional and  non-functional requirements in D3. -->
<!--  Responsible for Android and web testing and quality assurance. -->
### Response

A move, using the same row and column numbering as the board:

```json
{"row": 0, "col": 2}
```

or an error:

```json
{"error": "INVALID_SIDE", "message": "sideToMove must be \"X\" or \"O\"."}
```

### Error codes

| Code | When |
| --- | --- |
| `INVALID_BOARD` | The board is not a list of 3 or 8 rows, a row has the wrong length, or the X and O counts differ by more than one. |
| `INVALID_CELL` | A cell is not `"X"`, `"O"` or `""`. |
| `INVALID_WIN_LENGTH` | `winLength` is not allowed for this board size. |
| `INVALID_SIDE` | `sideToMove` is not `"X"` or `"O"`. |
| `INVALID_DIFFICULTY` | `difficulty` is not one of the four levels. |
| `GAME_OVER` | Someone has already won, or the board is full. |

`message` is a short English sentence that explains the problem. Check `error`, not `message`, in your code.

### Difficulty levels

- `easy`: a random empty cell.
- `medium`: wins if it can, blocks your win, otherwise random.
- `hard`: never loses on 3×3. On 8×8 it plays like `medium`.
- `expert`: the strongest level on 8×8, and answers well inside 2 seconds. On 3×3 it plays like `hard`.

### Try the example calls

`packages/game_ai/example/main.dart` makes two normal calls and one call for every error code:

```bash
cd packages/game_ai
dart pub get
dart run example/main.dart
```

It prints:

```text
{"row":0,"col":2}
{"row":3,"col":3}
{"error":"INVALID_BOARD","message":"The board must have 3 or 8 rows."}
{"error":"INVALID_CELL","message":"Cell (0, 1) must be \"X\", \"O\" or \"\", not \"Z\"."}
{"error":"INVALID_WIN_LENGTH","message":"Win length must be one of [4, 5] on a 8×8 board."}
{"error":"INVALID_SIDE","message":"sideToMove must be \"X\" or \"O\"."}
{"error":"INVALID_DIFFICULTY","message":"difficulty must be one of easy, medium, hard, expert."}
{"error":"GAME_OVER","message":"The game is already won or the board is full."}
```

## Download the app

Every pull request and every merge to `main` also builds a release Android APK and the web version. Open the **Actions** tab on GitHub, pick the latest **CI** run on `main`, and download `tictactoe-arena-apk` or `tictactoe-arena-web` under **Artifacts** (you must be signed in to GitHub). Unzip the APK artifact and open `app-release.apk` on an Android phone to install it (allow installs from unknown sources). Each build has a new signature, so uninstall the old version before installing a new one.

## How we work

Never commit directly to `main`.

1. In Jira, pick a ticket assigned to you and move it to **In Progress**.
2. Get the latest code and create a branch named after the ticket:

   ```bash
   git checkout main
   git pull
   git checkout -b SCRUM-10-game-engine
   ```

3. Commit in small steps and put the ticket key in every message, then push:

   ```bash
   git add .
   git commit -m "SCRUM-10 Add win detection"
   git push -u origin SCRUM-10-game-engine
   ```

4. On GitHub, open a pull request with the ticket key in its title, then move the ticket to **In Review**.
5. A different team member reviews and approves it. The tests must pass.
6. Merge the pull request and move the ticket to **Done**.
