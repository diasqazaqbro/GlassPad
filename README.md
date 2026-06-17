# GlassPad

**GlassPad brings back Launchpad for macOS Tahoe as a native full-screen app grid — rebuilt with Apple’s Liquid Glass look and feel.**

Launch apps, search files, and open the web from one keyboard-first overlay. It feels like
the classic Launchpad people miss, but built for macOS 26.

`macOS 26+ (Tahoe)` · `Apple Silicon` · `MIT`

## Why use it

- **Full-screen app grid for macOS Tahoe** — the Launchpad replacement Apple removed.
- **Keyboard-first** — type, arrow, return.
- **Search apps, files, and the web** from one bar.
- **Drag to reorder and create folders** — your layout stays saved.
- **Native SwiftUI + AppKit** — no Electron.
- **No Dock icon, near-zero idle CPU.**

## Who it’s for

- You upgraded to macOS Tahoe and miss Launchpad.
- You want a launcher that feels native, not like a web app.
- You prefer keyboard-driven workflows.
- You want app launch, file search, and web search in one place.

## Demo

> A screenshot/GIF goes here. The app uses only SF Pro + SF Symbols (no bundled images),
> so the quickest preview is to [grab a build](#install) or `swift run GlassPad` and press
> the hotkey. Roughly, on summon:

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

Download the latest [**release**](../../releases), unzip it, and drag **GlassPad.app** to
`/Applications`. There’s no Dock icon — GlassPad lives in the **menu bar** (▦ icon).

Default hotkey: **Option-Space**.

**Requirements:** macOS **26 (Tahoe)** or newer, **Apple Silicon**. First launch shows a
Gatekeeper warning (the build isn’t notarized) — right-click → **Open** once, or see
[Troubleshooting](#troubleshooting).

## Quick start

1. Press **Option-Space** to open GlassPad.
2. Start typing an app, file, or search term.
3. Use the **arrow keys** to move.
4. Press **Return** to launch the app, open the file, or search the web.
5. **Drag** an icon to reorder it, or drop it on another to make a **folder**.

## Build from source

A Swift Package Manager executable — needs **Xcode 26 / the macOS 26 SDK**.

```bash
git clone https://github.com/diasqazaqbro/GlassPad.git
cd GlassPad
swift build
swift run GlassPad
```

To make a distributable bundle (the same artifact the release ships):

```bash
./Scripts/make-app-bundle.sh   # → dist/GlassPad.app
```

## Features

- Full-screen overlay over a dimmed, blurred desktop — on all Spaces, above the Dock and
  menu bar, on whichever screen your cursor is on.
- Real Liquid Glass on the search pill, page dots, folders, and controls, with a morphing
  folder open/close animation.
- A smooth custom pager (60 fps page flip) you swipe with two fingers, the page dots, or
  arrow keys; `⌘1`–`⌘9` jump straight to a page.
- Live app discovery — new installs appear and removed apps disappear automatically.
- English ⇄ Русский, switched live with no relaunch.
- A lightweight background agent: no Dock icon, near-zero idle CPU, sub-300 ms cold open.

### Search (apps, files, web)

Start typing in the pill — results are organized top-to-bottom:

1. **Apps** — fuzzy-matched installed apps (including apps inside folders).
2. **Files** — anything Spotlight indexed on your Mac (documents, images, downloads…),
   most-recently-used first. Opens with its default app.
3. **Search the web** — a row that sends your query to the default browser, so a miss never
   dead-ends.

Arrow keys walk all three; **Return** activates the selection. File results are
search-only — never added to your grid or saved layout.

### Reorder & folders

- **Drag** an icon: it lifts and follows the cursor while the others reflow to open a gap.
- **Drag to the screen edge** and hold briefly to flip pages, carrying the icon along.
- **Drop into a gap** to place it; **drop onto another icon** (it highlights) to make or
  extend a **folder**. Open a folder to rename it.
- Your arrangement persists across relaunches.

### Settings

Open with **⌘,** or the menu-bar icon: rebind the hotkey, switch language (EN ⇄ RU, live),
grid density, backdrop dimming, optional wallpaper backdrop, and four-finger pinch-to-summon.

## Permissions & privacy

GlassPad works **permission-free** by default:

- The global hotkey needs **no** Accessibility/Input-Monitoring permission.
- File search reads the local Spotlight index for your account; **nothing leaves your Mac**.
- The wallpaper backdrop is **opt-in** (it uses screen recording); the default frosted-glass
  backdrop captures nothing.
- **No network, no telemetry** — the only network use is the “search the web” row, which
  just opens a URL when you ask.

## Technical details

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
  all-Spaces, and screen-saver-level. A `KeyableWindow` overrides `canBecomeKey` (borderless
  windows refuse key focus otherwise — without it, no typing, no Esc).
- **The pager is a custom offset pager, not a `ScrollView`.** An eager `HStack` of pages is
  slid by one `.offset(x:)`, driven by an `NSEvent.scrollWheel` monitor, so a page flip is a
  pure GPU layer transform. The grid renders outside any glass container while swiping so
  nothing re-samples glass behind the moving icons.
- **Reorder is a position-based `ZStack`** (each cell pinned by `.position`), so an icon
  moving between rows glides diagonally instead of crossfading. It’s a one-finger
  `DragGesture` — a disjoint event stream from the two-finger scroll pager — so they never
  contend.
- **File search lives in its own array** — a file isn’t expressible as a grid item, so it
  can never leak into the saved layout.

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
  right-click → **Open**, or run `xattr -dr com.apple.quarantine /Applications/GlassPad.app`.
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

Issues and PRs welcome. Conventions: macOS 26+ only, Swift 6 strict concurrency, all
constants in `Design/Metrics.swift`, glass on the functional layer only, UI/AppKit on
`@MainActor`, conventional-commit messages, every commit builds.

## Credits & license

Global hotkey via [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) by
[Sindre Sorhus](https://github.com/sindresorhus). SF Pro & SF Symbols are Apple’s.

Released under the **MIT License** — see [`LICENSE`](LICENSE). Not affiliated with or
endorsed by Apple.
