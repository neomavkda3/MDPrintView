import Foundation
import UniformTypeIdentifiers

/// Decides whether a dropped item is something MDPrintView can open.
/// Mirrors `MarkdownDocument.readableContentTypes` ([.markdown, .plainText]).
enum WelcomeDrop {

    /// True when `type` conforms to one of the app's readable content types.
    /// `net.daringfireball.markdown` conforms to `public.plain-text`, so the
    /// `.plainText` branch also covers markdown and any source/text subtype —
    /// identical to what the Open panel allows.
    static func accepts(_ type: UTType) -> Bool {
        type.conforms(to: .markdown) || type.conforms(to: .plainText)
    }

    /// True when the file at `url` resolves to an acceptable content type.
    /// Unknown / extensionless files resolve to `public.data` and are rejected,
    /// the same outcome as the Open panel. No content sniffing.
    static func accepts(_ url: URL) -> Bool {
        guard let type = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType
        else { return false }
        return accepts(type)
    }
}
