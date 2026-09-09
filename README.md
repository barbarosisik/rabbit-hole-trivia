# Rabbit Hole

A little curiosity break: gaming, mythology, computers, politics, history, sports, science, or a mix of everything.

[![Download for Mac](https://img.shields.io/badge/Download_for_Mac-Intel_macOS_13%2B-d6fa83?style=for-the-badge&logo=apple&logoColor=17200c)](https://github.com/barbarosisik/rabbit-hole-trivia/releases/latest/download/Rabbit-Hole-macOS.zip)
[![Download for Windows](https://img.shields.io/badge/Download_for_Windows-ZIP-0078D4?style=for-the-badge)](https://github.com/barbarosisik/rabbit-hole-trivia/releases/latest/download/Rabbit-Hole-Windows.zip)

**This repository is private. Sign in to a GitHub account with access to download.** The buttons download ready-packaged ZIP files from the [latest release](https://github.com/barbarosisik/rabbit-hole-trivia/releases/latest).

## Mac: download, unzip, play

1. Click **Download for Mac** above and open the downloaded ZIP.
2. Open **Rabbit Hole.app**. You can keep it anywhere or drag it to Applications.
3. Choose **Play now** or **Play from background**.

The download is built for **Intel Macs**, including the Mac used to develop and test it. It requires macOS 13 or later and internet access. Apple Silicon users can build a native app from source with the command below; that architecture has not been tested. No Node.js, Python, or API key is needed for the Mac app.

The app is locally signed, but not Apple-notarized. If macOS blocks this trusted download, first try opening it, then use **System Settings → Privacy & Security → Open Anyway**. See [Apple’s opening instructions](https://support.apple.com/en-us/102445). You do not need to disable Gatekeeper.

To pause or stop background mode, click **↘ in the menu bar**, then **Pause reminders** or **Quit Rabbit Hole**. The same menu offers **Play now**, **Question turn now**, and 5/15/30/60-minute intervals.

## Windows: download, extract, play

1. Click **Download for Windows** above.
2. Right-click the ZIP and choose **Extract All**. Keep the extracted files together.
3. For background mode, install [Node.js](https://nodejs.org/) **24 or newer** if it is not already installed.
4. Double-click **Play Rabbit Hole.cmd**, then choose a mode.

The Windows ZIP contains the launcher and game scripts, not a standalone EXE. Normal play only needs a modern browser and internet; you can also open `Rabbit Hole/game.html` directly. Background mode needs Windows PowerShell 5.1 and Node.js. The launcher respects your existing PowerShell execution policy.

Right-click the Rabbit Hole **system-tray icon** (possibly under the hidden-icons arrow) for **Question turn now**, **Pause/Resume reminders**, **Play a full round**, or **Quit Rabbit Hole**.

## Two ways to play

**Play now:** a ten-question round with category selection, difficulty, chill or 20-second timed play, scoring, streak bonuses, and one 50/50 lifeline. Use keys **1–4** to answer and **Enter** to continue.

**Play from background, on both Mac and Windows:**

1. The main window closes and the menu-bar/tray app stays running.
2. Every **15 minutes** by default, a small prompt appears near the bottom-right without stealing focus.
3. Click it and choose a category. The app fetches **three questions in one request**, held only in memory.
4. Answer them one at a time, with **1/3, 2/3, 3/3** progress. Each answer reveals the correct choice. Click **Next** between questions.
5. After the third answer, the result and turn score remain for **eight seconds**, then fade away. **Done** closes sooner.
6. The next interval starts after the turn closes.

Dismiss with **×** or **Escape** at any time. Ignored prompts expire after 45 seconds; abandoned expanded turns after five minutes. There is no launch-at-login entry or background service. Settings and scores reset when you quit. These are custom desktop prompts; use **Pause** when you do not want interruptions.

On Mac, normal play suspends reminders until its window closes. Sleep/wake discards an open turn and starts one fresh interval without a backlog. Windows retains its tray/browser behavior: opening a full browser round does not pause reminders.

## Questions and privacy

Questions come from [Open Trivia DB](https://opentdb.com/), licensed [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/). The game shuffles and displays their answers. Community questions can be imperfect or dated.

**No question dataset, downloaded responses, question history, scores, or settings are saved.** Questions are fetched only when needed and discarded after the round or turn. The Mac uses ephemeral networking and a nonpersistent web view; Windows passes its response through an in-memory pipe. Browser play uses no local storage, cookies, analytics, or service worker. Ordinary browser history is separate. Wikipedia links are further-reading searches, not verified sources.

Network failures offer a retry. Requests respect the provider’s rate limit; wait a few seconds before retrying a busy service.

## Build and test from source

The GitHub source ZIP does not contain the compiled Mac app; use the Mac download button for that.

On a Mac with Apple Command Line Tools installed:

```sh
./macOS/build.sh
open "Rabbit Hole.app"
```

This builds for the Mac’s own architecture. The app is placed at the repository root.

```sh
# Browser mechanics (Node.js)
node tests/check-game.cjs

# Mac window, gameplay, lifecycle, and network-error tests
"./Rabbit Hole.app/Contents/MacOS/RabbitHole" --self-test

# Optional live questions, held only in memory
"./Rabbit Hole.app/Contents/MacOS/RabbitHole" --online-test
```

Windows PowerShell:

```powershell
powershell.exe -NoProfile -STA -File "Rabbit Hole\RabbitHole.ps1" -SelfTest
```

GitHub Actions checks browser gameplay and Windows three-question turns. Mac gameplay, live requests, fade, scheduling, pause/resume, and relaunch were tested on macOS 26.6.2 Intel. Actual hardware sleep, multiple monitors, full-screen transitions, and a full 15-minute wait remain untested. See [Mac validation](docs/MACOS-VALIDATION.md).
