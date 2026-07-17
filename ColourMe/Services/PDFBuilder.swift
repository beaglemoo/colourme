import AppKit
import Foundation

@MainActor
enum PDFBuilder {
    static let a4 = CGRect(x: 0, y: 0, width: 595.28, height: 841.89)
    static let margin: CGFloat = 36

    static func buildPDF(spec: BookSpec, pages: [GeneratedPage], coverImage: Data? = nil) throws -> Data {
        let data = NSMutableData()
        var mediaBox = a4
        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let ctx = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            throw AppError.decoding("Could not create PDF context")
        }

        drawCover(in: ctx, spec: spec, coverImage: coverImage)

        for page in pages {
            ctx.beginPDFPage(nil)
            if let imageData = page.status.imageData, let image = cgImage(from: imageData) {
                let imageSize = CGSize(width: image.width, height: image.height)
                let target = aspectFit(imageSize, into: a4.insetBy(dx: margin, dy: margin))
                ctx.draw(image, in: target)
            } else {
                drawText("Page unavailable", font: .systemFont(ofSize: 18), in: ctx,
                         centeredAt: CGPoint(x: a4.midX, y: a4.midY))
            }
            ctx.endPDFPage()
        }

        ctx.closePDF()
        return data as Data
    }

    // MARK: - Cover

    private static func drawCover(in ctx: CGContext, spec: BookSpec, coverImage: Data?) {
        ctx.beginPDFPage(nil)

        ctx.setStrokeColor(NSColor.black.cgColor)
        ctx.setLineWidth(2.5)
        let border = a4.insetBy(dx: margin, dy: margin)
        let path = CGPath(roundedRect: border, cornerWidth: 18, cornerHeight: 18, transform: nil)
        ctx.addPath(path)
        ctx.strokePath()

        if let coverImage, let image = cgImage(from: coverImage) {
            // Artwork fills the lower two thirds; title sits above it.
            let artArea = CGRect(
                x: margin * 2, y: margin * 2,
                width: a4.width - margin * 4, height: a4.height * 0.58
            )
            let imageSize = CGSize(width: image.width, height: image.height)
            ctx.draw(image, in: aspectFit(imageSize, into: artArea))

            drawText(spec.title, font: .systemFont(ofSize: 38, weight: .bold), in: ctx,
                     centeredAt: CGPoint(x: a4.midX, y: a4.height * 0.84),
                     maxWidth: a4.width - margin * 4)
        } else {
            drawText(spec.title, font: .systemFont(ofSize: 42, weight: .bold), in: ctx,
                     centeredAt: CGPoint(x: a4.midX, y: a4.height * 0.62),
                     maxWidth: a4.width - margin * 4)
            drawText("Colour me in!", font: .systemFont(ofSize: 20, weight: .medium), in: ctx,
                     centeredAt: CGPoint(x: a4.midX, y: a4.height * 0.32))
        }

        ctx.endPDFPage()
    }

    // MARK: - Helpers

    private static func drawText(_ string: String, font: NSFont, in ctx: CGContext,
                                 centeredAt center: CGPoint, maxWidth: CGFloat = .infinity) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.black,
            .paragraphStyle: paragraph,
        ]
        let attributed = NSAttributedString(string: string, attributes: attributes)
        let width = min(maxWidth, a4.width - margin * 2)
        let bounds = attributed.boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin]
        )
        let rect = CGRect(
            x: center.x - width / 2,
            y: center.y - bounds.height / 2,
            width: width,
            height: ceil(bounds.height)
        )

        let nsContext = NSGraphicsContext(cgContext: ctx, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = nsContext
        attributed.draw(with: rect, options: [.usesLineFragmentOrigin])
        NSGraphicsContext.restoreGraphicsState()
    }

    private static func cgImage(from data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    private static func aspectFit(_ size: CGSize, into rect: CGRect) -> CGRect {
        guard size.width > 0, size.height > 0 else { return rect }
        let scale = min(rect.width / size.width, rect.height / size.height)
        let fitted = CGSize(width: size.width * scale, height: size.height * scale)
        return CGRect(
            x: rect.midX - fitted.width / 2,
            y: rect.midY - fitted.height / 2,
            width: fitted.width,
            height: fitted.height
        )
    }
}
