import CoreGraphics
import CoreText
import Foundation

public struct DoctorVisitSection: Equatable, Sendable {
    public var heading: String
    public var rows: [String]

    public init(heading: String, rows: [String]) {
        self.heading = heading
        self.rows = rows
    }
}

public struct DoctorVisitPage: Equatable, Sendable {
    public var title: String
    public var meta: [String]
    public var sections: [DoctorVisitSection]
    public var disclaimer: String

    public init(title: String, meta: [String], sections: [DoctorVisitSection], disclaimer: String) {
        self.title = title
        self.meta = meta
        self.sections = sections
        self.disclaimer = disclaimer
    }
}

public enum DoctorVisitPDF {
    public static let pageSize = CGSize(width: 612, height: 792)

    public static func data(page: DoctorVisitPage) -> Data {
        let attributed = attributedText(page)
        let data = NSMutableData()
        var mediaBox = CGRect(origin: .zero, size: pageSize)
        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let ctx = CGContext(consumer: consumer, mediaBox: &mediaBox, nil)
        else { return Data() }

        let framesetter = CTFramesetterCreateWithAttributedString(attributed)
        var offset: CFIndex = 0
        let total = CFAttributedStringGetLength(attributed)
        let inset: CGFloat = 54
        while offset < total {
            ctx.beginPDFPage(nil)
            // PDF space is Y-up. Do not flip the CTM — that inverts glyphs and
            // puts the title at the bottom of Quick Look / Files preview.
            ctx.textMatrix = .identity
            let frameRect = CGRect(origin: .zero, size: pageSize).insetBy(dx: inset, dy: inset)
            let path = CGPath(rect: frameRect, transform: nil)
            let frame = CTFramesetterCreateFrame(
                framesetter,
                CFRange(location: offset, length: 0),
                path,
                nil
            )
            CTFrameDraw(frame, ctx)
            let visible = CTFrameGetVisibleStringRange(frame)
            ctx.endPDFPage()
            if visible.length == 0 { break }
            offset = visible.location + visible.length
        }
        ctx.closePDF()
        return data as Data
    }

    private static func attributedText(_ page: DoctorVisitPage) -> NSAttributedString {
        let out = NSMutableAttributedString()
        out.append(block(page.title + "\n", font: bold(18), gray: 0.18))
        for line in page.meta {
            out.append(block(line + "\n", font: regular(11), gray: 0.32))
        }
        out.append(block("\n", font: regular(11), gray: 0.32))
        for section in page.sections {
            out.append(block(section.heading + "\n", font: bold(13), gray: 0.18))
            if section.rows.isEmpty {
                continue
            }
            for row in section.rows {
                out.append(block(row + "\n", font: regular(11), gray: 0.22))
            }
            out.append(block("\n", font: regular(11), gray: 0.22))
        }
        out.append(block(page.disclaimer, font: italic(10), gray: 0.35))
        return out
    }

    private static func block(_ text: String, font: CTFont, gray: CGFloat) -> NSAttributedString {
        NSAttributedString(
            string: text,
            attributes: [
                NSAttributedString.Key(kCTFontAttributeName as String): font,
                NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(gray: gray, alpha: 1),
            ]
        )
    }

    private static func bold(_ size: CGFloat) -> CTFont {
        CTFontCreateWithName("Helvetica-Bold" as CFString, size, nil)
    }

    private static func regular(_ size: CGFloat) -> CTFont {
        CTFontCreateWithName("Helvetica" as CFString, size, nil)
    }

    private static func italic(_ size: CGFloat) -> CTFont {
        CTFontCreateWithName("Helvetica-Oblique" as CFString, size, nil)
    }
}
