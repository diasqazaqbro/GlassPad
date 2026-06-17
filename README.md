# GlassPad

**A native macOS 26 “Tahoe” replacement for Launchpad — the full-screen app grid, brought back and rebuilt around Apple’s real Liquid Glass.**

> Apple removed Launchpad in macOS 26 Tahoe and folded app launching into Spotlight. GlassPad brings the full-screen visual app grid back — and makes it look *more* native than the original by adopting Tahoe’s genuine `.glassEffect` material.

- **Platform:** macOS **26.0+** (Tahoe), Apple Silicon
- **Built with:** Swift 6 (strict concurrency), SwiftUI + AppKit, Swift Package Manager
- **Status:** feature-complete v1 (build phases 0–6), `swift build` clean
- **License:** MIT

---

## Table of contents

- [What is GlassPad?](#what-is-glasspad)
- [Why does it exist?](#why-does-it-exist)
- [Why would you run it?](#why-would-you-run-it)
- [Features](#features)
- [Screenshots / the look](#screenshots--the-look)
- [Install (download a build)](#install-download-a-build)
- [First-launch: getting past Gatekeeper](#first-launch-getting-past-gatekeeper)
- [Build & run from source](#build--run-from-source)
- [Usage](#usage)
  - [Keyboard](#keyboard)
  - [Mouse & trackpad](#mouse--trackpad)
  - [Search (apps, files, web)](#search-apps-files-web)
  - [Reorder & folders](#reorder--folders)
  - [Settings](#settings)
- [Permissions & privacy](#permissions--privacy)
- [How it works (architecture)](#how-it-works-architecture)
- [Project layout](#project-layout)
- [Performance notes](#performance-notes)
- [Troubleshooting](#troubleshooting)
- [Roadmap](#roadmap)
- [Contributing](#contributing)
- [Credits & license](#credits--license)

---

## What is GlassPad?

GlassPad is a small, fast, **keyboard-first full-screen app launcher** for macOS. Hit a
global hotkey (or a four-finger pinch, or the menu-bar icon) and a full-screen overlay
fades in over a dimmed, blurred desktop: a paged grid of every app you have, with big
icons and SF Pro labels — exactly the Launchpad layout people miss — but with Apple’s
**Liquid Glass** on the functional chrome (search pill, page dots, folders, controls)
and a morphing folder-open animation.

It is a **background agent app**: no Dock icon, ~0% idle CPU, opens in well under a
second with icons cached. It asks for **no permissions** out of the box.

## Why does it exist?

macOS 26 Tahoe **retired Launchpad**. Its replacement — an Applications view inside
Spotlight — is a fine list, but it isn’t the spatial, paged, drag-to-arrange grid that a
lot of people built muscle memory around. GlassPad is a focused answer to one question:

> *“Can I have the old Launchpad back, but looking like Apple shipped it for Tahoe?”*

So the design goal isn’t nostalgia for its own sake — it’s to be **indistinguishable
from a first-party utility**: Launchpad’s metrics and motion, plus the genuine macOS 26
glass material that the old Launchpad never had.

## Why would you run it?

- You want the **full-screen, paged app grid** back after upgrading to Tahoe.
- You want a launcher you drive **entirely from the keyboard** (type → arrow → Return).
- You want **drag-to-arrange** with folders that **persist** across relaunches.
- You also want a quick **file finder** and a **“search the web”** fallback in the same
  bar — so one shortcut covers apps, files, and the browser.
- You want it to be **native, light, and permission-free**, not an Electron wrapper.

---

## Features

- 🪟 **Full-screen overlay** over a dimmed + blurred desktop, floating above the Dock and
  menu bar, on all Spaces, on the screen your cursor is on.
- 🧊 **Real Liquid Glass** (`.glassEffect` / `GlassEffectContainer` / `glassEffectID`) on
  the search pill, page dots, folder surfaces, and controls — including a **morphing**
  folder-open transition. Glass stays on the *functional* layer; the icon grid stays
  restrained (HIG-correct).
- ⌨️ **Keyboard-first**: type to fuzzy-filter, arrow keys to move, Return to launch, Esc
  to dismiss, **⌘1–9** to jump to a page.
- 🧭 **Buttery custom pager**: horizontal paging via two-finger trackpad swipe, page dots,
  or arrows — a hand-rolled offset pager (not a `ScrollView`) for a 60 fps native flip.
- ✋ **Live-reflow drag-to-reorder**: drag an icon and the others part to make room in
  real time; carry it to the screen edge to flip pages; drop it in the gap. Drop onto
  another icon’s center to make/extend a **folder**. Layout **persists** to disk.
- 🔎 **Spotlight file search**: the search bar finds **any file on your Mac** (via
  `NSMetadataQuery`), shown in a **Files** section below your matching apps.
- 🌐 **Search the web**: a row at the bottom of results opens your query in the default
  browser — so a miss never dead-ends.
- 🗂 **Folders** with rename and the glass morph open/close.
- 🔁 **Live app discovery**: newly installed/removed apps reconcile automatically.
- ⚙️ **Settings**: rebind the global hotkey, switch language (English ⇄ Русский, no
  relaunch), grid density, backdrop dimming, optional wallpaper backdrop, and gesture
  options (four-finger pinch to summon, sensitivity, invert).
- 🏎 **Background agent** (`.accessory`): no Dock icon, near-zero idle CPU, sub-300 ms cold
  open with icons cached, **no permission prompts** unless you opt into wallpaper capture.

---

## Screenshots / the look

> Screenshots aren’t committed (no bundled image assets — SF Pro + SF Symbols only). The
> quickest way to see it is to [grab a build](#install-download-a-build) or
> `swift run GlassPad` and press the hotkey.

Roughly, what you get on summon:

```
┌──────────────────────────────────────────────────────────────┐
│                        ⌕  Search                               │   ← glass search pill (auto-focused)
│                                                                │
│   ▦   ▦   ▦   ▦   ▦   ▦   ▦                                    │
│   ▦   ▦   ▦   ▦   ▦   ▦   ▦       big icons, SF Pro labels     │
│   ▦   ▦   ▦   ▦   ▦   ▦   ▦       ~7×5 per page (derived)      │
│   ▦   ▦   ▦   ▦   ▦   ▦   ▦                                    │
│   ▦   ▦   ▦   ▦   ▦                                            │
│                                                                │
│                      • • ○ •            ⚙  ← glass page dots + gear │
└──────────────────────────────────────────────────────────────┘
        (everything floats over the blurred, dimmed desktop)
```

---

## Install (download a build)

1. Go to the [**Releases**](../../releases) page and download the latest
   `GlassPad.app.zip`.
2. Unzip it and drag **GlassPad.app** to `/Applications`.
3. Launch it. There’s no Dock icon — look for the **▦ grid** icon in the **menu bar**.
4. Press the default hotkey **⌥Space** (Option-Space) to summon the grid. Rebind it in
   **Settings** if it clashes with something.

> **Requirements:** macOS **26.0 (Tahoe) or newer**, **Apple Silicon** (the release
> binary is `arm64`). On macOS < 26 the Liquid Glass APIs don’t exist and it won’t run —
> build from source is no different here; macOS 26 is a hard floor.

## First-launch: getting past Gatekeeper

The release build is **ad-hoc signed, not notarized** (it’s a hobby/open-source build),
so Gatekeeper will complain the first time. This is expected. Pick one:

- **Right-click → Open** on `GlassPad.app`, then confirm **Open** in the dialog. (You only
  do this once.)
- **Or** strip the quarantine flag from a terminal:
  ```bash
  xattr -dr com.apple.quarantine /Applications/GlassPad.app
  ```
- **Or** System Settings → Privacy & Security → scroll to the “GlassPad was blocked”
  notice → **Open Anyway**.

If you’d rather not trust a prebuilt binary at all, [build from source](#build--run-from-source) — it’s one command.

---

## Build & run from source

GlassPad is a **Swift Package Manager executable**. You need **Xcode 26 / the macOS 26
SDK** (for the `.glassEffect` APIs and Swift 6).

```bash
# clone
git clone https://github.com/diasqazaqbro/GlassPad.git
cd GlassPad

# compile (Swift 6, strict concurrency)
swift build

# run straight from SPM
swift run GlassPad
```

Or open the folder / `Package.swift` directly in **Xcode 26** and run.

### Make a distributable `.app` bundle

`swift run` is great for development, but launch-at-login and a clean TCC identity want a
real bundle. The repo ships a script that builds **release** and wraps the binary into
`dist/GlassPad.app` (ad-hoc signed):

```bash
./Scripts/make-app-bundle.sh
open dist/GlassPad.app
```

That `dist/GlassPad.app` (zipped) is exactly what the GitHub Release attaches.

### Dependency

- [`KeyboardShortcuts`](https://github.com/sindresorhus/KeyboardShortcuts) by Sindre
  Sorhus — robust, user-rebindable global hotkey **without** requiring Accessibility or
  Input-Monitoring permission. Resolved automatically by SPM.

---

## Usage

Summon GlassPad with the **global hotkey** (default **⌥Space**), a **four-finger pinch**
(if enabled in Settings), or by clicking the **menu-bar ▦ icon**.

### Keyboard

| Key | Action |
|---|---|
| *type* | Instant fuzzy filter (apps), plus a Spotlight file search and a web-search row |
| `←` `→` `↑` `↓` | Move the selection (pages flip naturally) |
| `Return` | Launch the selected app / open the selected file / run the web search |
| `Esc` | Close the overlay (or end a folder rename / close an open folder) |
| `⌘1`–`⌘9` | Jump straight to page 1–9 |
| `⌘,` | Open Settings |

### Mouse & trackpad

- **Click** an icon to launch it.
- **Two-finger swipe** left/right to flip pages (one page per swipe, like the original).
- **Click + drag** an icon to reorder (see below).
- **Click empty space** to dismiss.

### Search (apps, files, web)

Just start typing in the pill. Results are organized top-to-bottom:

1. **Apps** — fuzzy-matched installed apps (matches apps inside folders too).
2. **Files** — anything on your Mac that Spotlight knows about (documents, images,
   downloads…), most-recently-used first. Opens with its default app.
3. **Search the web** — a row that sends your query to the browser. Never a dead end.

Arrow keys walk all three sections in order; **Return** activates whatever’s selected.
File results are **search-only** — they never get added to your grid or saved layout.

### Reorder & folders

- **Drag** an icon: it lifts (scales up, casts a shadow) and follows your cursor while the
  other icons **reflow in real time** to open a gap.
- **Drag to the left/right screen edge** and hold briefly to **flip to the next page**,
  carrying the icon with you.
- **Drop into a gap** to place it there.
- **Hover over another icon’s center** until it highlights, then drop, to **create or
  extend a folder**. Open a folder to rename it.
- Your arrangement and folders **persist** to
  `~/Library/Application Support/GlassPad/layout.json` and survive relaunch. New installs
  are appended; uninstalled apps are pruned automatically.

### Settings

Open with **⌘,** or the menu-bar icon → Settings. Tabs:

- **General** — launch at login, show/hide menu-bar icon, reset layout.
- **Appearance** — grid density, backdrop dimming, optional wallpaper backdrop.
- **Shortcuts** — rebind the global summon hotkey; reference for in-app keys.
- **Gestures** — four-finger pinch to summon, pinch sensitivity, invert direction.
- **Language** — English ⇄ Русский, applied live (no relaunch).

---

## Permissions & privacy

GlassPad is designed to work **permission-free**:

- **No Accessibility / Input-Monitoring** — the global hotkey uses `KeyboardShortcuts`.
- **File search** uses the system Spotlight index over your local computer scope. A
  non-sandboxed build queries it with **no extra prompt**; it only ever sees what
  Spotlight already indexed for your account, and file paths/names never leave your Mac.
- **Wallpaper backdrop is opt-in.** By default the backdrop is a frosted
  `.ultraThinMaterial`. If you turn on “use desktop wallpaper as background”, GlassPad
  captures the screen behind it via ScreenCaptureKit — *that* triggers the standard
  macOS Screen-Recording prompt. Leave it off and nothing is captured.
- **No network, no telemetry, no analytics.** The only thing that touches the network is
  the “search the web” row, which just opens a URL in your browser when you ask it to.

---

## How it works (architecture)

Layered and **unidirectional**: services produce data → one `@Observable` model holds it
→ SwiftUI reads it. User actions call model methods → the model mutates → the UI
re-renders. **No view talks to a service directly** — only through the model.

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

A few load-bearing decisions worth knowing:

- **The overlay window is hand-built in AppKit.** SwiftUI scenes can’t be borderless,
  all-Spaces, and screen-saver-level. `KeyableWindow` overrides `canBecomeKey` (borderless
  windows refuse key focus otherwise — without it there’s no typing and no Esc).
- **The pager is a custom offset pager, not a `ScrollView`.** Every `ScrollView` strategy
  re-ran scroll physics and re-laid-out content per frame and hitched. Instead, an eager
  `HStack` of full-width pages is slid by a single `.offset(x:)`, driven by an
  `NSEvent.scrollWheel` *local monitor* — a page flip is then a pure GPU layer transform.
- **The grid renders *outside* any `GlassEffectContainer`** while swiping, so nothing
  re-samples a glass backdrop behind the moving icons (the smooth path). Glass lives on
  the static chrome and the open-folder morph.
- **Reorder is a position-based `ZStack`.** Each page lays cells out by computed
  `.position` from a single `ForEach`, so an icon moving between rows **glides** along a
  diagonal. Reorder is a one-finger `DragGesture` — a *disjoint* event stream from the
  two-finger scroll-wheel pager, so the two never contend, and a reflow animation keys on
  a private revision counter so a page swipe can never trigger it.
- **File search lives in its own array.** Spotlight hits are `FileResult`s held separately
  from the launcher `items`; a file is deliberately **not** expressible as a grid item, so
  it can never leak into the saved layout.

See [`plan.md`](plan.md) for the full vision and the phased build plan, and
[`CLAUDE.md`](CLAUDE.md) for the repo conventions.

## Project layout

```
GlassPad/
├─ Package.swift                 # SPM executable + KeyboardShortcuts dep
├─ plan.md                       # full product vision + phased build plan
├─ CLAUDE.md                     # repo conventions / hard requirements
├─ Scripts/make-app-bundle.sh    # build release → wrap into dist/GlassPad.app
└─ Sources/GlassPad/
   ├─ App/                       # @main, AppDelegate, menu-bar item
   ├─ Window/                    # KeyableWindow, OverlayWindowController, Settings window
   ├─ Model/                     # InstalledApp, LaunchpadItem, FileResult, LaunchpadModel
   ├─ Services/                  # discovery, icons, launch, layout store, Spotlight, hotkey, gestures…
   ├─ Views/                     # LaunchpadView, PagedGrid, SearchResultsView, cells, folders, settings
   ├─ Design/Metrics.swift       # every layout/animation constant (no magic numbers in views)
   └─ Resources/{en,ru}.lproj/   # localized strings
```

## Performance notes

- **Idle CPU ≈ 0** — it’s an event-driven agent app; nothing spins when hidden.
- **Cold open < ~300 ms** once icons are cached (`NSCache` keyed by bundle path; icons
  load async off the main actor and are never stored on the model).
- **60 fps paging & reflow** — the pager flip is a GPU layer transform; reflow only
  rebuilds page slices when the target slot actually changes (coalesced), not per frame.

## Troubleshooting

- **“GlassPad is damaged / can’t be opened.”** Gatekeeper on an un-notarized build. See
  [getting past Gatekeeper](#first-launch-getting-past-gatekeeper) — right-click → Open,
  or `xattr -dr com.apple.quarantine /Applications/GlassPad.app`.
- **The hotkey does nothing.** Another app may own ⌥Space. Open Settings (menu-bar icon →
  Settings, or ⌘, while the overlay is up) and rebind it.
- **No menu-bar icon.** If you turned it off in Settings, summon by hotkey/pinch and
  reopen Settings from there (⌘,). Or relaunch the app.
- **A file I expect isn’t in search.** GlassPad only surfaces what Spotlight has indexed.
  If Spotlight is rebuilding or the folder is excluded in System Settings → Spotlight, it
  won’t appear.
- **It won’t launch / build.** Confirm **macOS 26+** and the **Xcode 26 / macOS 26 SDK**.
  The Liquid Glass APIs are macOS 26-only by design — there is no back-deploy.
- **Wallpaper backdrop asks for Screen Recording.** That’s expected and opt-in; turn the
  option off to use the frosted-glass backdrop with no prompt.

## Roadmap

Post-v1 ideas (not yet built): import a recovered legacy Launchpad layout; jiggle-mode
uninstall; smart folders / categories; iCloud layout sync; custom glass tint themes;
inline calculator/actions in the search bar; multi-display spanning.

## Contributing

Issues and PRs welcome. Conventions live in [`CLAUDE.md`](CLAUDE.md); the short version:

- **macOS 26+ only**, Swift 6 strict concurrency, `swift build` must stay clean.
- **All design constants in `Design/Metrics.swift`** — no magic numbers in views.
- **Liquid Glass on the functional layer only**; keep the icon grid restrained.
- UI/AppKit on `@MainActor`; scanning/icon/Spotlight work off-main, results back on main.
- One logical change per commit, conventional-commit messages; every commit builds & runs.

## Credits & license

- Global hotkey via [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts)
  by [Sindre Sorhus](https://github.com/sindresorhus).
- SF Pro & SF Symbols are Apple’s.

Released under the **MIT License** — see [`LICENSE`](LICENSE). Not affiliated with or
endorsed by Apple.
