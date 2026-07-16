import AppKit

/// Hex-string persistence for user-picked colors. `nil` means "no override,
/// use the dynamic system default." Round-trips through `@AppStorage` as a
/// `String?`, so it works with the codebase's existing settings pattern.
enum HexColor {

    /// Parse a `#RRGGBB` (or `RRGGBB`) hex string into a sRGB `NSColor`.
    /// Returns nil for nil / empty / malformed input.
    static func nsColor(from hex: String?) -> NSColor? {
        guard var s = hex, !s.isEmpty else { return nil }
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let value = UInt32(s, radix: 16) else { return nil }
        let r = CGFloat((value >> 16) & 0xFF) / 255.0
        let g = CGFloat((value >>  8) & 0xFF) / 255.0
        let b = CGFloat( value        & 0xFF) / 255.0
        return NSColor(srgbRed: r, green: g, blue: b, alpha: 1.0)
    }

    /// Emit `#RRGGBB` from any `NSColor`. Converts to sRGB first so device-
    /// dependent colors (like `NSColor.textColor`) still produce a usable
    /// hex value.
    static func hex(from color: NSColor) -> String {
        let rgb = color.usingColorSpace(.sRGB) ?? color
        let r = Int(round(rgb.redComponent   * 255))
        let g = Int(round(rgb.greenComponent * 255))
        let b = Int(round(rgb.blueComponent  * 255))
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
