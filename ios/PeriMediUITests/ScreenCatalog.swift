import UIKit
import XCTest

enum ScreenCatalog {
    static var directory: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("docs/screens")
    }

    static var expectedNames: [String] {
        let url = directory.appendingPathComponent("expected.txt")
        let text = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        return text
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.hasSuffix(".png") }
    }

    /// Writes `{name}.png`. Does not compare pixels.
    static func write(_ name: String) throws {
        let dest = directory.appendingPathComponent("\(name).png")
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        try pngData(from: XCUIScreen.main.screenshot()).write(to: dest, options: .atomic)
    }

    private static func pngData(from screenshot: XCUIScreenshot) -> Data {
        let image = screenshot.image
        let maxWidth: CGFloat = 390
        let scale = min(1, maxWidth / max(image.size.width, 1))
        let size = CGSize(
            width: (image.size.width * scale).rounded(),
            height: (image.size.height * scale).rounded()
        )
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let rendered = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return rendered.pngData() ?? Data()
    }
}
