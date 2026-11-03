# TicTacToe Arena

A cross-platform 3×3 and 8×8 Tic-Tac-Toe game with a Game AI, player accounts and a cloud database.
Built by Team Alpha for Software Engineering, Fall 2026 (PUCIT).

**Team:** Muhammad Shahab (BSDSF24A032), Daniyal Usman (BSDSF24A025), Muhammad Samiullah (BSDSF24A013)
**Task board:** Jira project `SCRUM` (Kanban)
**Planned stack:** Flutter + Firebase, pending team confirmation

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
