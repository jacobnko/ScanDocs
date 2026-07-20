// 이미지 90도 회전과 사각형 크롭을 처리하는 기하 변환 서비스
import UIKit

enum ImageTransformEngine {
    static func rotated90(_ image: UIImage, clockwise: Bool) -> UIImage {
        let radians = clockwise ? CGFloat.pi / 2 : -CGFloat.pi / 2
        let newSize = CGSize(width: image.size.height, height: image.size.width)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { context in
            context.cgContext.translateBy(x: newSize.width / 2, y: newSize.height / 2)
            context.cgContext.rotate(by: radians)
            image.draw(in: CGRect(
                x: -image.size.width / 2,
                y: -image.size.height / 2,
                width: image.size.width,
                height: image.size.height
            ))
        }
    }

    // normalizedRect: 이미지 좌상단 원점 기준 0~1 정규화 좌표
    static func cropped(_ image: UIImage, to normalizedRect: CGRect) -> UIImage {
        let upright = normalizedOrientation(image)
        guard let cgImage = upright.cgImage else { return image }

        let pixelRect = CGRect(
            x: normalizedRect.minX * CGFloat(cgImage.width),
            y: normalizedRect.minY * CGFloat(cgImage.height),
            width: normalizedRect.width * CGFloat(cgImage.width),
            height: normalizedRect.height * CGFloat(cgImage.height)
        ).integral

        guard let croppedImage = cgImage.cropping(to: pixelRect) else { return upright }
        return UIImage(cgImage: croppedImage, scale: upright.scale, orientation: .up)
    }

    // 크롭 좌표 계산이 픽셀 공간과 어긋나지 않도록 orientation을 항상 .up으로 구워둠
    private static func normalizedOrientation(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return image }
        let renderer = UIGraphicsImageRenderer(size: image.size)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }
}
