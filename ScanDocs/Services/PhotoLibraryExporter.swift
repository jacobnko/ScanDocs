// 스캔한 페이지 이미지를 사진 앱(Photos)에 저장하는 서비스
import UIKit
import Photos

enum PhotoLibraryExporter {
    enum ExportError: Error {
        case permissionDenied
    }

    static func save(_ image: UIImage) async throws {
        let status = await requestAuthorization()
        guard status == .authorized || status == .limited else {
            throw ExportError.permissionDenied
        }
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }
    }

    private static func requestAuthorization() async -> PHAuthorizationStatus {
        await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                continuation.resume(returning: status)
            }
        }
    }
}
