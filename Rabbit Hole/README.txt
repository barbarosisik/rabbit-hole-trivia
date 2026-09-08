RABBIT HOLE

Double-click "Play Rabbit Hole.cmd" in the parent folder.
Choose "Play now" for the browser game, or "Play from background" for tray mode.
You can also open game.html directly for the browser game.
Internet is required to fetch each round. No installation, account, or API key is needed.

Choose a topic, difficulty and pace. Answer using the mouse or keys 1-4.
Press Enter after an answer to continue. You get one 50/50 lifeline per round.
Easy answers earn 100 points, medium 150, hard 200. Consecutive correct answers
add 25 points per streak step, up to a 125-point bonus. There is no speed bonus.

Questions and scores are kept only in JavaScript memory. This game uses no
localStorage, cookies, question files, analytics, or service worker. API requests
use cache: no-store. Your browser may still keep its ordinary browsing history.
Leaving a round discards its questions. Closing the tab stops the game.

Everything draws from all Open Trivia DB categories. Computers & code uses its
computer-science category and includes broader computing trivia. Politics and
other questions are community supplied and may be dated or imperfect.
Wikipedia links are answer searches for further reading, not verified citations.

Questions: https://opentdb.com/ (CC BY-SA 4.0)
License: https://creativecommons.org/licenses/by-sa/4.0/
The game shuffles and displays API questions without maintaining a local dataset.

BACKGROUND MODE

1. Open Play Rabbit Hole.cmd, leave the interval at 15 minutes (or choose another).
2. Click Play from background. The launcher closes and a tray icon appears.
3. After the interval, a small custom notification appears above the right side
   of the primary monitor's taskbar. It does not take focus from your work.
4. Click the prompt to expand it upward, then choose a category and answer.
5. The correct answer stays visible for 12 seconds, then the popup fades away.
   The next interval starts when it disappears.

Right-click the tray icon (it may be under the hidden-icons arrow):
- Question now: try a popup immediately. Double-clicking the icon does this too.
- Pause reminders / Resume reminders.
- Play a full round: open the browser game while reminders remain running.
- Quit Rabbit Hole: stop the background process completely.

Dismiss with x or Escape. Ignored small prompts disappear after 45 seconds;
abandoned expanded prompts disappear after five minutes. No reminder backlog
accumulates. The computer must be awake and your Windows session running.
This is a custom tray popup, not a Windows Notification Center notification;
it does not automatically follow Windows Do Not Disturb settings. Use Pause.
Questions are fetched only after you choose a category and discarded on dismissal.
Settings last only for the current run. Closing the browser does not stop tray mode.

The game is tucked away in this folder; it does not run at startup or install a service.
Background mode uses Windows PowerShell, Windows desktop UI libraries, and the
Node.js installation already on this computer. Node uses the system certificate
store to fetch each question in a short-lived hidden process. Nothing is installed.
The launcher does not change your execution policy.
To remove it, delete the Rabbit Hole folder and Play Rabbit Hole.cmd.
