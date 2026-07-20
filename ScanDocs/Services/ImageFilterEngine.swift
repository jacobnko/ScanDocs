// Core Image 기반으로 스캔 페이지에 흑백/향상/그레이스케일 필터를 적용하는 엔진
import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

enum ImageFilterType: String, CaseIterable, Identifiable {
    case original
    case blackAndWhite
    case enhanced
    case grayscale

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .original: return "Original"
        case .blackAndWhite: return "B&W"
        case .enhanced: return "Enhanced"
        case .grayscale: return "Grayscale"
        }
    }
}

enum ImageFilterEngine {
    private static let context = CIContext()

    static func apply(_ filter: ImageFilterType, to image: UIImage) -> UIImage {
        guard filter != .original, let ciImage = CIImage(image: image) else { return image }

        let outputImage: CIImage?
        switch filter {
        case .original:
            outputImage = ciImage
        case .blackAndWhite:
            outputImage = blackAndWhiteFilter(ciImage)
        case .enhanced:
            outputImage = enhancedFilter(ciImage)
        case .grayscale:
            outputImage = grayscaleFilter(ciImage)
        }

        guard let outputImage,
              let cgImage = context.createCGImage(outputImage, from: outputImage.extent) else {
            return image
        }
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: .up)
    }

    // 문서 텍스트만 선명하게 남기고 그림자·손자국 잡음을 날리는 고대비 흑백 필터
    private static func blackAndWhiteFilter(_ image: CIImage) -> CIImage? {
        let mono = CIFilter.colorMonochrome()
        mono.inputImage = image
        mono.color = CIColor(red: 1, green: 1, blue: 1)
        mono.intensity = 1.0

        let contrast = CIFilter.colorControls()
        contrast.inputImage = mono.outputImage
        contrast.contrast = 2.2
        contrast.brightness = 0.1
        return contrast.outputImage
    }

    private static func enhancedFilter(_ image: CIImage) -> CIImage? {
        let controls = CIFilter.colorControls()
        controls.inputImage = image
        controls.saturation = 1.1
        controls.contrast = 1.15
        controls.brightness = 0.05

        let sharpen = CIFilter.sharpenLuminance()
        sharpen.inputImage = controls.outputImage
        sharpen.sharpness = 0.4
        return sharpen.outputImage
    }

    private static func grayscaleFilter(_ image: CIImage) -> CIImage? {
        let filter = CIFilter.colorControls()
        filter.inputImage = image
        filter.saturation = 0
        return filter.outputImage
    }
}
