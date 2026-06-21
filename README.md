# QuickCapture

A minimal macOS menu bar app that lets you capture a bullet point into today's Obsidian daily note from anywhere — instantly.

![macOS](https://img.shields.io/badge/macOS-13%2B-black) ![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange) ![No dependencies](https://img.shields.io/badge/dependencies-none-brightgreen)

---

## What it does

Hit `⌥Q` from any app. A small Spotlight-style window appears centered on screen. Type your thought. Hit `↩`. Done — it's a bullet point at the bottom of today's daily note. Hit `esc` to dismiss without saving.

No Electron. No background daemon. No Xcode project. One Swift file, ~350 lines, zero dependencies beyond AppKit and Carbon (both ship with macOS).

---

## Install

**Requirements:** macOS 13+, Xcode Command Line Tools (`xcode-select --install`)

```bash
git clone https://github.com/yourusername/QuickCapture
cd QuickCapture
bash build.sh
open QuickCapture.app
```

On first launch the app auto-detects your Obsidian vault and creates a config file at:

```
~/.config/quickcapture/config
```

---

## Config

Open `~/.config/quickcapture/config` in any text editor:

```
# Absolute path to your Obsidian vault root
vault=/Users/you/Library/Mobile Documents/iCloud~md~obsidian/Documents/MyVault

# Folder inside the vault where daily notes live
journal_folder=10_Journal

# Path inside the vault to the daily note template
template_path=00_Inbox/templates/Daily Template.md
```

Rebuild after changing config (`bash build.sh`).

---

## Daily note format

Notes are named `DD-MM-YYYY.md` and live in `journal_folder`. If today's note doesn't exist, it's created from your template with `{{date:DD-MM-YYYY}}` and `{{date:dddd}}` replaced automatically.

Each capture appends to the bottom:

```markdown
- your captured thought
```

---

## Hotkey

Default is `⌥Q`. To change it, edit the top of `QuickCapture.swift`:

```swift
static let hotkeyMods: UInt32 = 0x0800   // ⌥ option
static let hotkeyCode: UInt32 = UInt32(kVK_ANSI_Q)
```

Modifier flags: `cmd=0x0100  option=0x0800  ctrl=0x1000  shift=0x0200` — add them for combos.  
Key codes are Carbon `kVK_ANSI_*` constants (e.g. `kVK_Space`, `kVK_ANSI_C`).

Then rebuild: `bash build.sh`

---

## How it works

| Layer | Detail |
|---|---|
| **Global hotkey** | Carbon `RegisterEventHotKey` — fires on any app, any Space, no Accessibility permission needed |
| **Window** | `NSPanel` with `.borderless` style, `NSVisualEffectView` blur background, 22px corner radius, `masksToBounds` clips the blur clean |
| **Text input** | `NSTextView` with frame-math vertical centering — `y = (windowH - lineH) / 2` using real font metrics |
| **File I/O** | Plain `String` read/write on a background thread — dismiss is instant, write happens after |
| **No Dock icon** | `.accessory` activation policy — lives only in the menu bar |

---

## Auto-launch at login

System Settings → General → Login Items → + → select `QuickCapture.app`

---

## License

MIT
