import CoreImage.CIFilterBuiltins
import SwiftUI

/// Turns a short string (here, a friend code deep link) into a crisp QR
/// code image, scaled up from the raw generated bitmap so it stays sharp.
enum QRCodeGenerator {
    static func image(from string: String, scale: CGFloat = 10) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let outputImage = filter.outputImage else { return nil }
        let transformed = outputImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        guard let cgImage = context.createCGImage(transformed, from: transformed.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
