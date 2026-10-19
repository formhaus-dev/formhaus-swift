import AppKit

let width: CGFloat = 600
let height: CGFloat = 450
let purple = NSColor(srgbRed: 0x6A / 255, green: 0x2B / 255, blue: 0xFC / 255, alpha: 1)

func tint(_ alpha: CGFloat) -> NSColor {
    purple.withAlphaComponent(alpha)
}

func fill(_ rect: NSRect, _ alpha: CGFloat, radius: CGFloat = 8) {
    tint(alpha).setFill()
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
}

func window(_ rect: NSRect, alpha: CGFloat = 1, dashed: Bool = false) {
    let path = NSBezierPath(roundedRect: rect, xRadius: 18, yRadius: 18)
    tint(0.07 * alpha).setFill()
    path.fill()
    path.lineWidth = 4
    if dashed { path.setLineDash([14, 10], count: 2, phase: 0) }
    tint(0.55 * alpha).setStroke()
    path.stroke()
    let bar = NSRect(x: rect.minX, y: rect.maxY - 44, width: rect.width, height: 44)
    tint(0.3 * alpha).setFill()
    NSBezierPath(rect: NSRect(x: bar.minX, y: bar.minY, width: bar.width, height: 3)).fill()
    for index in 0..<3 {
        let dot = NSRect(x: rect.minX + 22 + CGFloat(index) * 22, y: bar.midY - 7, width: 14, height: 14)
        tint(0.4 * alpha).setFill()
        NSBezierPath(ovalIn: dot).fill()
    }
}

func content(of rect: NSRect) -> NSRect {
    NSRect(x: rect.minX + 28, y: rect.minY + 28, width: rect.width - 56, height: rect.height - 44 - 56)
}

func newSite() {
    let frame = NSRect(x: 60, y: 50, width: 480, height: 350)
    window(frame)
    let area = content(of: frame)
    fill(NSRect(x: area.minX, y: area.maxY - 110, width: area.width, height: 110), 0.22, radius: 10)
    fill(NSRect(x: area.minX + 24, y: area.maxY - 52, width: 190, height: 18), 0.7, radius: 9)
    fill(NSRect(x: area.minX + 24, y: area.maxY - 82, width: 130, height: 14), 0.4, radius: 7)
    let cardWidth = (area.width - 32) / 3
    for index in 0..<3 {
        let card = NSRect(x: area.minX + CGFloat(index) * (cardWidth + 16), y: area.minY, width: cardWidth, height: 116)
        fill(card, 0.14, radius: 10)
        fill(NSRect(x: card.minX + 16, y: card.maxY - 36, width: 32, height: 20), 0.55, radius: 6)
        fill(NSRect(x: card.minX + 16, y: card.minY + 36, width: card.width - 32, height: 10), 0.3, radius: 5)
        fill(NSRect(x: card.minX + 16, y: card.minY + 18, width: card.width - 56, height: 10), 0.3, radius: 5)
    }
}

func redesign() {
    let back = NSRect(x: 40, y: 110, width: 380, height: 290)
    let front = NSRect(x: 180, y: 40, width: 380, height: 290)
    NSGraphicsContext.saveGraphicsState()
    let outside = NSBezierPath(rect: NSRect(x: 0, y: 0, width: width, height: height))
    outside.append(NSBezierPath(roundedRect: front.insetBy(dx: -10, dy: -10), xRadius: 26, yRadius: 26))
    outside.windingRule = .evenOdd
    outside.addClip()
    window(back, alpha: 0.55, dashed: true)
    let old = content(of: back)
    fill(NSRect(x: old.minX, y: old.maxY - 40, width: 140, height: 16), 0.18)
    fill(NSRect(x: old.minX, y: old.minY + 60, width: 90, height: 90), 0.12)
    NSGraphicsContext.restoreGraphicsState()
    window(front)
    let area = content(of: front)
    fill(NSRect(x: area.minX, y: area.maxY - 96, width: area.width * 0.56, height: 96), 0.24, radius: 10)
    fill(NSRect(x: area.minX + area.width * 0.6, y: area.maxY - 96, width: area.width * 0.4, height: 96), 0.5, radius: 10)
    fill(NSRect(x: area.minX, y: area.minY + 26, width: area.width, height: 14), 0.3, radius: 7)
    fill(NSRect(x: area.minX, y: area.minY, width: area.width * 0.7, height: 14), 0.3, radius: 7)
    sparkle(at: NSPoint(x: 96, y: 62), size: 34)
    sparkle(at: NSPoint(x: 142, y: 30), size: 18)
}

