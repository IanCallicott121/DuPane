#!/usr/bin/env swift
// Generates /Opus app icon PNGs at all required macOS sizes.
// Run from the project root: swift Scripts/make_icon.swift
import AppKit

let outputDir = "Sources/DOpusMac/Assets.xcassets/AppIcon.appiconset"

let sizes: [(name: String, px: Int)] = [
    ("icon_16x16",       16),
    ("icon_16x16@2x",    32),
    ("icon_32x32",       32),
    ("icon_32x32@2x",    64),
    ("icon_128x128",    128),
    ("icon_128x128@2x", 256),
    ("icon_256x256",    256),
    ("icon_256x256@2x", 512),
    ("icon_512x512",    512),
    ("icon_512x512@2x",1024),
]

// Draw directly into a CGContext at exact pixel dimensions (avoids Retina 2x scale).
func renderIcon(px: Int) -> Data? {
    let s = CGFloat(px)
    let cs = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(
        data: nil, width: px, height: px,
        bitsPerComponent: 8, bytesPerRow: px * 4,
        space: cs,
        bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
    ) else { return nil }

    // Use AppKit drawing APIs via NSGraphicsContext
    let nsCtx = NSGraphicsContext(cgContext: ctx, flipped: false)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = nsCtx

    // Rounded rect clip (macOS icon corner ratio ≈ 22%)
    let radius = s * 0.22
    let path = CGPath(roundedRect: CGRect(x: 0, y: 0, width: s, height: s),
                      cornerWidth: radius, cornerHeight: radius, transform: nil)
    ctx.addPath(path)
    ctx.clip()

    // Blue gradient background
    let colors = [CGColor(red: 0.20, green: 0.48, blue: 0.98, alpha: 1),
                  CGColor(red: 0.04, green: 0.20, blue: 0.70, alpha: 1)] as CFArray
    if let grad = CGGradient(colorsSpace: cs, colors: colors, locations: [0, 1]) {
        ctx.drawLinearGradient(grad,
                               start: CGPoint(x: s / 2, y: s),
                               end:   CGPoint(x: s / 2, y: 0),
                               options: [])
    }

    // "/" glyph — scale font to exact pixel size
    let fontSize = s * 0.68
    let font = NSFont(name: "SF Pro Display", size: fontSize)
            ?? NSFont.boldSystemFont(ofSize: fontSize)
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor.white,
    ]
    let str = NSAttributedString(string: "/", attributes: attrs)
    let ts = str.size()
    let tx = (s - ts.width)  / 2
    let ty = (s - ts.height) / 2 + s * 0.03
    str.draw(at: NSPoint(x: tx, y: ty))

    NSGraphicsContext.restoreGraphicsState()

    guard let cgImage = ctx.makeImage() else { return nil }
    let rep = NSBitmapImageRep(cgImage: cgImage)
    rep.size = NSSize(width: CGFloat(px), height: CGFloat(px))
    return rep.representation(using: .png, properties: [:])
}

for (name, px) in sizes {
    let path = "\(outputDir)/\(name).png"
    if let data = renderIcon(px: px) {
        do {
            try data.write(to: URL(fileURLWithPath: path))
            print("✓ \(name).png  (\(px)×\(px)px)")
        } catch {
            print("✗ \(name).png: \(error)")
        }
    } else {
        print("✗ \(name).png: render failed")
    }
}
print("Done — \(sizes.count) images written.")
