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

Install [Flutter](https://docs.flutter.dev/get-started/install), then from the repo root:

```bash
flutter create --platforms=android,ios,web,windows --project-name tictactoe_arena .
flutter pub get
flutter run -d chrome
```

Run the tests:

```bash
flutter test
cd packages/game_engine && dart pub get && dart test && cd ../..
cd packages/game_ai && dart pub get && dart test && cd ../..
```

GitHub runs these tests automatically on every pull request.

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
