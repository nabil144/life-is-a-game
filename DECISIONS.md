# Decision trail

One entry per decision that shaped the work, newest at the bottom. Current state and next steps live in `PROGRESS.md`.

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
- First cloud build (2026-09-11) failed on 7 root causes, all in the app, none in the engine. The big one: SwiftUI exports its own `Path`, so the app declares `typealias Path = LifeEngine.Path` and never draws with SwiftUI's. `Notifier` needed `@Observable` to travel through `.environment`. `Objective` needed a public init. Settings body was too big for the type checker and became five small views. Second build was green across all three jobs; the Simulator screenshot shows onboarding. Artifacts land in `artifacts/`, gitignored.
- Three Today-screen mockups in `design/` as static HTML so the owner reacts to something on the phone before any SwiftUI exists.

## 2026-09-12

- `splice login` on the Linux laptop fails twice over. First, Arch's CA bundle lacks Apple Root CA, which `gsa.apple.com` chains to. Fixed with `~/.config/splice/ca/AppleRootCA.pem` and a `splice()` wrapper in `~/.bashrc` that sets `SSL_CERT_DIR`. Second, Apple's GrandSlam login POST answers with an HTTP 503 page, splice parses it as a plist, gets null, and segfaults (`coredumpctl list splice`). That is a splice bug plus an Apple-side rejection of the emulated anisette data, and nothing on the laptop is left to configure.
- First install moves to Xcode on the Mac. Splice on macOS would run the same login code against the same account, so the 503 may follow. Xcode signs in through Apple's own auth stack and handles device registration, Developer Mode, and the trust dialog. Cost: a free Apple ID signs for 7 days, so refreshes need the Mac again until the Linux pipeline works. Experience First. The point of the prototype weeks is living with the Today screen, not the pipeline.
- `PROGRESS.md` added as the first file to read in a session. It holds what the app is, status, and the session log. This file keeps the why. The workflow no longer runs on markdown-only pushes, so progress commits stop burning macOS runner minutes.

## Checkpoints that need the owner

- Mac with Xcode, the iPhone, and a USB cable in one place. Blocks the first install.
- Every 7 days after that, the same, until Splice works on the laptop.
