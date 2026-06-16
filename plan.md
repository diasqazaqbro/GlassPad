# GlassPad — Build Plan for Claude Code

A native macOS Launchpad replacement with authentic Liquid Glass. Built because Apple removed Launchpad in macOS 26 Tahoe and folded it into Spotlight. Goal: bring back the full-screen visual app grid, but make it look *more* native than the original by adopting Tahoe's real Liquid Glass material.

> **How to use this doc:** Implement phase by phase. Do **not** jump ahead. After each phase, the app must build, run, and be visually verifiable. Commit at the end of every phase. Treat the "Proven patterns" snippets as authoritative for API surface — they target the real macOS 26 APIs.

---

## 1. Product vision

A keyboard-first, gorgeous, full-screen app launcher that feels like Apple shipped it:

- Summon with a global hotkey or menu-bar icon → full-screen overlay fades in over a blurred desktop.
- Paged grid of every installed app, big icons, SF Pro labels — Launchpad metrics.
- Type to filter instantly (fuzzy). Arrow keys + Return to launch. Esc to dismiss.
- Drag to reorder; drag one app onto another → folder. Layout persists.
- Real **Liquid Glass** on the functional chrome (search pill, folder surfaces, page dots), with morphing folder-open transitions.

Non-goals for v1: iCloud sync, multi-monitor spanning (single active screen is fine), iPhone-mirroring apps.

---

## 2. Tech stack & rationale

| Choice | Why |
|---|---|
| **Swift 6**, strict concurrency | Modern, `@MainActor` correctness for all UI/AppKit. |
| **SwiftUI** for all views | `.glassEffect` / `GlassEffectContainer` are SwiftUI-native and one-line. |
| **AppKit interop** (`NSWindow` + `NSHostingView`) | SwiftUI's `WindowGroup` can't do a borderless, all-Spaces, screen-saver-level overlay. The window must be hand-built in AppKit. |
| **Observation** (`@Observable`) | macOS 26 default; cleaner than `ObservableObject`. |
| **Swift Package Manager** | Deps as SPM. |
| `KeyboardShortcuts` (Sindre Sorhus) | Robust, user-rebindable global hotkey without wrestling Carbon or asking for Accessibility permission. |
| **Deployment target: macOS 26.0**, Xcode 26 | `.glassEffect` is macOS 26+ only. Hard requirement. |

No Electron, no web layer. This is a system utility — it needs native window levels, `NSWorkspace`, and the real glass material.

---

## 3. Architecture

Layered, unidirectional. UI observes one `@Observable` model; services are stateless/injectable.

```
                ┌─────────────────────────────┐
   AppKit  ───► │ OverlayWindowController      │  borderless full-screen window,
                │ (KeyableWindow)              │  hosts SwiftUI via NSHostingView
                └──────────────┬──────────────┘
                               │ owns
                ┌──────────────▼──────────────┐
   State   ───► │ LaunchpadModel  @Observable  │  pages, query, selection, mode
                └───┬──────────────────────┬───┘
                    │ uses                  │ renders
        ┌───────────▼────────┐   ┌──────────▼───────────────┐
Services│ AppDiscoveryService│   │ SwiftUI view tree         │ UI
        │ IconLoader (cache) │   │  LaunchpadView            │
        │ LaunchService      │   │   ├ SearchPill (glass)    │
        │ LayoutStore (disk) │   │   ├ PagedGrid             │
        │ HotkeyManager      │   │   │   └ AppCell / FolderCell
        └────────────────────┘   │   └ PageDots (glass)      │
                                  └───────────────────────────┘
```

Data flow: services produce data → `LaunchpadModel` holds it → SwiftUI reads it. User actions call model methods → model mutates → UI re-renders. No view talks to a service directly except through the model.

---

## 4. Project structure

```
GlassPad/
├─ App/
│  ├─ GlassPadApp.swift          // @main, AppDelegate, menu-bar item
│  └─ AppDelegate.swift
├─ Window/
│  ├─ KeyableWindow.swift        // NSWindow subclass, canBecomeKey = true
│  └─ OverlayWindowController.swift
├─ Model/
│  ├─ InstalledApp.swift
│  ├─ LaunchpadItem.swift        // .app(InstalledApp) | .folder(Folder)
│  ├─ Page.swift
│  └─ LaunchpadModel.swift       // @Observable, the single source of UI truth
├─ Services/
│  ├─ AppDiscoveryService.swift  // scan + FSEvents watch
│  ├─ IconLoader.swift           // async load + NSCache
│  ├─ LaunchService.swift
│  ├─ LayoutStore.swift          // persist pages/folders to Application Support
│  └─ HotkeyManager.swift
├─ Views/
│  ├─ LaunchpadView.swift        // root: background + search + paged grid
│  ├─ SearchPill.swift           // glass capsule
│  ├─ PagedGrid.swift            // horizontal pages, dots, keyboard nav
│  ├─ AppCell.swift
│  ├─ FolderCell.swift           // morphs open via glassEffectID
│  ├─ FolderOverlay.swift
│  └─ PageDots.swift
├─ Design/
│  └─ Metrics.swift              // grid columns, icon sizes, spacing, durations
└─ Resources/
   └─ Assets.xcassets
```