func sparkle(at center: NSPoint, size: CGFloat) {
    let path = NSBezierPath()
    path.move(to: NSPoint(x: center.x, y: center.y + size))
    path.curve(
        to: NSPoint(x: center.x + size, y: center.y), controlPoint1: NSPoint(x: center.x + size * 0.12, y: center.y + size * 0.12),
        controlPoint2: NSPoint(x: center.x + size * 0.12, y: center.y + size * 0.12))
    path.curve(
        to: NSPoint(x: center.x, y: center.y - size), controlPoint1: NSPoint(x: center.x + size * 0.12, y: center.y - size * 0.12),
        controlPoint2: NSPoint(x: center.x + size * 0.12, y: center.y - size * 0.12))
    path.curve(
        to: NSPoint(x: center.x - size, y: center.y), controlPoint1: NSPoint(x: center.x - size * 0.12, y: center.y - size * 0.12),
        controlPoint2: NSPoint(x: center.x - size * 0.12, y: center.y - size * 0.12))
    path.curve(
        to: NSPoint(x: center.x, y: center.y + size), controlPoint1: NSPoint(x: center.x - size * 0.12, y: center.y + size * 0.12),
        controlPoint2: NSPoint(x: center.x - size * 0.12, y: center.y + size * 0.12))
    tint(0.85).setFill()
    path.fill()
}

func landingPage() {
    let frame = NSRect(x: 60, y: 50, width: 480, height: 350)
    window(frame)
    let area = content(of: frame)
    let middle = area.midX
    fill(NSRect(x: middle - 150, y: area.maxY - 60, width: 300, height: 26), 0.7, radius: 13)
    fill(NSRect(x: middle - 110, y: area.maxY - 98, width: 220, height: 14), 0.35, radius: 7)
    fill(NSRect(x: middle - 80, y: area.maxY - 122, width: 160, height: 14), 0.35, radius: 7)
    let button = NSRect(x: middle - 80, y: area.minY + 46, width: 160, height: 50)
    tint(1).setFill()
    NSBezierPath(roundedRect: button, xRadius: 25, yRadius: 25).fill()
    NSColor.white.withAlphaComponent(0.9).setFill()
    NSBezierPath(roundedRect: button.insetBy(dx: 40, dy: 19), xRadius: 6, yRadius: 6).fill()
    fill(NSRect(x: middle - 60, y: area.minY + 6, width: 120, height: 10), 0.25, radius: 5)
}

func onlineStore() {
    let frame = NSRect(x: 60, y: 50, width: 480, height: 350)
    window(frame)
    let area = content(of: frame)
    let size = NSSize(width: (area.width - 48) / 4, height: area.height - 8)
    for index in 0..<4 {
        let card = NSRect(x: area.minX + CGFloat(index) * (size.width + 16), y: area.minY, width: size.width, height: size.height)
        fill(card, 0.12, radius: 10)
        fill(NSRect(x: card.minX + 10, y: card.minY + 74, width: card.width - 20, height: card.height - 84), 0.3)
        fill(NSRect(x: card.minX + 10, y: card.minY + 52, width: card.width - 20, height: 10), 0.3, radius: 5)
        fill(NSRect(x: card.minX + 10, y: card.minY + 16, width: 48, height: 22), 0.75, radius: 11)
    }
}

func render(_ draw: () -> Void) -> Data {
    guard
        let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Int(width), pixelsHigh: Int(height), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
            isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
    else { fatalError("bitmap") }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    draw()
    NSGraphicsContext.restoreGraphicsState()
    guard let png = bitmap.representation(using: .png, properties: [:]) else { fatalError("png") }
    return png
}

let pictures: [(String, () -> Void)] = [
    ("new-site", newSite), ("redesign", redesign), ("landing-page", landingPage), ("online-store", onlineStore),
]
let definition = URL(fileURLWithPath: CommandLine.arguments[1])
var text = try String(contentsOf: definition, encoding: .utf8)
for (value, draw) in pictures {
    let uri = "data:image/png;base64," + render(draw).base64EncodedString()
    let pattern = "(\"value\": \"\(value)\"[^}]*\"image\": \")[^\"]*(\")"
    let regex = try NSRegularExpression(pattern: pattern)
    let range = NSRange(text.startIndex..., in: text)
    text = regex.stringByReplacingMatches(in: text, range: range, withTemplate: "$1\(uri)$2")
    if CommandLine.arguments.count > 2 {
        try render(draw).write(to: URL(fileURLWithPath: CommandLine.arguments[2]).appendingPathComponent("\(value).png"))
    }
}
try text.write(to: definition, atomically: true, encoding: .utf8)
