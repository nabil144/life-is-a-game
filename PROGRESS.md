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

Blocked.

- First install on the iPhone. `splice login` on the Linux laptop fails. The Apple Root CA gap is fixed (wrapper in `~/.bashrc`), but Apple's login endpoint returns HTTP 503 and splice segfaults on the reply. Decision on 2026-09-12: do the first install from Xcode on the Mac instead. Steps in `README.md`.

Next.

1. On the Mac, install from Xcode and open the app on the phone.
2. Live with the Today screen for the prototype weeks. Switch styles A, B, C from Settings and note which one survives.
3. Load the owner's own paths from `testdata/owner-paths.json` through import once it exists (phase 2 item, see spec).
4. File the 503 null-deref against Splice so the Linux pipeline can take over refreshes later.

## Session log

One line per session, newest at the bottom. Date, what changed, what is next.

- 2026-09-11. Spec, mockups, engine, app skeleton, CI. Two cloud builds, second green. Next: install on the phone.
- 2026-09-12. Tried `splice login` on Linux. Fixed the TLS root, hit the 503 crash, gave up on Linux for the first install. Added this file. Next: Xcode on the Mac.

## How to keep this file true

At the end of a session, add one line to the session log and update the Status section if anything moved between Done, Blocked, and Next. Put the reasoning behind a choice in `DECISIONS.md`, not here.
