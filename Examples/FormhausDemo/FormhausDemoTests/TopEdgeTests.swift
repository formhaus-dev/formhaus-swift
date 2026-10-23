import SwiftUI
import Testing
import UIKit

@testable import FormhausDemo

@MainActor
private func pixels(_ window: UIWindow) -> (data: [UInt8], width: Int) {
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    let image = UIGraphicsImageRenderer(bounds: window.bounds, format: format).image { _ in
        window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
    }
    let width = Int(window.bounds.width)
    let height = Int(window.bounds.height)
    var data = [UInt8](repeating: 0, count: width * height * 4)
    data.withUnsafeMutableBytes { buffer in
        let context = CGContext(
            data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        if let cgImage = image.cgImage { context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height)) }
    }
    return (data, width)
}

@Suite("Demo top edge", .serialized)
@MainActor
struct TopEdgeTests {
    @Test("the cover of the top edge leaves the large title visible")
    func largeTitleVisible() async throws {
        enableAccessibilityAutomation()
        let session = DemoSession()
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        let window = scene.map { UIWindow(windowScene: $0) } ?? UIWindow()
        window.frame = CGRect(x: 0, y: 0, width: 393, height: 852)
        window.rootViewController = UIHostingController(rootView: RootView(session: session))
        window.makeKeyAndVisible()
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }
        let title = { axTree(window).first { $0.label == session.title && $0.frame.height > 0 }?.frame }
        #expect(await eventually { title() != nil })
        for _ in 0..<10 {
            try await Task.sleep(for: .milliseconds(100))
            window.layoutIfNeeded()
        }
        let frame = try #require(title()).intersection(window.bounds).integral
        try #require(frame.width > 4 && frame.height > 4)
        let image = pixels(window)
        func pixel(_ x: Int, _ y: Int) -> [Int] {
            let start = (y * image.width + x) * 4
            return image.data[start..<start + 3].map(Int.init)
        }
        let reference = pixel(1, Int(frame.midY))
        var differing = 0
        for y in Int(frame.minY)..<Int(frame.maxY) {
            for x in Int(frame.minX)..<Int(frame.maxX) where zip(pixel(x, y), reference).contains(where: { abs($0 - $1) > 48 }) {
                differing += 1
            }
        }
        #expect(differing > 20)
    }
}
