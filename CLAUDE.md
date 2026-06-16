# GlassPad — repo conventions

A native macOS Launchpad replacement with real Liquid Glass. See `plan.md` for the full vision and phased build plan. **Implement phase by phase; keep every phase buildable.**

## Toolchain (hard requirements)
- **macOS 26.0+** deployment target. No back-deploy. `.glassEffect` is macOS 26 only — gate nothing, just require 26.
- Xcode 26 / Swift 6, **strict concurrency** (Swift 6 language mode).
- Build & run: this is a **SwiftPM executable** (`Package.swift`). `swift build` to compile, `swift run GlassPad` to launch. Also opens directly in Xcode 26 (open the folder / `Package.swift`).
- Distribution / launch-at-login / clean TCC identity need a real `.app` bundle: `Scripts/make-app-bundle.sh` wraps the built binary into `dist/GlassPad.app`.

## Architecture (unidirectional)
Services produce data → `LaunchpadModel` (`@Observable`) holds it → SwiftUI reads it. User actions call model methods → model mutates → UI re-renders. **No view talks to a service directly except through the model.** The overlay window is hand-built in AppKit (`OverlayWindowController` + `KeyableWindow`) because SwiftUI scenes can't be borderless / all-Spaces / screen-saver level.

## Conventions
- **All design constants live in `Design/Metrics.swift`** — no magic numbers in views.
- **Liquid Glass on the *functional* layer only** (search pill, folders, page dots, controls). Keep the content icon grid restrained: glass-on-hover for cells is the tasteful default; full per-cell glass must stay inside a `GlassEffectContainer`.
- **Concurrency:** UI + AppKit on `@MainActor`; app scanning / icon decoding off-main; model mutations back on main. Keep model types `Sendable`/`Hashable`-friendly — icons are resolved on demand by `IconLoader`, never stored on the model.
- **SF Pro + SF Symbols only.** No bundled image assets in v1.
- **Icons:** load async off the main actor, cache in `NSCache` keyed by bundle path, render at a fixed size once.
- Borderless windows can't become key unless `canBecomeKey` is overridden (`KeyableWindow`) — without it, no typing, no Esc.
- Global hotkey: `KeyboardShortcuts` (Sindre Sorhus) to avoid Accessibility/Input-Monitoring permission.
- ScreenCaptureKit wallpaper capture is **opt-in** (triggers a screen-recording prompt). Default to the `.ultraThinMaterial` fallback so the app works permission-free.

## Commits
One commit per phase, conventional-commit messages. Each phase must build, run, and be visually verifiable.

## Current status
- Phase 0 — Skeleton: ✅ done.
