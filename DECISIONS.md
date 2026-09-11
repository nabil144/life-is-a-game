# Decision trail

Local only. No git until the personal GitHub login exists. One entry per decision that shaped the work, newest at the bottom.

## 2026-09-11

- Project lives at `~/life-is-a-game`. Everything for the app stays inside this folder.
- Generic vocabulary only in code and templates. Path, Role, Node, Milestone, Cue, LogEntry. The owner's own paths (guitar, magic, lab, car) are test data under `testdata/`, never shipped as templates.
- Two node kinds, quest and practice. A decision is a Path role, not a node kind. Four independent critics cut the Decision node type as schema for one item.
- Milestones are sentences the user ticks. No numeric stage, no XP, no streaks. Research (Mekler 2017, Deci 1999) says counters hurt hobbies the user already loves.
- Surfacing engine is a pure Swift package (`Engine/`) with no UIKit or SwiftUI imports, so its tests run on Linux, no Mac needed. The app target depends on it. First full run on 2026-09-11: 20 tests, 0 failures. One test had drifted from the `record(_:in:)` signature (takes the whole paths array, as the app uses it) and was fixed.
- Storage in the app was going to be SwiftData. Revised the same day. The engine types are Codable already, so the app persists one `World` JSON document (paths, surfacing history, log) in Application Support with an atomic write. No SwiftData mirror classes, no mapping layer. Data is dozens of nodes for one user. SwiftData and CloudKit return only if phase 3 (sync, friends) ever happens. Laziness Protocol and Subtract Before You Add.
- Docker on this laptop hangs the CLI in a way `timeout` cannot kill. Not used anywhere in this project. Swift toolchain was going to come from mise, but mise's swift plugin 404s on Omarchy's OS id and deletes the install when the post-install check fails on missing libraries. Instead, the Ubuntu 24.04 tarball lives in `.toolchain/`, and `.toolchain/shim/` holds the two libraries Arch names differently (`libncurses.so.6` as a symlink to the system `libncursesw`, `libxml2.so.2` plus its `libicu74` dependency extracted from Ubuntu debs). `swift.sh` wires up `LD_LIBRARY_PATH`. User space, no root, no pacman.
- Today screen ships with a style switch (A one card, B objective plus paths, C paths first) behind Settings for the prototype weeks. The owner lives with each and one survives. Exhaust the Design Space, then delete the losers.
- Cues in phase 1 are time and date only (weekday, weekend, morning, evening, a date). Place and event cues wait for phase 2.
- Build pipeline is GitHub Actions macOS runners plus Splice on the Linux laptop. The workflow lives at `.github/workflows/build.yml`.
- Repo is public at github.com/nabil144/life-is-a-game (personal account, 2026-09-11). Public because GitHub bills macOS runners at 10x on private repos. The laptop keeps the work GitHub account (nabil-end) untouched: personal has its own SSH key (`id_ed25519_personal`), its own `github-personal` host alias, its own `gh` account entry, and the git identity is set per repo, not globally. `testdata/owner-paths.json` carries the owner's four example paths in the open, judged harmless (hobby names).
- Three Today-screen mockups in `design/` as static HTML so the owner reacts to something on the phone before any SwiftUI exists.

## Checkpoints that need the owner

- Personal GitHub login, then `git init` and push. Blocks the first cloud build.
- iPhone plugged into the laptop once for Splice pairing. Blocks the first install.
- Mac availability for the design week (Xcode Previews, Icon Composer). Optional; the plan works without it.
