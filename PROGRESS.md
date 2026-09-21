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
- Paths World view. You in the middle, paths as orbs, quests and practices as twigs. List still there.
- Blood and brass palette (`Ink`). Dark only.
- A ticked milestone is a fact. Second tap edits the day or confirms taking the tick back.
- The words: in-app cheat sheet. Settings and New path.
- Practices have a frequency on the same cue. World glow hops through You. Orbs stay on their twigs when names show. Build 0.17 (23).

Blocked.

- Nothing.

Next.

1. On the Mac, `git pull`, `xcodegen generate`, open the project, Cmd+R. Check Settings says `Version 0.17 (23)`. Select a path: quests stay on their twigs.
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
- 2026-09-13. Today: swipe right is done; tap confirms on the row. Build 0.12 (12). Next: pull, swipe one, tap one.
- 2026-09-13. Today title pinned; sort section Kind / Path / When. Build 0.13 (13). Next: pull, confirm the title, try the sorts.
- 2026-09-13. Today title lives in the page. Sort is Quests / Practice / Path / When. Build 0.14 (14). Next: pull, look above the sort.
- 2026-09-13. Today clock ticks; pin stays; date shrinks. Build 0.15 (15). Next: pull, scroll, watch the seconds.
- 2026-09-13. Centered clock, neuron quests per path, Path sort gone. Build 0.16 (16). Next: pull, look at Quests.
- 2026-09-13. Missing return in DueNeuronLayout. Build 0.16 (17). Next: pull, generate, run.
- 2026-09-13. Revert Today Quests/Practice to the list. Build 0.16 (18). Next: pull, open Quests.
- 2026-09-13. Practice frequency on the cue. World twigs. Build 0.17 (19). Next: pull, set a practice to every 3 days, look at World.
- 2026-09-13. World glow is a tap selection from You. Build 0.17 (20). Next: pull, tap a path, tap You.
- 2026-09-13. Glow retracts to You then out. Quest names only when the path is selected. Build 0.17 (21). Next: pull, switch paths.
- 2026-09-13. Drop World milestone rings. Build 0.17 (22). Next: pull, pinch: only paths and twigs.
- 2026-09-13. Pin World orbs to branch tips so names do not lift them. Build 0.17 (23). Next: pull, select a path.

- 2026-09-21. Local build 96 changes add the Today path-filter overflow triangle and keep long selected names on one line with an ellipsis and a stable filter width. Swift syntax parsed on Linux; iOS layout still needs checking on the Mac or phone.
- 2026-09-21. Build 97 lets a routine log row open an Undo completion confirmation in Today or path detail. Undo removes that entry, restores the remaining latest completion date, and persists it. Today keeps Recently visible when nothing is due. Three Store regression tests passed on Linux against the actual Store with unused Apple bookmark and draft-creation APIs stubbed. Swift syntax checks passed; iOS interaction remains unverified. Push is pending explicit remote/branch approval after automatic review blocked it.

- 2026-09-21. Build 98 keeps Today sort controls below the Out/path-filter row. The selected path uses the remaining row width and wraps to show its full name. Swift syntax and diff checks passed; iPhone layout still needs visual verification.

- 2026-09-21. Build 99 makes Today’s Recently section secondary with muted, smaller text, unboxed checkmarks, and clear row backgrounds. Routine rows retain a 44-point minimum height and show a quiet undo icon. Swift syntax and diff checks passed; iPhone appearance remains unverified.

- 2026-09-21. Build 100 passes Today’s selected filter path to the top-right Capture button. All paths keeps the existing default selection. Verified the request-to-picker code path and Swift syntax; iPhone interaction remains unverified.

- 2026-09-21. Build 101 preselects Capture kind from Today’s Quests or Routine selection. When supplies no override and keeps the Quest default. Selected path prefill remains. Swift syntax and diff checks passed; iPhone interaction remains unverified.

- 2026-09-21. Build 102 adds Monthly routines with a 1–31 day picker in Capture and Edit. Shorter months use their last day; the selected date overrides role day restrictions. Cue JSON remains backward compatible. All 77 engine tests passed, including five monthly regression tests. App Swift syntax passed; iPhone picker layout remains unverified.

- 2026-09-21. Build 103 expands Today sort buttons across the row with 44-point height and Quest/Routine icons. List items show those icons only in When mode. Selected-button icons use the dark foreground for contrast. Swift syntax and diff checks passed; iPhone layout remains unverified.

## How to keep this file true

At the end of a session, add one line to the session log and update the Status section if anything moved between Done, Blocked, and Next. Put the reasoning behind a choice in `DECISIONS.md`, not here.

## Release ritual

Every push that touches `App/` bumps `CURRENT_PROJECT_VERSION` in `project.yml` by one. The report to the owner names the build to expect, and the owner checks it at the bottom of Settings ("Version 0.3 (3)") before judging anything else. A different number means the Mac has not pulled and regenerated. Current build: 23.
