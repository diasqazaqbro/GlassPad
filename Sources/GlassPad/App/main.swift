import AppKit

// Pure AppKit bootstrap. SwiftUI scenes can't produce a borderless, all-Spaces,
// screen-saver-level overlay, so we own the NSApplication lifecycle ourselves
// and hand-build the window in OverlayWindowController.
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
