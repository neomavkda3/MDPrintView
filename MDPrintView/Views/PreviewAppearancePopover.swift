import SwiftUI

/// The "Aa" popover for preview appearance: theme, font size, and
/// text color. All three rows live-apply through AppSettings; no
/// explicit save. Matches the near-universal reading-app pattern
/// (Apple Books, Bear, Reeder) from the Mobbin audit.
struct PreviewAppearancePopover: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings

        VStack(alignment: .leading, spacing: 14) {
            row("Theme") {
                HStack(spacing: 8) {
                    ForEach(PreviewTheme.allCases) { theme in
                        ThemeSwatch(theme: theme,
                                    isSelected: settings.previewTheme == theme)
                            .onTapGesture { settings.previewTheme = theme }
                            .help(theme.label)
                            .accessibilityLabel(theme.label)
                            .accessibilityAddTraits(.isButton)
                            .accessibilityAddTraits(settings.previewTheme == theme ? .isSelected : [])
                    }
                }
            }
            row("Font size") {
                HStack(spacing: 6) {
                    Image(systemName: "textformat.size.smaller")
                        .foregroundStyle(.secondary)
                    Slider(value: $settings.previewFontSize, in: 12...24, step: 1)
                    Image(systemName: "textformat.size.larger")
                        .foregroundStyle(.secondary)
                    Text("\(Int(settings.previewFontSize)) pt")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 40, alignment: .trailing)
                }
            }
            row("Text color") {
                SwatchStrip(selection: $settings.previewTextColor,
                            onCustomPicked: { _ in })
            }
        }
        .padding(16)
        .frame(width: 340)
    }

    private func row<Content: View>(_ label: String,
                                     @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text(label)
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Split-color circle showing the theme's background (top) and text (bottom).
/// Used only inside the Aa popover; kept private to this file.
private struct ThemeSwatch: View {
    let theme: PreviewTheme
    let isSelected: Bool

    var body: some View {
        Circle()
            .fill(bg)
            .frame(width: 22, height: 22)
            .overlay(
                Circle()
                    .trim(from: 0, to: 0.5)
                    .fill(fg)
                    .rotationEffect(.degrees(-90))
                    .frame(width: 22, height: 22)
            )
            .overlay(
                Circle().strokeBorder(
                    isSelected ? Color.accentColor : Color.secondary.opacity(0.3),
                    lineWidth: isSelected ? 2 : 1
                )
            )
    }

    // KEEP IN SYNC with MDPrintView/Preview/Resources/preview.css
    // (`body.theme-<name>` rules). If you change a theme's palette in
    // one place, mirror it here so the popover swatch matches what
    // users actually see in the preview.
    private var bg: Color {
        switch theme {
        case .original: return Color(nsColor: .textBackgroundColor)
        case .sepia:    return Color(red: 0.957, green: 0.925, blue: 0.847)  // #f4ecd8
        case .quiet:    return Color(red: 0.961, green: 0.961, blue: 0.941)  // #f5f5f0
        case .focus:    return Color(red: 0.102, green: 0.102, blue: 0.110)  // #1a1a1c
        }
    }
    private var fg: Color {
        switch theme {
        case .original: return Color(nsColor: .labelColor)
        case .sepia:    return Color(red: 0.357, green: 0.275, blue: 0.212)  // #5b4636
        case .quiet:    return Color(red: 0.180, green: 0.180, blue: 0.180)  // #2e2e2e
        case .focus:    return Color(red: 0.902, green: 0.902, blue: 0.902)  // #e6e6e6
        }
    }
}
