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

## User guide

### 1. Get the app

**Android phone**

1. On GitHub, open the **Actions** tab, click the latest **CI** run on `main` with a green tick, and download **tictactoe-arena-apk** under **Artifacts** (you must be signed in to GitHub).
2. Unzip it and copy `app-release.apk` to the phone.
3. Open the file on the phone. If Android asks, allow installs from this source (Settings → Apps → Special access → Install unknown apps), then tap **Install**.

**Web browser**

Follow [Build and run](#build-and-run) above and finish with `flutter run -d chrome`. The game opens in Chrome. Or download **tictactoe-arena-web** from the same CI run and serve the unzipped folder with any static web server.

Android and web are the versions we build and test. `flutter run -d windows` may also work if you have Visual Studio with the C++ desktop tools, but we have not tested it.

### 2. Sign in

- **Sign up** with an email and password, or **Continue with Google**.
- **Play as guest** to play on this device without an account. Guests cannot play online. To make an account later, tap **Sign up** at the top of the home screen; games played as a guest move to the new account.
- **Forgot password?** sends a reset email to the address you typed.

The first time the app opens, a short **How to play** tutorial appears before sign-in. Tap **Next** or **Skip**. You can open it again from **Settings → How to play**.

### 3. Play

On the home screen pick **Classic 3×3** or **Big 8×8**. On the setup screen choose:

- **Mode:** **Two players** (take turns on one device) or **Computer**.
- **Difficulty** (Computer only): **Easy**, **Medium**, **Hard** or **Expert**. Hard never loses on 3×3.
- On 8×8, **4 in a row** or **5 in a row** wins. Pinch the board to zoom on a phone.
- **You play** X or O, **Who starts**, and **Match** (**Single**, **Best of 3** or **Best of 5**).

Tap **Start game**. Tap an empty cell to place your mark. Against the computer you can use **Hint**, **Undo** and, after the game, **Replay** to step through the moves with the best and worst ones marked. **Rematch** plays again with the same options. If you leave a game unfinished, the setup screen offers **Continue unfinished game**, also on another device signed in to the same account.

**Online (needs an account and internet)**

Tap **Play online** on the home screen and pick **3×3** or **8×8**.

- **Create room** shows a 5-letter code. Send it to your friend; they type it and tap **Join room**. You are X, they are O.
- **Find a match** pairs you with a waiting player with a similar rating. The allowed rating gap grows the longer you wait. **Cancel** leaves the queue.
- Each turn has a 60-second limit. If the other player runs out of time, **Claim win** appears.
- **Leave (you lose)** ends the game as a loss. If the app closes by accident, open **Play online** again and tap **Rejoin game**.
- After the game, **Report** sends the player to the admins and **Block** stops you being matched with them again.
- Every online game is ranked. Your rating starts at 1200 and is shown on the **Play online** screen. **Leaderboards** has **All time** (highest rating) and **This week** (3 points per win, 1 per draw).

### 4. History, profile and settings

- **History & statistics**: your finished games, wins and win rate.
- **Profile**: username (must be unique), avatar, and **Delete account**.
- **Settings**: **Theme** (System, Light, Dark), **Skin** for the board and marks, **Sound**, **Vibration**, **Language** (English or اردو, right-to-left) and **Colour-blind friendly colours** (blue and orange). Settings follow your account to other devices.

### 5. Make someone an admin

1. The person signs up and signs in once.
2. In the [Firebase console](https://console.firebase.google.com/) open project `tictactoe-arena-9ece4` → **Authentication** → **Users** and copy their **User UID**.
3. Go to **Firestore Database**, open (or start) the collection `admins`, and add a document whose **Document ID** is that UID. It needs no fields; add any one field, for example `name`, if the console asks for one.
4. The person reopens **Play online** and sees **Admin dashboard**. It lists open reports; **Dismiss** closes a report and **Suspend** blocks that player from online games.

Only people with access to the Firebase project can add admins. The app has no way to make yourself an admin.

### 6. Known limits

- There is no friends list, so there is no friends leaderboard; only all-time and weekly.
- Online ratings are worked out on each player's device. The database rules check the game really finished and is counted once, but a determined cheater could send a wrong rating.
- The Android APK is signed with a new key on every build, so uninstall the old app before installing a newer APK.

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
