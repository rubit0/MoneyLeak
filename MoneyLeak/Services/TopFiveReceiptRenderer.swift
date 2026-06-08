import AppKit
import SwiftUI

enum TopFiveReceiptRenderer {
    @MainActor
    static func render(data: TopFiveReceiptData, scale: CGFloat = 2) -> NSImage? {
        let renderer = ImageRenderer(content: TopFiveReceiptView(data: data))
        renderer.scale = scale
        return renderer.nsImage
    }

    @MainActor
    static func pngData(from image: NSImage) -> Data? {
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else {
            return nil
        }
        return bitmap.representation(using: .png, properties: [:])
    }
}
