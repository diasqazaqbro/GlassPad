import AppKit

/// Borderless windows refuse to become key/main by default, which kills typing
/// and Esc handling. Overriding these restores normal keyboard behaviour.
final class KeyableWindow: NSWindow {
    /// Invoked when the user presses Esc (`cancelOperation`) and nothing in the
    /// responder chain consumed it.
    var onCancel: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }
}
