import CoreImage
import UIKit

final class ImageEditingService {
    private let context = CIContext()
    private(set) var originalImage: UIImage
    private(set) var currentImage: UIImage

    init() {
        let image = Self.makeSampleImage()
        self.originalImage = image
        self.currentImage = image
    }

    func apply(operation: ImageEditOperation, filter: ImageFilter? = nil) -> ImageEditResult {
        switch operation {
        case .filter:
            let selectedFilter = filter ?? .vivid
            currentImage = applyFilter(selectedFilter, to: currentImage)
            return ImageEditResult(
                title: "Applied \(selectedFilter.title)",
                detail: "The image was processed locally with Core Image.",
                image: currentImage
            )
        case .brighten:
            currentImage = applyColorControls(to: currentImage, brightness: 0.16, contrast: 1.04, saturation: 1.08)
            return ImageEditResult(
                title: "Brightness Increased",
                detail: "Brightness, contrast, and saturation were adjusted on device.",
                image: currentImage
            )
        case .squareCrop:
            currentImage = cropToSquare(currentImage)
            return ImageEditResult(
                title: "Cropped to Square",
                detail: "The longest edge was trimmed from the center for a square composition.",
                image: currentImage
            )
        case .reset:
            currentImage = originalImage
            return ImageEditResult(
                title: "Reset Image",
                detail: "Restored the original local sample image.",
                image: currentImage
            )
        }
    }

    private func applyFilter(_ filter: ImageFilter, to image: UIImage) -> UIImage {
        switch filter {
        case .mono:
            return render(image, filterName: "CIPhotoEffectMono") ?? image
        case .vivid:
            return applyColorControls(to: image, brightness: 0.04, contrast: 1.18, saturation: 1.35)
        case .warm:
            return renderTemperature(image, neutral: CIVector(x: 6500, y: 0), target: CIVector(x: 5200, y: 0)) ?? image
        case .cool:
            return renderTemperature(image, neutral: CIVector(x: 6500, y: 0), target: CIVector(x: 8500, y: 0)) ?? image
        }
    }

    private func applyColorControls(
        to image: UIImage,
        brightness: Double,
        contrast: Double,
        saturation: Double
    ) -> UIImage {
        guard let ciImage = CIImage(image: image),
              let filter = CIFilter(name: "CIColorControls")
        else { return image }
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(brightness, forKey: kCIInputBrightnessKey)
        filter.setValue(contrast, forKey: kCIInputContrastKey)
        filter.setValue(saturation, forKey: kCIInputSaturationKey)
        return render(filter.outputImage, scale: image.scale, orientation: image.imageOrientation) ?? image
    }

    private func render(_ image: UIImage, filterName: String) -> UIImage? {
        guard let ciImage = CIImage(image: image),
              let filter = CIFilter(name: filterName)
        else { return nil }
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        return render(filter.outputImage, scale: image.scale, orientation: image.imageOrientation)
    }

    private func renderTemperature(_ image: UIImage, neutral: CIVector, target: CIVector) -> UIImage? {
        guard let ciImage = CIImage(image: image),
              let filter = CIFilter(name: "CITemperatureAndTint")
        else { return nil }
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(neutral, forKey: "inputNeutral")
        filter.setValue(target, forKey: "inputTargetNeutral")
        return render(filter.outputImage, scale: image.scale, orientation: image.imageOrientation)
    }

    private func render(_ ciImage: CIImage?, scale: CGFloat, orientation: UIImage.Orientation) -> UIImage? {
        guard let ciImage,
              let cgImage = context.createCGImage(ciImage, from: ciImage.extent)
        else { return nil }
        return UIImage(cgImage: cgImage, scale: scale, orientation: orientation)
    }

    private func cropToSquare(_ image: UIImage) -> UIImage {
        guard let cgImage = image.cgImage else { return image }
        let side = min(cgImage.width, cgImage.height)
        let rect = CGRect(
            x: (cgImage.width - side) / 2,
            y: (cgImage.height - side) / 2,
            width: side,
            height: side
        )
        guard let cropped = cgImage.cropping(to: rect) else { return image }
        return UIImage(cgImage: cropped, scale: image.scale, orientation: image.imageOrientation)
    }

    private static func makeSampleImage() -> UIImage {
        let size = CGSize(width: 960, height: 640)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            let cgContext = context.cgContext
            let colors = [
                UIColor(red: 0.10, green: 0.32, blue: 0.82, alpha: 1).cgColor,
                UIColor(red: 0.98, green: 0.72, blue: 0.24, alpha: 1).cgColor,
            ] as CFArray
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
            cgContext.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: size.width, y: size.height), options: [])

            UIColor.white.withAlphaComponent(0.22).setFill()
            UIBezierPath(ovalIn: CGRect(x: 610, y: 70, width: 190, height: 190)).fill()
            UIColor.white.withAlphaComponent(0.16).setFill()
            UIBezierPath(ovalIn: CGRect(x: 130, y: 390, width: 260, height: 160)).fill()

            UIColor.black.withAlphaComponent(0.28).setFill()
            UIBezierPath(roundedRect: CGRect(x: 170, y: 170, width: 610, height: 310), cornerRadius: 36).fill()
            UIColor.white.withAlphaComponent(0.92).setStroke()
            let frame = UIBezierPath(roundedRect: CGRect(x: 210, y: 210, width: 530, height: 230), cornerRadius: 26)
            frame.lineWidth = 10
            frame.stroke()
            UIColor.white.withAlphaComponent(0.85).setFill()
            UIBezierPath(ovalIn: CGRect(x: 270, y: 250, width: 78, height: 78)).fill()
            let mountain = UIBezierPath()
            mountain.move(to: CGPoint(x: 370, y: 405))
            mountain.addLine(to: CGPoint(x: 500, y: 285))
            mountain.addLine(to: CGPoint(x: 595, y: 385))
            mountain.addLine(to: CGPoint(x: 660, y: 325))
            mountain.addLine(to: CGPoint(x: 720, y: 405))
            mountain.close()
            mountain.fill()
        }
    }
}
