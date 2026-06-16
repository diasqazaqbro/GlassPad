import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    /// Global summon shortcut. Default: ⌥Space. User-rebindable via the Recorder
    /// in Settings. KeyboardShortcuts avoids the Accessibility/Input-Monitoring
    /// permission that a raw global NSEvent monitor would require.
    // The Name is an immutable value; `nonisolated(unsafe)` satisfies Swift 6's
    // global-state check without forcing an actor onto this constant.
    nonisolated(unsafe) static let toggleGlassPad = Self("toggleGlassPad", default: .init(.space, modifiers: [.option]))
}

@MainActor
enum HotkeyManager {
    static func register(onToggle: @escaping () -> Void) {
        KeyboardShortcuts.onKeyDown(for: .toggleGlassPad, action: onToggle)
    }
}
