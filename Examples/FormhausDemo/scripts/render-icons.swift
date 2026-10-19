import AppKit

let arguments = CommandLine.arguments
let source = try String(contentsOf: URL(fileURLWithPath: arguments[1]), encoding: .utf8)
let catalog = URL(fileURLWithPath: arguments[2])
let mark = source.replacingOccurrences(of: #"viewBox="[^"]*""#, with: #"viewBox="0 0 100 100""#, options: .regularExpression)
guard let image = NSImage(data: Data(mark.utf8)) else { fatalError("Cannot read \(arguments[1])") }

func png(size: Int, inset: CGFloat, radius: CGFloat, opaque: Bool) -> Data {
    let alpha = opaque ? CGImageAlphaInfo.noneSkipLast : .premultipliedLast
    guard let space = CGColorSpace(name: CGColorSpace.sRGB),
        let context = CGContext(
            data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0, space: space, bitmapInfo: alpha.rawValue)
    else { fatalError("context") }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
    NSGraphicsContext.current?.imageInterpolation = .high
    let side = CGFloat(size)
    let rect = NSRect(x: 0, y: 0, width: side, height: side).insetBy(dx: side * inset, dy: side * inset)
    NSBezierPath(roundedRect: rect, xRadius: rect.width * radius, yRadius: rect.width * radius).addClip()
    image.draw(in: rect)
    NSGraphicsContext.restoreGraphicsState()
    guard let cgImage = context.makeImage(), let data = NSBitmapImageRep(cgImage: cgImage).representation(using: .png, properties: [:])
    else { fatalError("png") }
    return data
}

func write(_ data: Data, _ name: String, in folder: URL) throws {
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    try data.write(to: folder.appendingPathComponent(name))
}

let icon = catalog.appendingPathComponent("AppIcon.appiconset")
try write(png(size: 1024, inset: 0, radius: 0, opaque: true), "ios-1024.png", in: icon)
var entries = [#"{ "filename" : "ios-1024.png", "idiom" : "universal", "platform" : "ios", "size" : "1024x1024" }"#]
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = "mac-\(points)@\(scale)x.png"
        try write(png(size: points * scale, inset: 100.0 / 1024, radius: 0.225, opaque: false), name, in: icon)
        entries.append(
            #"{ "filename" : "\#(name)", "idiom" : "mac", "scale" : "\#(scale)x", "size" : "\#(points)x\#(points)" }"#)
    }
}
let contents =
    "{\n  \"images\" : [\n    " + entries.joined(separator: ",\n    ")
    + "\n  ],\n  \"info\" : { \"author\" : \"xcode\", \"version\" : 1 }\n}\n"
try write(Data(contents.utf8), "Contents.json", in: icon)

let markSet = catalog.appendingPathComponent("Mark.imageset")
try write(Data(mark.utf8), "mark.svg", in: markSet)
let markContents = """
    {
      "images" : [{ "filename" : "mark.svg", "idiom" : "universal" }],
      "info" : { "author" : "xcode", "version" : 1 },
      "properties" : { "preserves-vector-representation" : true }
    }

    """
try write(Data(markContents.utf8), "Contents.json", in: markSet)
