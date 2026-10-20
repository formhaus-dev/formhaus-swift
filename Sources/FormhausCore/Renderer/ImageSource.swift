import Foundation

private let specialSchemes: Set<String> = ["ftp", "file", "http", "https", "ws", "wss"]
private let rasterData = JSRegex(unchecked: "^image\\/(?:png|jpeg|webp|gif)[;,]")

private struct ImageURL {
    var scheme = "https"
    var authority: ArraySlice<Unicode.Scalar>?
    var path: ArraySlice<Unicode.Scalar>

    init(_ source: String) {
        let kept = Array(source.unicodeScalars.filter { !["\t", "\n", "\r"].contains($0) })
        let start = kept.firstIndex { $0.value > 0x20 } ?? kept.endIndex
        let end = kept.lastIndex { $0.value > 0x20 }.map { $0 + 1 } ?? start
        var rest = kept[start..<max(start, end)]
        var relative = true
        if let colon = rest.firstIndex(of: ":"), isScheme(rest[..<colon]) {
            scheme = String(String.UnicodeScalarView(rest[..<colon])).lowercased()
            rest = rest[(colon + 1)...]
            relative = scheme == "https"
        }
        let special = specialSchemes.contains(scheme)
        let slashes = rest.prefix { special ? $0 == "/" || $0 == "\\" : $0 == "/" }.count
        let opens = special && !relative ? true : slashes >= 2
        guard opens else {
            path = rest
            return
        }
        rest = rest.dropFirst(special ? slashes : 2)
        let ends: Set<Unicode.Scalar> = special ? ["/", "?", "#", "\\"] : ["/", "?", "#"]
        let authority = rest.prefix { !ends.contains($0) }
        self.authority = authority
        path = rest[authority.endIndex...]
    }

    var credentials: Bool {
        guard let authority, let at = authority.lastIndex(of: "@") else { return false }
        let user = authority[..<at]
        return !user.isEmpty && Array(user) != [":"]
    }

    var emptyHost: Bool {
        guard let authority else { return false }
        return authority.lastIndex(of: "@").map { $0 + 1 == authority.endIndex } ?? authority.isEmpty
    }
}

private func isScheme(_ name: ArraySlice<Unicode.Scalar>) -> Bool {
    guard let first = name.first, first.isASCII, first.properties.isAlphabetic else { return false }
    return name.allSatisfy { $0.isASCII && ($0.properties.isAlphabetic || ("0"..."9").contains($0) || "+-.".unicodeScalars.contains($0)) }
}

@_spi(Renderer)
public func imageSource(_ image: String?) -> String? {
    guard let image, !image.jsTrimmed.isEmpty else { return nil }
    let url = ImageURL(image)
    guard !url.credentials, URL(string: image)?.user == nil else { return nil }
    switch url.scheme {
    case "http", "https": return url.emptyHost ? nil : image
    case "blob": return image
    case "data":
        return rasterData.test(String(String.UnicodeScalarView(url.path)).lowercased()) == true ? image : nil
    default: return nil
    }
}
