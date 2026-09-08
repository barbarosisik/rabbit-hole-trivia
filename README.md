# Rabbit Hole

A small personal trivia game for curiosity breaks: gaming, mythology, computers and code, politics, history, sports, science, or a mix of everything.

## Play on Windows

1. Clone or download this repository.
2. Double-click **Play Rabbit Hole.cmd**.
3. Choose **Play now** or **Play from background**.

**Play now** opens `Rabbit Hole/game.html` in your browser. Choose a topic, difficulty, and either a relaxed pace or a 20-second timer. Each round has ten questions, streak bonuses, and one 50/50 lifeline. Use keys 1–4 to answer and Enter to continue.

**Play from background** closes the launcher and stays in the system tray. Every 15 minutes by default, a small prompt appears above the right side of the primary monitor's taskbar. Click it to expand the category picker and question. After answering, the result stays visible for 12 seconds, then fades away. The next interval starts after dismissal. The launcher also offers 5-, 30-, and 60-minute intervals.

Right-click the tray icon (possibly under the hidden-icons arrow) for **Question now**, **Pause reminders**, **Play a full round**, or **Quit Rabbit Hole**. Double-click the icon for a question immediately. No startup entry or background service is installed.

The popup is custom desktop UI, not a Windows Notification Center notification. Use the tray's Pause option when you do not want interruptions. An ignored small prompt disappears after 45 seconds; an abandoned expanded prompt disappears after five minutes. The computer must be awake and the Windows session running.

### Requirements

- Browser mode: a modern browser and internet access; no build, account, or API key.
- Windows background mode: Windows PowerShell 5.1, Windows desktop UI libraries, and a Node.js version that supports `--use-system-ca` and built-in `fetch`. The existing Node installation on the development computer was used and tested. No packages are required.
- The launcher respects the computer's PowerShell execution policy. On another machine, downloaded scripts may require review/unblocking under its existing policy.

## Use on macOS

Open `Rabbit Hole/game.html` in a browser for the existing game. The browser version has not yet been tested on macOS.

The `.cmd` launcher and PowerShell/WPF tray application are **Windows-only**. A native macOS background mode is not implemented. See [the macOS handoff](docs/MACOS-HANDOFF.md) for the expected behavior, file map, and validation checklist.

## Data and attribution

Questions are fetched from [Open Trivia DB](https://opentdb.com/) on demand and are licensed [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/). The app shuffles and displays API answers. Community questions may be imperfect or dated; the computer-science category includes broader computing trivia.

No question dataset, API responses, question history, scores, or settings are saved by the game. Browser mode keeps the current round in JavaScript memory and uses no local storage, cookies, service worker, or analytics. Background mode fetches one question only after a category is chosen; its helper sends the response to the parent process through a pipe, without writing a file. Questions are discarded when their round or popup ends. Ordinary browser history is separate from game storage.

Wikipedia links in browser mode search for an answer; they are further-reading links, not verified sources for the question.

## Files

| File | Purpose |
| --- | --- |
| `Rabbit Hole/game.html` | Standalone browser game, styles, and logic |
| `Rabbit Hole/RabbitHole.ps1` | Windows launcher, tray lifecycle, popup, timers, and desktop checks |
| `Rabbit Hole/fetch-question.cjs` | Short-lived network helper using the system certificate store |
| `Play Rabbit Hole.cmd` | Opens the Windows launcher without a persistent console |
| `tests/check-game.cjs` | Browser logic checks with synthetic mechanics-only fixtures |

## Validation

Run commands from the repository root:

```sh
node tests/check-game.cjs
```

Windows desktop checks:

```powershell
powershell.exe -NoProfile -STA -File "Rabbit Hole\RabbitHole.ps1" -SelfTest
```

Optional live network check, fetching one question in memory:

```powershell
powershell.exe -NoProfile -STA -File "Rabbit Hole\RabbitHole.ps1" -SelfTest -OnlineTest
```

Verified on the development Windows computer: browser logic, WPF construction, reminder interval, answer generation and feedback, dismissal, memory clearing, pause, cleanup, and a live fetch through the background application. Full interactive visual QA and a real 15-minute end-to-end wait were not completed. macOS behavior remains unverified.
