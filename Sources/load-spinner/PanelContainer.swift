import LoadSpinnerCore
import SwiftUI

/// The click-to-open popover has two faces: the status readout (front) and the
/// settings (back). Tapping the gear flips to settings; tapping the back chevron
/// flips back. Both toggles sit in the top-right corner so the control never moves.
///
/// The popover height follows whichever face is showing (the status face is
/// shorter than settings), animating between the two natural heights in step with
/// the flip — so the status face is not padded out to the settings height. Each
/// face is measured at its natural size via `.fixedSize`, independent of the
/// height the container is currently constrained to. See
/// docs/adr/0003-settings-on-popover-back.md.
struct PanelContainer: View {
    @ObservedObject var model: AppModel
    var onQuit: () -> Void

    @State private var showingSettings = false
    @State private var frontHeight: CGFloat = 0
    @State private var backHeight: CGFloat = 0

    private var displayHeight: CGFloat? {
        let height = showingSettings ? backHeight : frontHeight
        return height > 0 ? height : nil
    }

    var body: some View {
        ZStack(alignment: .top) {
            PanelView(
                model: model,
                onOpenSettings: { showingSettings = true },
                onQuit: onQuit
            )
            .fixedSize(horizontal: false, vertical: true)
            .modifier(MeasureHeight(height: $frontHeight))
            // Front is visible through the first half of the turn; it fades out as
            // it rotates edge-on, so its back side is never seen mirrored.
            .opacity(showingSettings ? 0 : 1)
            .animation(.easeInOut(duration: 0.2), value: showingSettings)

            SettingsView(model: model, onBack: { showingSettings = false })
                .fixedSize(horizontal: false, vertical: true)
                .modifier(MeasureHeight(height: $backHeight))
                // Pre-rotated so it reads correctly once the container reaches 180°.
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                // Back fades in only after the midpoint, so the two faces never
                // overlap on screen during the flip.
                .opacity(showingSettings ? 1 : 0)
                .animation(.easeInOut(duration: 0.2).delay(0.2), value: showingSettings)
        }
        // Constrain to the active face's height (animated with the flip). The
        // inactive, taller face overflows this frame but is hidden, so it is unseen.
        .frame(height: displayHeight, alignment: .top)
        .rotation3DEffect(
            .degrees(showingSettings ? 180 : 0),
            axis: (x: 0, y: 1, z: 0),
            perspective: 0.35
        )
        .animation(.easeInOut(duration: 0.4), value: showingSettings)
    }
}

/// Reports a view's laid-out height back to a binding. Pair with `.fixedSize`
/// (vertical) on the measured view so it reports its *natural* height regardless of
/// any height the parent later constrains it to.
private struct MeasureHeight: ViewModifier {
    @Binding var height: CGFloat

    func body(content: Content) -> some View {
        content.background(
            GeometryReader { proxy in
                Color.clear.preference(key: HeightPreferenceKey.self, value: proxy.size.height)
            }
        )
        .onPreferenceChange(HeightPreferenceKey.self) { newHeight in
            height = newHeight
        }
    }
}

private struct HeightPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
