// 스캔한 문서의 개별 페이지(이미지, 필터, OCR 텍스트)를 저장하는 SwiftData 모델
import Foundation
import SwiftData

@Model
final class DocumentPage {
    var id: UUID
    var order: Int
    @Attribute(.externalStorage) var imageData: Data
    var filterType: String
    var recognizedText: String?
    var document: ScannedDocument?

    init(
        order: Int,
        imageData: Data,
        filterType: String = "original",
        recognizedText: String? = nil
    ) {
        self.id = UUID()
        self.order = order
        self.imageData = imageData
        self.filterType = filterType
        self.recognizedText = recognizedText
    }
}
