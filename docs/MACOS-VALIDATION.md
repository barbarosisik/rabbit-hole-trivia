# Mac build and validation

Implementation date: 2026-09-09. Terminal verification returned `Darwin`, macOS **26.6.2** (25G83), and `x86_64`. Built locally with Apple Swift 6.3.3, using a macOS 13 deployment target. The runnable bundle is `Rabbit Hole.app` at the project root; it requires no downloaded runtime or package dependencies.

## Reproduce

```sh
./macOS/build.sh
"./Rabbit Hole.app/Contents/MacOS/RabbitHole" --self-test --screenshots
"./Rabbit Hole.app/Contents/MacOS/RabbitHole" --online-test
open "./Rabbit Hole.app"
```

The tests open real AppKit/SwiftUI windows and a WKWebView, call the same actions used by the controls, and exit through the app's Quit action. Run them in an unlocked graphical Mac session. The offline suite uses generated mechanics-only placeholders; it is not a question dataset. Optional screenshots contain only synthetic text or the setup screen and go to `$TMPDIR/rabbit-hole-qa/`. Live questions are never written to screenshots, logs or response files.

## Verified by the Mac harness

- 15-minute production default, shortened one-shot scheduling, prompt appearance without activation/key focus, and upward expansion with a fixed bottom edge.
- All three question positions, answer feedback, duplicate-answer rejection, base points and streak bonuses, automatic third-answer result, eight-second result expiry, actual fade, question clearing, and a new interval starting after closure.
- Pause/Resume, a manual turn while paused, dismissal during an in-flight fetch, repeated sleep/wake handler calls, and suspension of reminders while normal play is open.
- Original ten-question game running inside WKWebView: 50/50, complete round, scoring/streaks, wrong-answer feedback, timed expiry, retry state, and memory clearing.
- Native networking with caching/cookies disabled. Synthetic API codes 1/2/5, HTTP 429 with bounded retries, an incomplete batch, offline failure, and timeout handling.
- Native window layout screenshots: launcher, compact prompt, category selection, each answer/result, long wrapping text, and original normal-play setup.
- Test teardown restores 900 seconds, removes the panel and web view, cancels tasks/timers and exits. Settings are not persisted, so every ordinary launch starts at 15 minutes.

## Live API checks

Both live paths passed on this Mac: a category-specific batch of three questions through the background application, all three answers and automatic result/fade, and a ten-question easy normal round through the WKWebView native bridge. Both suites exited successfully through Quit; the online suite relaunched after the offline suite. No live question text was printed or saved.

## Final bundle checks

The final bundle passed the offline suite again, including disabled state restoration, long-answer scrolling, and wrong-answer feedback in background mode. `codesign --verify --strict` and plist validation passed. The embedded HTML matches the source. The executable is Mach-O x86_64 with a macOS 13.0 minimum deployment target.

Launched `Rabbit Hole.app` using macOS `open` (the same Launch Services path used by Finder). A second direct executable launch exited successfully; `pgrep -x RabbitHole` confirmed exactly one remaining process, launched independently by macOS. The app was left running at its chooser with the default 15-minute interval. The initial local delivery made no commits or pushes; the follow-up GitHub release is authorized separately.

## Implementation notes

The main game has one compatibility change: it uses the Mac host's `window.rabbitHoleFetch` when present and the original browser `fetch` otherwise. Native requests share a 5.5-second reservation gate. The initial Mac port preserved the Windows implementation. The follow-up release also updates Windows to three-question turns, with its own PowerShell self-test in GitHub Actions. A newline-only difference in `tests/check-game.cjs` was already present immediately after cloning and was preserved.

The Mac uses an AppKit status item and nonactivating NSPanel with SwiftUI content. Both the native network session and normal game's website data store are ephemeral. Window and application-state restoration are disabled. The only app-owned file created at runtime is an empty per-user instance lock in the temporary directory; it holds no game data. No launch agent, login item, question dataset, score file or settings file is installed.

Open Trivia DB documents a five-second per-IP request limit and supplies questions under CC BY-SA 4.0: https://opentdb.com/api_config.php. Attribution and the license link remain in both game modes.

## Limits of this validation

Automated interaction and screenshots do not replace a full manual accessibility/VoiceOver review. Actual hardware sleep, lock/unlock, multiple monitors, Space/full-screen transitions, and an uninterrupted real 15-minute wait were not performed; the lifecycle handlers and shortened timer were exercised instead. The custom panel is not a Notification Center notification and does not automatically follow Focus settings; use Pause. Windows native UI cannot be executed on this Mac. The build is locally ad-hoc signed, not notarized or packaged for distribution to other Macs. Earlier macOS releases and Apple Silicon were not tested.
