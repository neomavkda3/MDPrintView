import Foundation

/// GitHub-parity HTML sanitizer for raw HTML embedded in markdown.
/// Mirrors the allowlist of GitHub's html-pipeline SanitizationFilter, so a
/// README that renders on GitHub renders the same way here — and a hostile
/// document can't execute script in the preview WKWebView (whose CSP allows
/// 'unsafe-inline' for Mermaid, so escaping-or-sanitizing is load-bearing).
///
/// Works on fragments: swift-markdown delivers inline HTML as separate nodes
/// ("<sup>", text, "</sup>"), so lone open/close tags are valid input.
enum HTMLSanitizer {

    /// Tags GitHub allows (html-pipeline SanitizationFilter).
    private static let allowedTags: Set<String> = [
        "h1", "h2", "h3", "h4", "h5", "h6", "br", "b", "i", "strong", "em",
        "a", "pre", "code", "img", "tt", "div", "ins", "del", "sup", "sub",
        "p", "ol", "ul", "table", "thead", "tbody", "tfoot", "blockquote",
        "dl", "dt", "dd", "kbd", "q", "samp", "var", "hr", "ruby", "rt", "rp",
        "li", "tr", "td", "th", "s", "strike", "summary", "details",
        "caption", "figure", "figcaption", "abbr", "bdo", "cite", "dfn",
        "mark", "small", "span", "time", "wbr",
    ]

    /// Tags whose CONTENTS are code, not prose — dropped entirely.
    private static let dropWithContents: Set<String> = [
        "script", "style", "iframe", "object", "embed",
    ]

    /// GitHub's global attribute set (applies to every allowed tag).
    private static let globalAttributes: Set<String> = [
        "abbr", "accept", "accept-charset", "accesskey", "action", "align",
        "alt", "axis", "border", "cellpadding", "cellspacing", "char",
        "charoff", "charset", "checked", "clear", "cols", "colspan", "color",
        "compact", "coords", "datetime", "dir", "disabled", "enctype", "for",
        "frame", "headers", "height", "hreflang", "hspace", "ismap", "label",
        "lang", "maxlength", "media", "method", "multiple", "name", "nohref",
        "noshade", "nowrap", "open", "progress", "prompt", "rel", "rev",
        "rows", "rowspan", "rules", "scope", "selected", "shape", "size",
        "span", "start", "summary", "tabindex", "target", "title", "type",
        "usemap", "valign", "value", "vspace", "width", "itemprop",
    ]

    /// Per-tag extras on top of the global set.
    private static let perTagAttributes: [String: Set<String>] = [
        "a": ["href"],
        "img": ["src", "longdesc"],
        "div": ["itemscope", "itemtype"],
        "blockquote": ["cite"],
        "del": ["cite"],
        "ins": ["cite"],
        "q": ["cite"],
    ]

    /// Attributes whose value is a URL and needs a scheme check.
    private static let urlAttributes: Set<String> = ["href", "src", "cite", "longdesc"]

    /// Schemes allowed in URL attributes. mailto is href-only in GitHub's
    /// config; allowing it on the other three URL attrs is harmless.
    private static let allowedSchemes: Set<String> = ["http", "https", "mailto"]

    static func sanitize(_ html: String) -> String {
        var out = ""
        let chars = Array(html)
        var i = 0

        while i < chars.count {
            guard chars[i] == "<" else {
                // Plain text between tags: escape it.
                out += escapeChar(chars[i])
                i += 1
                continue
            }

            // Comment?
            if matches(chars, at: i, "<!--") {
                guard let end = find(chars, from: i + 4, "-->") else {
                    // Unterminated comment: drop the rest (comments are never content).
                    return out
                }
                i = end + 3
                continue
            }

            // Try to parse a tag. Failure = not actually a tag.
            guard let tag = parseTag(chars, at: i) else {
                // Stray "<" followed by non-tag text ("a < b"): escape the "<".
                if let gt = find(chars, from: i + 1, ">"), isTagLike(chars, from: i + 1, to: gt) {
                    // Looked like a tag but didn't parse (malformed attrs etc.):
                    // fail closed — escape the remainder verbatim.
                    out += htmlEscape(String(chars[i...]))
                    return out
                }
                if find(chars, from: i + 1, ">") == nil, isTagStart(chars, at: i + 1) {
                    // Unterminated tag ("<div align=\"c"): fail closed.
                    out += htmlEscape(String(chars[i...]))
                    return out
                }
                out += "&lt;"
                i += 1
                continue
            }

            i = tag.end

            if dropWithContents.contains(tag.name) {
                // Drop the element INCLUDING its contents.
                if !tag.isClosing, !tag.isSelfClosing {
                    if let closeEnd = findClosingTag(chars, from: i, name: tag.name) {
                        i = closeEnd
                    } else {
                        return out  // unterminated: drop rest, contents are code
                    }
                }
                continue
            }

            guard allowedTags.contains(tag.name) else { continue }  // strip tag, keep flow

            if tag.isClosing {
                out += "</\(tag.name)>"
            } else {
                out += "<\(tag.name)"
                for (name, value) in tag.attributes where attributeAllowed(name, for: tag.name) {
                    if urlAttributes.contains(name) {
                        guard let value, schemeAllowed(value) else { continue }
                        out += " \(name)=\"\(htmlEscape(value))\""
                    } else if let value {
                        out += " \(name)=\"\(htmlEscape(value))\""
                    } else {
                        out += " \(name)"
                    }
                }
                out += ">"
            }
        }
        return out
    }

    // MARK: - Policy helpers