Seed a `CLAUDE.md` at repo root from §10 conventions.

---

## 5. Data model

```swift
struct InstalledApp: Identifiable, Hashable {
    let id: String          // bundle path (stable, unique)
    let name: String
    let url: URL
    let bundleID: String?
}

enum LaunchpadItem: Identifiable, Hashable {
    case app(InstalledApp)
    case folder(Folder)
    var id: String { ... }
}

struct Folder: Identifiable, Hashable {
    let id: UUID
    var name: String
    var appIDs: [String]    // references InstalledApp.id
}

struct Page: Identifiable {
    let id: UUID
    var items: [LaunchpadItem]   // max grid capacity per page
}
```

Icons are intentionally **not** stored on the model — `IconLoader` resolves `NSImage` on demand and caches, so the model stays cheap/`Hashable`/`Sendable`-friendly.

`LayoutStore` persists `[Page]` (item order + folders) to `~/Library/Application Support/GlassPad/layout.json`. On launch: discover apps → merge with saved layout (new apps appended to last page, removed apps pruned).

---

## 6. Proven patterns (use these verbatim as the API baseline)

### Overlay window (AppKit) — the part SwiftUI can't do
```swift
final class KeyableWindow: NSWindow {
    override var canBecomeKey: Bool { true }   // borderless windows refuse key by default
    override var canBecomeMain: Bool { true }
}

// in the controller:
let window = KeyableWindow(contentRect: screen.frame,
                           styleMask: [.borderless],
                           backing: .buffered, defer: false)
window.isOpaque = false
window.backgroundColor = .clear
window.hasShadow = false
window.level = .screenSaver
window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
window.isReleasedWhenClosed = false
window.contentView = NSHostingView(rootView: LaunchpadView(...))
NSApp.activate(ignoringOtherApps: true)
window.makeKeyAndOrderFront(nil)
```

### Agent app (no Dock icon) + menu-bar toggle
```swift
NSApp.setActivationPolicy(.accessory)   // background utility, no Dock icon
let item = NSStatusBar.system.statusItem(withLength: .variableLength)
item.button?.image = NSImage(systemSymbolName: "square.grid.3x3.fill", accessibilityDescription: nil)
```

### App discovery (top level of each dir; don't recurse into .app bundles)
```swift
let searchPaths = ["/Applications", "/Applications/Utilities",
                   "/System/Applications", "/System/Applications/Utilities",
                   NSHomeDirectory() + "/Applications"]
// for each: FileManager.contentsOfDirectory(...).filter { $0.pathExtension == "app" }
// name: FileManager.default.displayName(atPath:)   icon: NSWorkspace.shared.icon(forFile:)
// launch: NSWorkspace.shared.openApplication(at:configuration:) with config.activates = true
```
For live updates, watch the search paths with **FSEvents** and re-scan on change (Phase 1 can poll; upgrade to FSEvents in Phase 5).

### Liquid Glass (real macOS 26 API — this is the whole point)
```swift
// functional chrome gets glass:
SearchField()
    .glassEffect(.regular.interactive(), in: .capsule)

// group many glass elements so they blend + render efficiently:
GlassEffectContainer(spacing: 24) {
    ForEach(items) { item in
        AppCell(item)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 22))
            .glassEffectID(item.id, in: namespace)   // enables morphing
    }
}
```
- `.glassEffect(_:in:)`, `GlassEffectContainer(spacing:)`, `.glassEffectID(_:in:)` with `@Namespace` — all **macOS 26.0+**.
- Folder open = morph the folder tile into the expanded panel using a shared `glassEffectID` + `@Namespace` and `withAnimation(.bouncy)`. This is the signature "liquid" moment — make it sing.

---

## 7. Design spec — make it indistinguishable from Apple

Match Launchpad's feel, then layer Tahoe glass on the chrome.

