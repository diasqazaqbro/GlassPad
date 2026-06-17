# GlassPad

**GlassPad is a native macOS Tahoe app launcher that brings back the full-screen Launchpad grid — rebuilt with Apple’s new Liquid Glass look.**

It’s a fast, keyboard-first way to launch apps, search files, and open the web from one
full-screen overlay. It feels like the classic Launchpad people miss on macOS 26, but
designed for Tahoe.

`macOS 26+ (Tahoe)` · `Apple Silicon` · `SwiftUI + AppKit` · `MIT`

## Why use it

- 🗔 **Full-screen app grid** for macOS Tahoe — the Launchpad replacement Apple removed.
- ⌨️ **Keyboard-first app launching** — type, arrow, Return. No mouse needed.
- 🔎 **File search and web search in one bar** — apps, Spotlight files, and the browser.
- ✋ **Drag-to-reorder with folders** — and your layout sticks across relaunches.
- 🧊 **Real Liquid Glass UI** — genuine `.glassEffect`, with a morphing folder animation.
- 🪶 **Lightweight background agent** — no Dock icon, near-zero idle CPU, no permissions.

## Who it’s for

People who upgraded to **macOS 26 Tahoe**, miss the old **Launchpad**, and want a
**full-screen, keyboard-driven app launcher** that looks like Apple shipped it — without
an Electron app or extra permissions. If you liked Launchpad (or Spotlight/Raycast-style
launchers) and want the spatial app grid back, this is for you.

---

## The look

