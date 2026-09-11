# Life is a Game

A personal iOS app. Paths you write yourself, one objective a day that finds you when the moment is right. No points, no streaks, nothing you can lose.

## Layout

- `docs/` spec, screens and flows, copy deck.
- `design/` static HTML mockups of the Today screen (three styles) and Path detail. Open on the phone.
- `templates/` four generic starter paths, bundled into the app.
- `testdata/` the owner's own paths in the same shape. Not shipped.
- `Engine/` pure Swift package. Domain types and the surfacing planner. Tests run on Linux.
- `App/` SwiftUI app. One JSON document as storage, local notifications, no server.
- `project.yml` XcodeGen definition. `xcodegen generate` produces the Xcode project.
- `.github/workflows/build.yml` GitHub Actions workflow: engine tests, Simulator screenshot, unsigned .ipa.
- `DECISIONS.md` why things are the way they are.
- `PROGRESS.md` what the app is, where the work stands, what comes next. Read it first each session.

## Run the engine tests on this laptop

```sh
cd Engine && ../swift.sh test
```

`swift.sh` runs the project-local toolchain in `.toolchain/` with the Ubuntu shared libraries it needs (`.toolchain/shim/`). No root, nothing installed system-wide. Last run: 20 tests, 0 failures.

## Look at the mockups on the phone

The laptop firewall (ufw) only lets port 53317 through, so the mockups ride on the existing `serve-md` server on that port, behind its login.

```sh
serve-md ~/game-lore-learning-plan.md --port 53317 --static ~/life-is-a-game/design
```

Then open `http://<laptop-ip>:53317/design/today-a.html` on the phone (same Wi-Fi). Login is in `~/.local/share/serve-md/credentials.json`.

## Build for the phone

Repo: https://github.com/nabil144/life-is-a-game (public, so macOS runner minutes are free). Remote uses the `github-personal` SSH alias so the work key is never involved.

Pushes to `main` that touch anything except markdown run the workflow: engine tests, a Simulator screenshot, and an unsigned `.ipa`. Download the artifact with `gh run download --name LifeIsAGame-unsigned-ipa --dir artifacts/`.

### From the Mac with Xcode

This is the path that works today. It does not use the CI `.ipa`.

1. Clone the repo, `brew install xcodegen`, then `xcodegen generate` in the repo root.
2. Open `LifeIsAGame.xcodeproj`. In Xcode > Settings > Accounts, add the Apple ID.
3. Select the `LifeIsAGame` target > Signing & Capabilities. Tick **Automatically manage signing** and pick the Personal Team.
4. Plug the phone in over USB, unlock it, and trust the Mac. Pick the phone as the run destination and press Run. Xcode offers to enable Developer Mode if it is off.
5. On the phone, open Settings > General > VPN & Device Management and trust the developer profile.

A free Apple ID signs for 7 days. Press Run again from the Mac to refresh.

### From the Linux laptop with Splice

Blocked on 2026-09-12. `splice login` gets an HTTP 503 from Apple and crashes. Details in `DECISIONS.md`. When it works, the steps are `splice login` once, then `splice install artifacts/LifeIsAGame-unsigned-ipa/LifeIsAGame-unsigned.ipa` with the phone on USB. Later installs and the 7-day refresh can go over Wi-Fi.
