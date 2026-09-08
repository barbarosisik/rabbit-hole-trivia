# macOS native background-mode handoff

## Goal

Keep the existing browser trivia game, and add a native macOS version of the background experience. This repository contains the working Windows implementation as a behavioral reference; it contains no native macOS project yet.

## User-requested experience

1. Open the game and choose normal play or **Play from background**.
2. Background mode closes the main window but keeps the app running.
3. Wait 15 minutes, then show a small unobtrusive prompt near the bottom-right edge of the screen.
4. Clicking it expands a panel upward, asks for a category, and fetches one question in that category.
5. Selecting an answer reveals the correct answer, waits briefly, and fades the panel away.
6. Wait another 15 minutes and repeat until paused or quit.

The Windows version also has 5/30/60-minute options, a Question now action, Pause/Resume, a full-round shortcut, and Quit. It does not launch at login. Preserve those choices unless deliberately changing the product behavior.

## Boundaries to preserve

- Do not embed, download, or maintain a question dataset.
- Keep API responses and answers only in memory; discard after use.
- Fetch only when needed, handle network failures, and respect rate limiting.
- Do not install startup persistence by default.
- Keep the background process discoverable through a menu-bar/tray control with Pause and Quit.
- Do not steal keyboard focus when a reminder first appears.
- Do not accumulate a backlog of missed reminders while asleep or paused.
- Keep question-provider attribution and its CC BY-SA 4.0 license link.

## Code map

- `Rabbit Hole/game.html`: portable browser UI and gameplay; no build step.
- `Rabbit Hole/RabbitHole.ps1`: Windows-only main-window and tray implementation. Useful functions are `Schedule-Next`, `Show-Reminder`, `Expand-Popup`, `Fetch-Question`, `Poll-Question`, `Show-Question`, `Submit-Answer`, `Dismiss-Popup`, and `Stop-Game`.
- `Rabbit Hole/fetch-question.cjs`: one-question API request helper. A native port can replace this helper with native networking while preserving in-memory-only handling.

Category IDs used by both modes: gaming 15, mythology 20, computers 18, politics 24, history 23, sports 21, and science 17. Everything omits the category parameter. Current API documentation: https://opentdb.com/api_config.php

Current desktop timings: 15-minute default interval; 45-second ignored teaser lifetime; five-minute abandoned expanded-panel lifetime; 12-second answer display, followed by fade. The reminder interval restarts after dismissal. Background mode has no question timer or score history.

## Port validation checklist

- Launch normal mode and background mode independently.
- Test Question now before waiting through a real scheduled interval.
- Check category selection, answer feedback, long-question scrolling, and fade.
- Exercise offline, timeout, and rate-limit cases without blocking the UI.
- Check sleep/wake, multiple monitors, screen edges, full-screen apps, and notification preferences.
- Verify Pause, Resume, Quit, and duplicate-launch handling.
- Confirm no question files, cache, logs containing questions, or saved datasets are produced.
- Test the browser game on macOS as well as the native background UI.

This is a handoff specification, not a claim that these behaviors have been implemented or tested on macOS.
