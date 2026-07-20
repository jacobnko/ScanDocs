// 문서의 모든 페이지를 필터가 적용된 상태로 하나의 PDF로 렌더링
import UIKit

enum PDFExporter {
    static func makePDF(from document: ScannedDocument) -> Data {
        let pages = document.pages.sorted { $0.order < $1.order }
        let renderer = UIGraphicsPDFRenderer()

        return renderer.pdfData { context in
            for page in pages {
                guard let image = UIImage(data: page.imageData) else { continue }
                let filter = ImageFilterType(rawValue: page.filterType) ?? .original
                let filteredImage = ImageFilterEngine.apply(filter, to: image)

                let pageRect = CGRect(origin: .zero, size: filteredImage.size)
                context.beginPage(withBounds: pageRect, pageInfo: [:])
                filteredImage.draw(in: pageRect)
            }
        }
    }
}
