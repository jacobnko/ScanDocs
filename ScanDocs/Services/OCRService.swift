// Vision 프레임워크로 스캔 이미지에서 텍스트를 추출하는 OCR 서비스
import UIKit
import Vision

enum OCRService {
    // Vision의 boundingBox는 좌하단 원점의 0~1 정규화 좌표
    struct RecognizedLine {
        let text: String
        let boundingBox: CGRect
    }

    static func recognizeText(in image: UIImage) async -> String {
        let lines = await recognizeLines(in: image)
        return lines.map(\.text).joined(separator: "\n")
    }

    static func recognizeLines(in image: UIImage) async -> [RecognizedLine] {
        guard let cgImage = image.cgImage else { return [] }

        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                guard error == nil,
                      let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: [])
                    return
                }
                let lines = observations.compactMap { observation -> RecognizedLine? in
                    guard let candidate = observation.topCandidates(1).first else { return nil }
                    return RecognizedLine(text: candidate.string, boundingBox: observation.boundingBox)
                }
                continuation.resume(returning: lines)
            }
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["ko-KR", "en-US"]
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: [])
            }
        }
    }
}
