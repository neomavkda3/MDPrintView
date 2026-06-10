// scripts/generate-icon.swift
//
// Generate a 1024×1024 PNG placeholder app icon. Run via:
//   swift scripts/generate-icon.swift
//   for size in 16 32 128 256 512; do
//       sips -z $size $size /tmp/mdview-icon-1024.png \
//           --out mdview/Assets.xcassets/AppIcon.appiconset/icon_${size}x${size}.png
//       sips -z $((size*2)) $((size*2)) /tmp/mdview-icon-1024.png \
//           --out mdview/Assets.xcassets/AppIcon.appiconset/icon_${size}x${size}@2x.png
//   done
//
// REPLACE THE PLACEHOLDER WITH REAL ARTWORK before submitting to App Review —
// Apple rejects default-looking icons under Guideline 4.0 Design.

import AppKit
import Foundation

let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)
image.lockFocus()

// Background: rounded squircle with a soft vertical gradient that hints at
// "paper" — light at the top, slightly warmer at the bottom.
let bgRect = NSRect(origin: .zero, size: size)
let squircle = NSBezierPath(roundedRect: bgRect, xRadius: 180, yRadius: 180)
squircle.addClip()

let gradient = NSGradient(colors: [
    NSColor(srgbRed: 0.99, green: 0.99, blue: 1.00, alpha: 1.0),  // near-white
    NSColor(srgbRed: 0.94, green: 0.95, blue: 0.97, alpha: 1.0)   // cool grey
])
gradient?.draw(in: bgRect, angle: 270)

// Subtle inner stroke for definition.
NSColor(srgbRed: 0.82, green: 0.84, blue: 0.88, alpha: 1.0).setStroke()
let stroke = NSBezierPath(roundedRect: bgRect.insetBy(dx: 4, dy: 4), xRadius: 176, yRadius: 176)
stroke.lineWidth = 8
stroke.stroke()

// Accent bar — left margin, the SwiftUI-blue we use for links throughout the app.
// Reads as a "document margin" hint at small sizes.
let accentColor = NSColor(srgbRed: 0.16, green: 0.38, blue: 0.88, alpha: 1.0)
accentColor.setFill()
let accentBar = NSBezierPath(roundedRect: NSRect(x: 175, y: 220, width: 20, height: 580), xRadius: 10, yRadius: 10)
accentBar.fill()

// "md" wordmark — heavy weight, properly centered, dark navy ink.
let inkColor = NSColor(srgbRed: 0.10, green: 0.14, blue: 0.24, alpha: 1.0)
let text = "md" as NSString
let attrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 540, weight: .heavy),
    .foregroundColor: inkColor,
    .kern: -18 as NSNumber
]
let textSize = text.size(withAttributes: attrs)
let point = NSPoint(
    x: (size.width - textSize.width) / 2 + 30,  // shift right of the accent bar
    y: (size.height - textSize.height) / 2 - 40
)
text.draw(at: point, withAttributes: attrs)

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write("Failed to encode PNG\n".data(using: .utf8)!)
    exit(1)
}
try png.write(to: URL(fileURLWithPath: "/tmp/mdview-icon-1024.png"))
print("Wrote /tmp/mdview-icon-1024.png")