Screenshots aren’t bundled (the app uses only SF Pro + SF Symbols, no image assets). The
fastest way to see it is to [grab a build](#install) or `swift run GlassPad` and press the
hotkey. Roughly, on summon:

```
┌──────────────────────────────────────────────────────────────┐
│                        ⌕  Search                               │   ← glass search pill (auto-focused)
│                                                                │
│   ▦   ▦   ▦   ▦   ▦   ▦   ▦                                    │
│   ▦   ▦   ▦   ▦   ▦   ▦   ▦       big icons, SF Pro labels     │
│   ▦   ▦   ▦   ▦   ▦   ▦   ▦       ~7×5 per page (auto-sized)   │
│   ▦   ▦   ▦   ▦   ▦   ▦   ▦                                    │
│   ▦   ▦   ▦   ▦   ▦                                            │
│                                                                │
│                      • • ○ •            ⚙                      │   ← glass page dots + settings
└──────────────────────────────────────────────────────────────┘
        (everything floats over the blurred, dimmed desktop)
```

## Install

1. Download **`GlassPad.app.zip`** from the [**Releases**](../../releases) page, unzip, and
   drag **GlassPad.app** to `/Applications`.
2. Launch it. There’s **no Dock icon** — look for the **▦ grid** icon in the **menu bar**.
3. Press **⌥Space** (Option-Space) to summon the grid. Rebind it in Settings if it clashes.

**Requirements:** macOS **26.0 (Tahoe)** or newer, **Apple Silicon** (the release binary is
`arm64`). The Liquid Glass APIs are macOS 26-only, so that’s a hard floor.

### First launch (Gatekeeper)

The release is **ad-hoc signed, not notarized** (open-source hobby build), so macOS warns
once. Either **right-click → Open** and confirm, or run:

```bash
xattr -dr com.apple.quarantine /Applications/GlassPad.app
```

Prefer not to trust a prebuilt binary? [Build from source](#build-from-source) — one command.

## Usage

Summon with the global hotkey (**⌥Space** by default), a **four-finger pinch** (if enabled),
or the **menu-bar ▦ icon**.

| Key | Action |
|---|---|
| *type* | Fuzzy-filter apps + Spotlight file search + a web-search row |
| `←` `→` `↑` `↓` | Move the selection (pages flip naturally) |
| `Return` | Launch app / open file / run the web search |
| `Esc` | Close (or end a folder rename / close an open folder) |
| `⌘1`–`⌘9` | Jump to page 1–9 |
| `⌘,` | Open Settings |

Mouse/trackpad: **click** to launch, **two-finger swipe** to flip pages, **click + drag** to
reorder, **click empty space** to dismiss.

## Features

- Full-screen overlay over a dimmed + blurred desktop, on all Spaces, above the Dock and
  menu bar, on whichever screen your cursor is on.
- Liquid Glass on the search pill, page dots, folders, and controls — plus a morphing
  folder-open transition.
- A buttery custom pager (60 fps page flip) driven by trackpad swipe, page dots, or arrows.
- Live app discovery — new installs appear and removed apps disappear automatically.
- English ⇄ Русский, switched live with no relaunch.
- Background agent (`.accessory`): no Dock icon, ~0% idle CPU, sub-300 ms cold open with
  icons cached.

### Search (apps, files, web)

Start typing in the pill. Results are organized top-to-bottom:

1. **Apps** — fuzzy-matched installed apps (including apps inside folders).
2. **Files** — anything on your Mac that Spotlight indexed (documents, images, downloads…),
   most-recently-used first. Opens with its default app.
3. **Search the web** — a row that sends your query to the default browser, so a miss never
   dead-ends.

Arrow keys walk all three sections; **Return** activates the selection. File results are
search-only — they’re never added to your grid or saved layout.

### Reorder & folders

- **Drag** an icon: it lifts and follows the cursor while the others **reflow in real time**
  to open a gap.
- **Drag to the screen edge** and hold briefly to **flip pages**, carrying the icon along.
- **Drop into a gap** to place it; **drop onto another icon’s center** (it highlights) to
  **make or extend a folder**. Open a folder to rename it.
- Your arrangement persists to `~/Library/Application Support/GlassPad/layout.json` and
  survives relaunch.

### Settings

Open with **⌘,** or the menu-bar icon. Tabs: **General** (launch at login, menu-bar icon,
reset layout), **Appearance** (grid density, backdrop dim, wallpaper backdrop), **Shortcuts**
(rebind the summon hotkey), **Gestures** (four-finger pinch, sensitivity, invert),
**Language** (EN ⇄ RU, live).

## Permissions & privacy

GlassPad works **permission-free** by default:

- The global hotkey uses [`KeyboardShortcuts`](https://github.com/sindresorhus/KeyboardShortcuts) —
  **no** Accessibility/Input-Monitoring permission.
- File search reads the system Spotlight index for your account; **nothing leaves your Mac**.
- The wallpaper backdrop is **opt-in** (it uses ScreenCaptureKit, which triggers the
  Screen-Recording prompt). The default frosted-glass backdrop captures nothing.
- **No network, no telemetry.** The only thing that touches the network is the “search the
  web” row, which just opens a URL when you ask.

## Build from source

A Swift Package Manager executable. Needs **Xcode 26 / the macOS 26 SDK**.

```bash
git clone https://github.com/diasqazaqbro/GlassPad.git
cd GlassPad
swift build          # Swift 6, strict concurrency
swift run GlassPad    # run straight from SPM
```

Or open `Package.swift` in **Xcode 26**. To make a distributable bundle (the same artifact
the Release ships):

```bash
./Scripts/make-app-bundle.sh   # builds release → dist/GlassPad.app (ad-hoc signed)
open dist/GlassPad.app
```

Sole dependency: [`KeyboardShortcuts`](https://github.com/sindresorhus/KeyboardShortcuts)
(resolved by SPM).

## Architecture

> For contributors. Layered and **unidirectional**: services produce data → one
> `@Observable` model holds it → SwiftUI reads it. User actions call model methods → the
> model mutates → the UI re-renders. No view talks to a service directly — only the model.

```
   AppKit  ─► OverlayWindowController (KeyableWindow)   borderless, all-Spaces,
              │  hosts SwiftUI via NSHostingView         screen-saver-level window
              ▼ owns
   State   ─► LaunchpadModel  @Observable                items, pages, query, selection,
              │                                            reorder state, file results
        ┌─────┴───────────────┐
Services│ AppDiscoveryService │   SwiftUI views:
        │ IconLoader (NSCache)│     LaunchpadView ─ SearchPill (glass)
        │ LaunchService       │                   ─ PagedGrid ─ AppCell / FolderCell
        │ LayoutStore (disk)  │                   ─ SearchResultsView (apps/files/web)
        │ SpotlightSearch     │                   ─ PageDots (glass)
        │ HotkeyManager       │                   ─ DragFloater (lifted icon)
        └─────────────────────┘
```

Load-bearing decisions:

- **The overlay window is hand-built in AppKit** — SwiftUI scenes can’t be borderless,
  all-Spaces, and screen-saver-level. `KeyableWindow` overrides `canBecomeKey` (borderless
  windows refuse key focus otherwise — no `canBecomeKey`, no typing, no Esc).
- **The pager is a custom offset pager, not a `ScrollView`.** An eager `HStack` of pages is
  slid by one `.offset(x:)`, driven by an `NSEvent.scrollWheel` local monitor, so a page
  flip is a pure GPU layer transform. The grid renders *outside* any `GlassEffectContainer`
  while swiping so nothing re-samples glass behind moving icons.
- **Reorder is a position-based `ZStack`** (each cell pinned by `.position`), so an icon
  moving between rows glides diagonally instead of crossfading. It’s a one-finger
  `DragGesture` — a disjoint event stream from the two-finger scroll-wheel pager — so the
  two never contend.
- **File search lives in its own array.** Spotlight hits are `FileResult`s held separately
  from the launcher `items`; a file isn’t expressible as a grid item, so it can never leak
  into the saved layout.

See [`plan.md`](plan.md) for the full vision and [`CLAUDE.md`](CLAUDE.md) for conventions.

### Project layout

```
Sources/GlassPad/
├─ App/        # @main, AppDelegate, menu-bar item
├─ Window/     # KeyableWindow, OverlayWindowController, Settings window
├─ Model/      # InstalledApp, LaunchpadItem, FileResult, LaunchpadModel
├─ Services/   # discovery, icons, launch, layout store, Spotlight, hotkey, gestures…
├─ Views/      # LaunchpadView, PagedGrid, SearchResultsView, cells, folders, settings
├─ Design/     # Metrics.swift — every layout/animation constant
└─ Resources/  # en.lproj / ru.lproj strings
```

## Troubleshooting

- **“GlassPad is damaged / can’t be opened.”** Gatekeeper on an un-notarized build —
  right-click → Open, or `xattr -dr com.apple.quarantine /Applications/GlassPad.app`.
- **Hotkey does nothing.** Something else owns ⌥Space — rebind it in Settings (⌘,).
- **No menu-bar icon.** If you hid it, summon by hotkey/pinch and reopen Settings (⌘,), or
  relaunch.
- **A file isn’t in search.** GlassPad only surfaces what Spotlight indexed (check System
  Settings → Spotlight).
- **Won’t build/launch.** Confirm macOS 26+ and the Xcode 26 / macOS 26 SDK — no back-deploy.

## Roadmap

Post-v1 ideas: import a recovered legacy Launchpad layout; jiggle-mode uninstall; smart
folders/categories; iCloud layout sync; custom glass tint themes; inline calculator/actions
in the search bar; multi-display spanning.

## Contributing

Issues and PRs welcome. Conventions live in [`CLAUDE.md`](CLAUDE.md): macOS 26+ only, Swift 6
strict concurrency, all constants in `Design/Metrics.swift`, glass on the functional layer
only, UI/AppKit on `@MainActor`, conventional-commit messages, every commit builds.

## Credits & license

Global hotkey via [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) by
[Sindre Sorhus](https://github.com/sindresorhus). SF Pro & SF Symbols are Apple’s.

Released under the **MIT License** — see [`LICENSE`](LICENSE). Not affiliated with or
endorsed by Apple.
