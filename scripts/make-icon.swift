// Draws the app icon and writes Resources/AppIcon.icns.
// Run from the repo root: swift scripts/make-icon.swift
import AppKit

func draw(size: CGFloat) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = size / 1024

    // macOS icon grid: 824pt rounded square centred on a 1024 canvas.
    let tile = NSRect(x: 100 * s, y: 100 * s, width: 824 * s, height: 824 * s)
    let tilePath = NSBezierPath(roundedRect: tile, xRadius: 185 * s, yRadius: 185 * s)
    NSShadow().apply { $0.shadowColor = .black.withAlphaComponent(0.3); $0.shadowBlurRadius = 20 * s; $0.shadowOffset = NSSize(width: 0, height: -10 * s) }
    NSGradient(starting: NSColor(srgbRed: 0.30, green: 0.36, blue: 0.98, alpha: 1),
               ending: NSColor(srgbRed: 0.12, green: 0.10, blue: 0.38, alpha: 1))!.draw(in: tilePath, angle: -90)
    NSShadow().set()

    // Three stacked windows, back to front, the front one "selected".
    let windows: [(NSRect, CGFloat)] = [
        (NSRect(x: 330, y: 470, width: 440, height: 300), 0.35),
        (NSRect(x: 290, y: 400, width: 440, height: 300), 0.6),
        (NSRect(x: 250, y: 330, width: 440, height: 300), 1),
    ]
    for (frame, alpha) in windows {
        let rect = NSRect(x: frame.minX * s, y: frame.minY * s, width: frame.width * s, height: frame.height * s)
        let path = NSBezierPath(roundedRect: rect, xRadius: 36 * s, yRadius: 36 * s)
        NSShadow().apply { $0.shadowColor = .black.withAlphaComponent(0.35); $0.shadowBlurRadius = 24 * s; $0.shadowOffset = NSSize(width: 0, height: -8 * s) }
        NSColor.white.withAlphaComponent(alpha).setFill()
        path.fill()
        NSShadow().set()
        // Title bar dots.
        for (i, color) in [NSColor.systemRed, .systemYellow, .systemGreen].enumerated() {
            let dot = NSRect(x: rect.minX + (34 + CGFloat(i) * 40) * s, y: rect.maxY - 52 * s, width: 24 * s, height: 24 * s)
            color.withAlphaComponent(alpha).setFill()
            NSBezierPath(ovalIn: dot).fill()
        }
    }

    // ⌘ on the front window.
    let front = windows[2].0
    let font = NSFont.systemFont(ofSize: 190 * s, weight: .semibold)
    let glyph = NSAttributedString(string: "⌘", attributes: [.font: font, .foregroundColor: NSColor(srgbRed: 0.24, green: 0.27, blue: 0.85, alpha: 1)])
    let g = glyph.size()
    glyph.draw(at: NSPoint(x: front.midX * s - g.width / 2, y: (front.midY - 24) * s - g.height / 2))

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

extension NSShadow {
    func apply(_ configure: (NSShadow) -> Void) { configure(self); set() }
}

let iconset = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = scale == 1 ? "icon_\(base)x\(base).png" : "icon_\(base)x\(base)@2x.png"
        try draw(size: CGFloat(base * scale)).representation(using: .png, properties: [:])!
            .write(to: iconset.appendingPathComponent(name))
    }
}
let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", iconset.path, "-o", "Resources/AppIcon.icns"]
try task.run()
task.waitUntilExit()
try draw(size: 512).representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "Resources/AppIcon.png"))
print(task.terminationStatus == 0 ? "Wrote Resources/AppIcon.icns" : "iconutil failed")
