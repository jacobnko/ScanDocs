// 여러 페이지를 묶는 스캔 문서 SwiftData 모델
import Foundation
import SwiftData

@Model
final class ScannedDocument {
    var id: UUID
    var title: String
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \DocumentPage.document)
    var pages: [DocumentPage] = []

    init(title: String, createdAt: Date = Date()) {
        self.id = UUID()
        self.title = title
        self.createdAt = createdAt
    }
}