- **Background:** dim + blur the live desktop. Primary: capture wallpaper via **ScreenCaptureKit**, blur heavily, tint `black @ ~22%`. Fallback (no screen-recording permission): `.ultraThinMaterial` over `black @ 25%`. The blurred desktop is what the glass refracts — don't skip it.
- **Grid:** centered, ~**7 columns × 5 rows** per page on a standard display (derive from screen size, don't hardcode). Icon render size **~96–112pt**, label **SF Pro / `.system(size: 13)`**, single line, truncate tail, white with subtle shadow for legibility.
- **Search pill:** top-center, glass capsule, `magnifyingglass` leading symbol, auto-focused on appear (`@FocusState`).
- **Page dots:** bottom-center, glass, current page emphasized. Horizontal paging via scroll, trackpad swipe, arrow keys, and dot taps.
- **Motion:** spring everything (`.spring(response: 0.3, dampingFraction: 0.8)`). Icon scales up slightly on hover and "pops" on launch. Overlay fades+scales in from `0.96`.
- **Type system / spacing:** SF Pro, SF Symbols only, generous padding. Centralize all numbers in `Design/Metrics.swift`.
- **HIG discipline:** Liquid Glass belongs to the *functional* layer (search, folders, dots, controls) — **not** the content layer. So the icon grid itself should be light on glass: glass-on-hover for cells is the tasteful default; full per-cell glass is optional and must stay inside a `GlassEffectContainer` for perf.

---

## 8. Build phases (each ends with a buildable, runnable app + commit)

**Phase 0 — Skeleton.** Xcode project, macOS 26 target, agent app (`.accessory`), menu-bar item, borderless full-screen `KeyableWindow` showing a translucent empty SwiftUI view. Toggle show/hide from the menu-bar item. Esc dismisses.

**Phase 1 — It launches apps.** `AppDiscoveryService` + `IconLoader` + `LaunchService`. `LaunchpadModel` exposes a flat `[InstalledApp]`. Render a plain `LazyVGrid` (no glass yet), click launches + hides overlay. Verify every installed app shows with correct icon/name.

**Phase 2 — The Apple look.** Blurred-desktop background, real grid metrics, SF Pro labels, glass `SearchPill` (auto-focused), instant fuzzy filter. Apply `.glassEffect` to chrome; hover state on cells. This is where it should start looking shippable.

**Phase 3 — Paging + keyboard.** Split items into `Page`s sized to the screen. Horizontal paging (scroll/swipe/arrows), glass `PageDots`. Full keyboard nav: type→search, arrows→move selection, Return→launch, Esc→close.

**Phase 4 — Reorder, folders, persistence.** Drag-to-reorder within/across pages. Drag app onto app → create `Folder`. Folder opens with the glass **morph** transition (`glassEffectID`). `LayoutStore` persists and restores arrangement. New/removed apps reconcile on launch.

**Phase 5 — Polish + summon.** `KeyboardShortcuts` global hotkey (default e.g. ⌥Space, rebindable). FSEvents live re-scan. Launch-at-login (`SMAppService`). Animation pass, empty-search-state, multi-display: open on the screen with the cursor. Optional: Settings window for hotkey + columns + glass intensity.

---

## 9. Acceptance criteria (v1 "done")

- Summon via hotkey **and** menu bar; overlay covers the active screen, floats above the Dock/menu bar, dims+blurs the desktop.
- Shows 100% of apps from the five search paths with correct names/icons; new installs appear without restart.
- Type-to-filter is instant and fuzzy; full keyboard operation; Esc/empty-click/launch all dismiss.
- Drag reorder + folder creation work and **survive relaunch**.
- Glass is real `.glassEffect` (verify by toggling it off → UI clearly degrades), and folder-open morphs.
- Idle CPU ≈ 0; cold open < 300 ms with icons cached; no permission prompts unless ScreenCaptureKit wallpaper is enabled.

---

## 10. Gotchas, permissions, conventions (seed CLAUDE.md with this)

- **Glass needs macOS 26.** No back-deploy. Gate nothing; just require 26.
- **Borderless windows can't become key** unless you override `canBecomeKey` — without it, no typing, no Esc.
- **Global hotkey:** prefer `KeyboardShortcuts` over `NSEvent.addGlobalMonitorForEvents` (the latter needs Input-Monitoring/Accessibility permission). Carbon `RegisterEventHotKey` is the no-dep fallback.
- **ScreenCaptureKit wallpaper capture triggers a screen-recording permission prompt** — make it opt-in; ship the material fallback as default so the app works permission-free out of the box.
- **Icons:** load async off the main actor, cache in `NSCache` keyed by path, set a render size (e.g. 256pt) once.
- **Concurrency:** UI + AppKit on `@MainActor`; scanning/icon work off-main; model mutations back on main.
- **All design constants live in `Design/Metrics.swift`** — no magic numbers in views.
- **HIG:** glass on the functional layer only; keep the content grid restrained.
- **Commits:** one per phase, conventional-commit messages. Keep each phase buildable.

---

## 11. Stretch (post-v1, ignore for now)
Import the legacy Launchpad layout DB if recoverable; per-app uninstall (jiggle mode); categories/smart folders; iCloud layout sync; custom glass tint themes; Spotlight-style inline calculator/actions in the search bar.