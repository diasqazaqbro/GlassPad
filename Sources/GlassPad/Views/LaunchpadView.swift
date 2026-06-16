import SwiftUI

/// Root overlay view: dimmed/blurred backdrop behind a scrolling grid of apps.
/// Phase 1 renders a plain `LazyVGrid`; clicking a cell launches and dismisses.
struct LaunchpadView: View {
    let model: LaunchpadModel
    var onDismiss: () -> Void

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: 24, alignment: .top),
        count: 7
    )

    var body: some View {
        ZStack {
            backdrop
            ScrollView {
                LazyVGrid(columns: columns, spacing: 28) {
                    ForEach(model.apps) { app in
                        AppCell(app: app) {
                            model.launch(app)
                            onDismiss()
                        }
                    }
                }
                .padding(.horizontal, 64)
                .padding(.vertical, 48)
            }
        }
    }

    /// The blurred desktop the glass will later refract. The material samples the
    /// window backdrop (the live desktop); the black tint dims it.
    private var backdrop: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial)
            Rectangle().fill(.black.opacity(0.22))
        }
        .ignoresSafeArea()
    }
}
