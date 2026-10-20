import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers

@testable import FormhausUI

private func encoded(width: Int, height: Int, as type: UTType = .png) throws -> Data {
    let context = try #require(
        CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    context.setFillColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 1)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    let image = try #require(context.makeImage())
    let data = NSMutableData()
    let destination = try #require(CGImageDestinationCreateWithData(data, type.identifier as CFString, 1, nil))
    CGImageDestinationAddImage(destination, image, nil)
    #expect(CGImageDestinationFinalize(destination))
    return data as Data
}

@Suite("Option image decoding")
struct ImageDecodingTests {
    @Test("small png and jpeg images decode", arguments: [UTType.png, .jpeg])
    func decodes(type: UTType) throws {
        let image = try #require(decodeImage(try encoded(width: 8, height: 6, as: type)))
        #expect(image.width == 8 && image.height == 6)
    }

    @Test("images wider or taller than the limit are refused from their header")
    func refusesLargeSides() throws {
        let wide = try encoded(width: maxImageSide + 1, height: 1)
        let size = try #require(imagePixelSize(wide))
        #expect(size.width == maxImageSide + 1)
        #expect(decodeImage(wide) == nil)
        #expect(decodeImage(try encoded(width: 1, height: maxImageSide + 1)) == nil)
        #expect(decodeImage(try encoded(width: maxImageSide, height: 1)) != nil)
    }

    @Test("other image formats and oversized payloads are refused")
    func refusesFormats() throws {
        #expect(decodeImage(try encoded(width: 4, height: 4, as: .tiff)) == nil)
        #expect(decodeImage(try encoded(width: 4, height: 4, as: .bmp)) == nil)
        #expect(decodeImage(Data("<svg xmlns=\"http://www.w3.org/2000/svg\"/>".utf8)) == nil)
        var padded = try encoded(width: 4, height: 4)
        padded.append(Data(count: maxImageBytes))
        #expect(decodeImage(padded) == nil)
    }

    @Test("only http and https URLs without a user name are fetched")
    func remoteURLs() {
        #expect(remoteImageURL("HTTPS://example.com/a.png") != nil)
        #expect(remoteImageURL("http://localhost:5173/a.png") != nil)
        let refused = [
            "https://h\\@evil.example/x.png", "https://u@example.com/x.png", "file:///tmp/a.png", "/assets/a.png", "https:///a.png",
        ]
        #expect(refused.allSatisfy { remoteImageURL($0) == nil })
    }
}
