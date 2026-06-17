import CMultitouch
import Foundation

/// Detects the 4-finger trackpad pinch — *inward* to summon GlassPad, *outward*
/// (spread) to dismiss it — mirroring the system app-launcher gesture it replaces.
///
/// Contact frames arrive on MultitouchSupport's own callback thread; all gesture
/// state below is therefore touched only from that thread, and the fire closures
/// hop to the main actor. Falls back silently (returns false) if the private
/// framework can't be loaded — ⌥Space still works.
final class TrackpadPinchMonitor: @unchecked Sendable {
    static let shared = TrackpadPinchMonitor()
    private init() {}

    private var onPinchIn: (@MainActor () -> Void)?
    private var onPinchOut: (@MainActor () -> Void)?

    // Gesture state — only ever read/written on the multitouch callback thread.
    private var tracking = false
    private var maxSpread: Float = 0
    private var minSpread: Float = 0
    private var fired = false   // one action per finger-down, reset on lift

    // Tuning (normalized trackpad units, 0…1). A pinch must change the finger
    // spread by `pinchDelta` from its extreme, having been at least `minActive`
    // wide/narrow — enough to ignore resting fingers and 4-finger swipes (which
    // translate but barely change spread).
    private let pinchDelta: Float = 0.045
    private let minActiveSpread: Float = 0.05

    @discardableResult
    func start(onPinchIn: @escaping @MainActor () -> Void,
               onPinchOut: @escaping @MainActor () -> Void) -> Bool {
        self.onPinchIn = onPinchIn
        self.onPinchOut = onPinchOut
        let ok = gp_multitouch_start(trackpadContactCallback) == 1
        if !ok { NSLog("GlassPad: MultitouchSupport unavailable — pinch gesture disabled") }
        return ok
    }

    func stop() { gp_multitouch_stop() }

    /// Called on the multitouch thread for every contact frame.
    func handleFrame(count: Int, xs: UnsafePointer<Float>, ys: UnsafePointer<Float>) {
        // Apple's "pinch" is thumb + three fingers = exactly four contacts.
        guard count == 4 else {
            tracking = false
            return
        }

        var cx: Float = 0, cy: Float = 0
        for i in 0 ..< 4 { cx += xs[i]; cy += ys[i] }
        cx /= 4; cy /= 4

        var spread: Float = 0
        for i in 0 ..< 4 {
            let dx = xs[i] - cx, dy = ys[i] - cy
            spread += (dx * dx + dy * dy).squareRoot()
        }
        spread /= 4

        if !tracking {
            tracking = true
            maxSpread = spread
            minSpread = spread
            fired = false
            return
        }

        maxSpread = max(maxSpread, spread)
        minSpread = min(minSpread, spread)

        // At most one action per finger-down; `tracking` resets when a finger lifts.
        guard !fired else { return }

        // Inward: started apart, now meaningfully closer.
        if maxSpread > minActiveSpread, (maxSpread - spread) > pinchDelta {
            fired = true
            fire(onPinchIn)
        }
        // Outward: spread meaningfully wider than its narrowest point.
        else if spread > minActiveSpread, (spread - minSpread) > pinchDelta {
            fired = true
            fire(onPinchOut)
        }
    }

    private func fire(_ closure: (@MainActor () -> Void)?) {
        guard let closure else { return }
        DispatchQueue.main.async { MainActor.assumeIsolated { closure() } }
    }
}

/// C-compatible (non-capturing) trampoline handed to the MultitouchSupport shim.
private func trackpadContactCallback(_ count: Int32,
                                     _ xs: UnsafePointer<Float>?,
                                     _ ys: UnsafePointer<Float>?) {
    guard let xs, let ys else { return }
    TrackpadPinchMonitor.shared.handleFrame(count: Int(count), xs: xs, ys: ys)
}
