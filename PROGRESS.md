# Progress

Read this file first at the start of every session. It says what the app is, where the work stands, and what comes next, so nobody has to explain the project again.

## What the app is

Life is a Game is a personal iOS app. The user writes Paths for things they want to get better at or finish (guitar, a lab project, a car repair) in their own words. Each Path has milestones the user ticks by hand and nodes, one-shot quests or repeatable practices, each with a cue for when it may surface. Once a day, when the cue fits (a free evening, a weekend morning), the app puts one node in front of the user as the objective. No points, no streaks, no scores, nothing to lose. Full spec in `docs/spec.md`.

## Where to read

- `docs/spec.md` says what phase 1 is and is not. One page.
- `docs/screens-and-flows.md` and `docs/copy-deck.md` say what the screens show and say.
- `DECISIONS.md` says why things are the way they are. Read it before proposing a change that undoes one.
- `README.md` says how to run the tests, view the mockups, and build for the phone.

## Status as of 2026-09-12

Done.

- Spec, screens, copy deck, three Today-screen mockups in `design/`.
- `Engine/` Swift package with the surfacing planner. 20 tests, 0 failures, run on the Linux laptop with `cd Engine && ../swift.sh test`.
- `App/` SwiftUI skeleton with onboarding, Today screen in three switchable styles, JSON storage, local notifications.
- Repo public at github.com/nabil144/life-is-a-game. GitHub Actions builds green on all three jobs (engine tests, Simulator screenshot, unsigned `.ipa`).
- First install on the iPhone, from Xcode on the Mac, 2026-09-12. Free Apple ID, so the signature lasts 7 days. Refresh by plugging the phone into the Mac and pressing Run again. Steps in `README.md`.
- New path form trimmed to a name and one milestone. Identity, kind, glyph, and first quests sit under a collapsed More row with defaults. Templates are a one-tap menu.
- Paths by talking. `App/Sources/Views/TalkPathView.swift` over `App/Sources/Talk/PathModel.swift`, a cloud model with the owner's own API key (OpenAI or Anthropic), key in the keychain. Setup once after onboarding or in Settings > New paths. The New path form offers "Talk it through instead" once a key is saved. Deployment target is iOS 26. CI proves compile and launch only; the runner has no key. The conversation has not run on a real phone yet. The owner said the key is not working; left for later.
- A copy of the world can live in Files. Settings > Your data, a one-time sheet after the first Path, restore on onboarding and on an empty Paths list. Full `world.json` (ticks and log), not drafts.
- The path itself is editable. Path detail header or Edit opens This path: name, identity, kind, glyph, deadline, milestone words and order.
- Paths World view. You in the middle, paths as orbs, pinch for milestones. List still there.
- Blood and brass palette (`Ink`). Dark only.
- A ticked milestone is a fact. Second tap edits the day or confirms taking the tick back.
- The words: in-app cheat sheet. Settings and New path.
- Today lists due quests and practices. Done confirms and removes for the day. Practices return with their cue. Build 0.11 (11).

Blocked.

- Nothing.

Next.

1. On the Mac, `git pull`, `xcodegen generate`, open the project, Cmd+R. Check Settings says `Version 0.11 (11)`. Today should list quests and practices, not paths. Tap one, confirm Done, it leaves.
2. Live with the Today screen for the prototype weeks. Switch styles A, B, C from Settings and note which one survives. Same for the two ways of creating a path, form and talk. One survives.
3. Load the owner's own paths from `testdata/owner-paths.json` through import once it exists (phase 2 item, see spec).
4. File the 503 null-deref against Splice (`splice login` on the Linux laptop gets an HTTP 503 from Apple and segfaults) so the Linux pipeline can take over the 7-day refreshes later.

## Session log

One line per session, newest at the bottom. Date, what changed, what is next.

- 2026-09-11. Spec, mockups, engine, app skeleton, CI. Two cloud builds, second green. Next: install on the phone.
- 2026-09-12. Tried `splice login` on Linux. Fixed the TLS root, hit the 503 crash, gave up on Linux for the first install. Added this file. Next: Xcode on the Mac.
- 2026-09-12. Xcode on the Mac worked (iOS platform download, developer agreement acceptance, Developer Mode, Run). App runs on the phone. Owner created the first Path and found the form heavy, asked for a chat-style LLM-guided creation flow. Next: decide on that (form trim, chat prototype, cloud or on-device model).
- 2026-09-12. Decided and built. Form trimmed, paths by talking on device (Foundation Models, iPhone 15 Pro), iOS 26 target, decisions in `DECISIONS.md`. Five commits, CI green. Next: pull on the Mac, run, try the talk flow on the phone.
- 2026-09-12. Owner ran it. Three reports: first Path gone (second app from a reverted bundle id, data still on the phone in the first icon), no chat found (toggle buried in Settings), quests not editable (never were). Fixed all three, bundle id pinned to `com.nabil`, Store keeps undecodable files, form offers the talk, nodes tap to edit. Next: pull, run, delete the empty icon, talk a path.
- 2026-09-12. Owner pressed Cmd+R without pulling and saw the old build. Added a visible build number in Settings (0.3 (3)) and the release ritual above. New path form always shows either the Talk row or one reason line. Next: pull, regenerate, run, confirm "Version 0.3 (3)" in Settings.
- 2026-09-12. Owner reversed the on-device choice: bring your own key. Cloud model over `URLSession`, OpenAI or Anthropic, key in the keychain, one-time setup sheet after onboarding and the same screen in Settings, five error sentences. Foundation Models removed. Build 0.4 (4). Next: pull, run, add a key on the sheet, talk a path.
- 2026-09-12. Owner: key can wait; losing paths on each new version would make the app unused. Files-folder copy of `world.json`, restore from a file, one-time pick sheet. Build 0.5 (5). Next: pull, run, confirm version, pick a folder.
- 2026-09-12. Path itself is editable (This path sheet). Build 0.6 (6). Next: pull, run, edit a path.
- 2026-09-12. Paths World view (skill-tree atlas, list stays). Build 0.7 (7). Next: pull, run, pinch around.
- 2026-09-13. Blood and brass. Build 0.8 (8). Next: pull, run, look at World and Today.
- 2026-09-13. Milestone facts: no silent untick, editable day. Build 0.9 (9). Next: pull, run, tap a ticked milestone.
- 2026-09-13. The words cheat sheet. Schema unchanged. Build 0.10 (10). Next: pull, open The words.
- 2026-09-13. Today is the due list. Build 0.11 (11). Next: pull, do one quest and one practice.

## How to keep this file true

At the end of a session, add one line to the session log and update the Status section if anything moved between Done, Blocked, and Next. Put the reasoning behind a choice in `DECISIONS.md`, not here.

## Release ritual

Every push that touches `App/` bumps `CURRENT_PROJECT_VERSION` in `project.yml` by one. The report to the owner names the build to expect, and the owner checks it at the bottom of Settings ("Version 0.3 (3)") before judging anything else. A different number means the Mac has not pulled and regenerated. Current build: 11.
