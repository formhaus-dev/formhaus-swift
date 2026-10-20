import Foundation
import ImageIO
import UniformTypeIdentifiers

let maxImageSide = 2048
let maxImageBytes = 10 * 1024 * 1024
private let decodes = AsyncGate(width: 2)
private let fetches = AsyncGate(width: 4)
private let imageTypes = Set([UTType.png, .jpeg, .gif, .webP].map(\.identifier))

private let imageSession: URLSession = {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.httpShouldSetCookies = false
    configuration.httpCookieAcceptPolicy = .never
    configuration.httpCookieStorage = nil
    configuration.urlCredentialStorage = nil
    configuration.urlCache = nil
    configuration.timeoutIntervalForRequest = 15
    configuration.timeoutIntervalForResource = 30
    return URLSession(configuration: configuration)
}()

func isInline(_ source: String) -> Bool {
    source.hasPrefix("data:image/")
}

func remoteImageURL(_ source: String) -> URL? {
    guard let url = URL(string: source), let scheme = url.scheme?.lowercased(), ["https", "http"].contains(scheme),
        url.host?.isEmpty == false, url.user == nil, url.password == nil
    else { return nil }
    return url
}

func loadImage(_ source: String) async -> CGImage? {
    if isInline(source) { return await decodes.run { decodeInline(source) } }
    guard let url = remoteImageURL(source), let data = await fetches.run({ await fetchImage(url) }) else { return nil }
    return await decodes.run { decodeImage(data) }
}

private func fetchImage(_ url: URL) async -> Data? {
    guard let (bytes, response) = try? await imageSession.bytes(from: url),
        let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
        http.expectedContentLength <= Int64(maxImageBytes)
    else { return nil }
    var data = Data()
    do {
        for try await byte in bytes {
            guard data.count < maxImageBytes else { return nil }
            data.append(byte)
        }
    } catch {
        return nil
    }
    return data
}

private func decodeInline(_ source: String) -> CGImage? {
    guard isInline(source), let comma = source.firstIndex(of: ","), source[..<comma].hasSuffix(";base64"),
        let data = Data(base64Encoded: String(source[source.index(after: comma)...]))
    else { return nil }
    return decodeImage(data)
}

func imagePixelSize(_ data: Data) -> (width: Int, height: Int)? {
    guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
        let type = CGImageSourceGetType(source) as String?, imageTypes.contains(type),
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, [kCGImageSourceShouldCache: false] as CFDictionary)
            as? [CFString: Any],
        let width = properties[kCGImagePropertyPixelWidth] as? Int, let height = properties[kCGImagePropertyPixelHeight] as? Int
    else { return nil }
    return (width, height)
}

func decodeImage(_ data: Data) -> CGImage? {
    guard data.count <= maxImageBytes, let size = imagePixelSize(data), (1...maxImageSide).contains(size.width),
        (1...maxImageSide).contains(size.height),
        let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary)
    else { return nil }
    let options: [CFString: Any] = [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceThumbnailMaxPixelSize: maxImageSide,
        kCGImageSourceCreateThumbnailWithTransform: true,
        kCGImageSourceShouldCacheImmediately: true,
    ]
    return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
}
