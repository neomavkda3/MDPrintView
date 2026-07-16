import SwiftUI
import AppKit

/// One preset swatch. `hex == nil` means "System default — no override."
struct TextColorSwatch: Hashable, Identifiable {
    let id: String
    let label: String
    let hex: String?

    static let system:       Self = .init(id: "system",        label: "System",        hex: nil)
    static let warmInk:      Self = .init(id: "warm-ink",      label: "Warm ink",      hex: "#5B4636")
    static let highContrast: Self = .init(id: "high-contrast", label: "High contrast", hex: "#111111")

    static let presets: [Self] = [.system, .warmInk, .highContrast]
}

extension TextColorSwatch {
    /// The preset that a stored hex value corresponds to, or nil if the
    /// value is a user-picked custom color. Case-insensitive on hex.
    static func matching(hex: String?) -> Self? {
        let target = hex?.uppercased()
        return presets.first { $0.hex?.uppercased() == target }
    }
}

/// Horizontal row of preset color swatches plus a "Custom…" ColorPicker
/// chip. Bound to a `String?` hex value: `nil` means System default. The
/// selected swatch is drawn with a ring around it.
struct SwatchStrip: View {
    @Binding var selection: String?
    /// Called after the user picks a color via the Custom… chip's
    /// NSColorPanel — currently unused by callers but reserved so a
    /// future preview / persistence action can tap in.
    let onCustomPicked: (NSColor) -> Void

    /// Local mirror of the picked custom color. Its `onChange` is our
    /// signal that NSColorPanel returned a value.
    @State private var customColor: Color = .black
    /// Set while `syncCustomFromSelection` is writing to `customColor`
    /// so its `.onChange` handler skips the round-trip back into
    /// `selection` (which would clobber external updates).
    @State private var syncingCustom = false

    var body: some View {
        HStack(spacing: 8) {
            ForEach(TextColorSwatch.presets) { swatch in
                let isSelected = TextColorSwatch.matching(hex: selection) == swatch
                SwatchCircle(swatch: swatch, isSelected: isSelected)
                    .onTapGesture { selection = swatch.hex }
                    .help(swatch.label)
                    .accessibilityLabel(swatch.label)
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
            // Custom… — a SwiftUI ColorPicker styled as a chip. Opens
            // NSColorPanel under the hood. Labels hidden; we control the
            // chrome via the container.
            ColorPicker(selection: $customColor, supportsOpacity: false) {
                Text("Custom…")
                    .font(.caption)
            }
            .labelsHidden()
            .accessibilityLabel("Custom color")
            .onChange(of: customColor) { _, new in
                guard !syncingCustom else { return }
                let ns = NSColor(new)
                selection = HexColor.hex(from: ns)
                onCustomPicked(ns)
            }
        }
        .onAppear { syncCustomFromSelection() }
        .onChange(of: selection) { _, _ in syncCustomFromSelection() }
    }

    /// Keep the Custom… chip's swatch in sync with the applied color
    /// so a user reopening the popover after picking a custom hex
    /// sees a visual echo of what's active (instead of an out-of-date
    /// .black chip). The `syncingCustom` guard prevents this write
    /// from triggering the reverse path in `.onChange(of: customColor)`.
    private func syncCustomFromSelection() {
        syncingCustom = true
        defer { syncingCustom = false }
        if let ns = HexColor.nsColor(from: selection) {
            customColor = Color(nsColor: ns)
        } else {
            customColor = Color(nsColor: .labelColor)
        }
    }
}

private struct SwatchCircle: View {
    let swatch: TextColorSwatch
    let isSelected: Bool

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 22, height: 22)
            .overlay(
                Circle().strokeBorder(
                    isSelected ? Color.accentColor : Color.secondary.opacity(0.3),
                    lineWidth: isSelected ? 2 : 1
                )
            )
            .overlay(
                // System swatch shows a split-color hint so users can tell
                // it isn't a specific color — half tinted with black overlay.
                Group {
                    if swatch == .system {
                        Circle()
                            .trim(from: 0, to: 0.5)
                            .fill(Color.black.opacity(0.15))
                            .rotationEffect(.degrees(-90))
                            .frame(width: 22, height: 22)
                    }
                }
            )
    }

    /// The color displayed for this swatch. System uses `labelColor` so
    /// it tracks Light/Dark; other presets use their fixed hex.
    private var color: Color {
        if let hex = swatch.hex, let ns = HexColor.nsColor(from: hex) {
            return Color(nsColor: ns)
        }
        return Color(nsColor: .labelColor)
    }
}
