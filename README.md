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

1. Push to `main`. The workflow runs on its own.
2. Download the `LifeIsAGame-unsigned-ipa` artifact: `gh run download --name LifeIsAGame-unsigned-ipa --dir artifacts/`.
3. On the laptop, `splice install LifeIsAGame-unsigned.ipa` (after a one-time `splice login` and USB pairing).
