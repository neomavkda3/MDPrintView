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

let bgRect = NSRect(origin: .zero, size: size)
NSColor(srgbRed: 0.96, green: 0.97, blue: 0.99, alpha: 1.0).setFill()
NSBezierPath(roundedRect: bgRect, xRadius: 180, yRadius: 180).fill()

NSColor(srgbRed: 0.85, green: 0.86, blue: 0.88, alpha: 1.0).setStroke()
let stroke = NSBezierPath(roundedRect: bgRect.insetBy(dx: 2, dy: 2), xRadius: 178, yRadius: 178)
stroke.lineWidth = 4
stroke.stroke()

let text = "md" as NSString
let attrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 460, weight: .heavy),
    .foregroundColor: NSColor(srgbRed: 0.16, green: 0.38, blue: 0.88, alpha: 1.0)
]
let textSize = text.size(withAttributes: attrs)
let point = NSPoint(
    x: (size.width - textSize.width) / 2,
    y: (size.height - textSize.height) / 2 - 20
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
