# AGENTS.md — QuickCapture

## What this repo is
A single-file macOS menu bar app (Swift) that appends bullet points to an Obsidian daily note via a global hotkey (`⌥Q`). Zero third-party dependencies; all frameworks ship with macOS.

## Build
```bash
bash build.sh        # compile + package into QuickCapture.app
open QuickCapture.app
```
There is no Xcode project, no SPM, no Makefile. Do not introduce them. The build is intentionally `swiftc` only.

**Requires:** macOS 13+, Xcode Command Line Tools (`xcode-select --install`).

## No tests, no CI, no linter
There is no test suite, no CI workflow, and no lint/format tooling. There is nothing to run after editing besides `bash build.sh`.

## Entire app is one file
`QuickCapture.swift` (~363 lines) contains everything. Sections are marked with `// MARK:`:

| MARK | What it does |
|---|---|
| `Config` | Compile-time constants (hotkey codes, window dimensions) |
| `UserConfig` | Reads/writes `~/.config/quickcapture/config` (key=value) |
| `Root (AppDelegate)` | Registers Carbon global hotkey, owns the Panel, handles file I/O |
| `Panel` | `NSPanel` borderless wrapper hosting `CaptureView` |
| `CaptureView` | `NSVisualEffectView` blur + `NSTextView` input; frame math, no Auto Layout |

## Key gotchas
* **Hotkey customization requires a source edit + rebuild.** The modifier/keycode constants live in `enum Config` at the top of `QuickCapture.swift`.
* **Runtime config** lives at `~/.config/quickcapture/config` (auto-created on first launch). Editing it does **not** require a rebuild — the file is read at launch.
* **`QuickCapture.app/` is gitignored.** The build artifact is always regenerated; never commit it.
* **`LSUIElement=true`** — no Dock icon by design. The app is menu-bar/background only.
* **File I/O is async** (`DispatchQueue.global`) so the panel dismisses instantly; keep it that way.
* **Global hotkey uses Carbon `RegisterEventHotKey`**, not Accessibility APIs — no Accessibility permission needed.
* **Daily note format:** `DD-MM-YYYY.md` inside the configured `journal_folder`.
* **Template variables** supported: `{{date:DD-MM-YYYY}}`, `{{date:dddd}}`, `{{date}}`.
