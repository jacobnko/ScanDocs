// 문서의 모든 페이지를 필터 적용 상태로 렌더링하고, OCR 결과를 보이지 않는 텍스트 레이어로 얹어 검색 가능한 PDF로 만드는 서비스
import UIKit

enum PDFExporter {
    static func makePDF(from document: ScannedDocument) async -> Data {
        let pages = document.pages.sorted { $0.order < $1.order }

        var renderPages: [(image: UIImage, lines: [OCRService.RecognizedLine])] = []
        for page in pages {
            guard let image = UIImage(data: page.imageData) else { continue }
            let filter = ImageFilterType(rawValue: page.filterType) ?? .original
            let filteredImage = ImageFilterEngine.apply(filter, to: image)
            let lines = await OCRService.recognizeLines(in: filteredImage)
            renderPages.append((filteredImage, lines))
        }

        let renderer = UIGraphicsPDFRenderer()
        return renderer.pdfData { context in
            for renderPage in renderPages {
                let pageRect = CGRect(origin: .zero, size: renderPage.image.size)
                context.beginPage(withBounds: pageRect, pageInfo: [:])
                renderPage.image.draw(in: pageRect)
                drawInvisibleTextLayer(renderPage.lines, in: pageRect)
            }
        }
    }

    // OCR로 인식한 줄들을 실제 텍스트 위치에 보이지 않게 그려서 PDF 뷰어에서 검색·선택이 가능하게 함
    private static func drawInvisibleTextLayer(_ lines: [OCRService.RecognizedLine], in pageRect: CGRect) {
        guard let cgContext = UIGraphicsGetCurrentContext() else { return }
        cgContext.saveGState()
        cgContext.setTextDrawingMode(.invisible)

        for line in lines {
            let box = line.boundingBox
            let rect = CGRect(
                x: box.minX * pageRect.width,
                y: (1 - box.maxY) * pageRect.height,
                width: box.width * pageRect.width,
                height: box.height * pageRect.height
            )
            let fontSize = max(rect.height * 0.9, 1)
            let attributedString = NSAttributedString(
                string: line.text,
                attributes: [.font: UIFont.systemFont(ofSize: fontSize)]
            )
            attributedString.draw(with: rect, options: .usesLineFragmentOrigin, context: nil)
        }

        cgContext.restoreGState()
    }
}