    private static func attributeAllowed(_ name: String, for tag: String) -> Bool {
        if name.hasPrefix("on") || name == "style" { return false }
        return globalAttributes.contains(name) || (perTagAttributes[tag]?.contains(name) ?? false)
    }

    /// Scheme check on a lowercased copy with ASCII control/space chars
    /// stripped, defeating "jAva\tscript:" obfuscation. No colon before any
    /// path/query/fragment delimiter = relative or anchor = allowed.
    private static func schemeAllowed(_ value: String) -> Bool {
        let cleaned = value.lowercased().unicodeScalars
            .filter { $0.value > 0x20 }
            .map(Character.init)
        guard let colon = cleaned.firstIndex(of: ":") else { return true }
        if let delim = cleaned.firstIndex(where: { $0 == "/" || $0 == "?" || $0 == "#" }),
           delim < colon {
            return true  // colon appears after a delimiter: not a scheme
        }
        return allowedSchemes.contains(String(cleaned[..<colon]))
    }

    // MARK: - Tokenizer

    private struct Tag {
        var name: String
        var isClosing: Bool
        var isSelfClosing: Bool
        var attributes: [(String, String?)]
        var end: Int  // index just past the ">"
    }

    private static func escapeChar(_ c: Character) -> String {
        switch c {
        case "&": return "&amp;"
        case "<": return "&lt;"
        case ">": return "&gt;"
        case "\"": return "&quot;"
        case "'": return "&#39;"
        default: return String(c)
        }
    }

    private static func matches(_ chars: [Character], at i: Int, _ s: String) -> Bool {
        let pat = Array(s)
        guard i + pat.count <= chars.count else { return false }
        return Array(chars[i..<(i + pat.count)]) == pat
    }

    private static func find(_ chars: [Character], from: Int, _ s: String) -> Int? {
        let pat = Array(s)
        guard !pat.isEmpty else { return nil }
        var i = from
        while i + pat.count <= chars.count {
            if Array(chars[i..<(i + pat.count)]) == pat { return i }
            i += 1
        }
        return nil
    }

    private static func isTagStart(_ chars: [Character], at i: Int) -> Bool {
        guard i < chars.count else { return false }
        return chars[i].isLetter || chars[i] == "/"
    }

    /// Rough check: does the span look like it was meant to be a tag
    /// (starts with a letter or "/", no second "<" inside)?
    private static func isTagLike(_ chars: [Character], from: Int, to: Int) -> Bool {
        guard isTagStart(chars, at: from) else { return false }
        return !chars[from..<to].contains("<")
    }

    /// Parse one tag starting at `chars[start] == "<"`. Returns nil if the
    /// span is not a well-formed tag.
    private static func parseTag(_ chars: [Character], at start: Int) -> Tag? {
        var i = start + 1
        guard i < chars.count else { return nil }

        var isClosing = false
        if chars[i] == "/" { isClosing = true; i += 1 }

        // Tag name: letters/digits, must start with a letter.
        guard i < chars.count, chars[i].isLetter else { return nil }
        var name = ""
        while i < chars.count, chars[i].isLetter || chars[i].isNumber {
            name.append(chars[i]); i += 1
        }
        name = name.lowercased()

        var attributes: [(String, String?)] = []
        var isSelfClosing = false

        while i < chars.count {
            // Skip whitespace.
            while i < chars.count, chars[i].isWhitespace { i += 1 }
            guard i < chars.count else { return nil }  // unterminated

            if chars[i] == ">" {
                return Tag(name: name, isClosing: isClosing,
                           isSelfClosing: isSelfClosing, attributes: attributes, end: i + 1)
            }
            if chars[i] == "/" {
                isSelfClosing = true; i += 1; continue
            }
            if isClosing { return nil }  // closing tags take no attributes

            // Attribute name.
            guard chars[i].isLetter else { return nil }
            var attrName = ""
            while i < chars.count,
                  chars[i].isLetter || chars[i].isNumber || chars[i] == "-" || chars[i] == "_" {
                attrName.append(chars[i]); i += 1
            }
            attrName = attrName.lowercased()

            while i < chars.count, chars[i].isWhitespace { i += 1 }

            // Value?
            if i < chars.count, chars[i] == "=" {
                i += 1
                while i < chars.count, chars[i].isWhitespace { i += 1 }
                guard i < chars.count else { return nil }
                var value = ""
                if chars[i] == "\"" || chars[i] == "'" {
                    let quote = chars[i]; i += 1
                    while i < chars.count, chars[i] != quote {
                        value.append(chars[i]); i += 1
                    }
                    guard i < chars.count else { return nil }  // unterminated quote
                    i += 1
                } else {
                    while i < chars.count, !chars[i].isWhitespace, chars[i] != ">" {
                        value.append(chars[i]); i += 1
                    }
                }
                attributes.append((attrName, value))
            } else {
                attributes.append((attrName, nil))
            }
        }
        return nil  // ran off the end without ">"
    }

    /// Find `</name` (case-insensitive) at or after `from`.
    /// Returns the index just past that closing tag's ">".
    private static func findClosingTag(_ chars: [Character], from: Int, name: String) -> Int? {
        var i = from
        while i < chars.count {
            if chars[i] == "<", i + 1 < chars.count, chars[i + 1] == "/" {
                var j = i + 2
                var candidate = ""
                while j < chars.count, chars[j].isLetter || chars[j].isNumber {
                    candidate.append(chars[j]); j += 1
                }
                if candidate.lowercased() == name {
                    while j < chars.count, chars[j] != ">" { j += 1 }
                    return j < chars.count ? j + 1 : nil
                }
            }
            i += 1
        }
        return nil
    }
}
