@_spi(Renderer) import FormhausCore
import Testing

@Suite("Option image sources")
struct ImageSourceTests {
    @Test("relative, blob, http, https and raster data images are kept")
    func allowed() {
        let allowed = [
            "/assets/a.png", "./a@2x.png", "a.png", "//cdn.example.com/a.png", "blob:https://example.com/3f1c",
            "http://localhost:5173/a.png", "HTTPS://example.com/a@b.png?x=1", "data:image/png;base64,iVBORw0KGgo=", "data:image/webp,x",
        ]
        #expect(allowed.map(imageSource) == allowed)
    }

    @Test("script, file, non-raster data and credential URLs are dropped")
    func refused() {
        let refused: [String?] = [
            nil, "", " ", "javascript:alert(1)", " JaVa\tScRiPt:alert(1)", "\u{1}javascript:alert(1)", "vbscript:msgbox(1)",
            "data:text/html,<script>", "data:image/svg+xml;base64,PHN2Zz4=", "file:///etc/hosts", "https://user:pass@example.com/a.png",
            "http:user@example.com/a.png", "//user@example.com/a.png",
        ]
        #expect(refused.map(imageSource).allSatisfy { $0 == nil })
    }
}
