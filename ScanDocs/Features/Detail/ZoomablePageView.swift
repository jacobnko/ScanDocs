// 페이지 이미지를 백그라운드에서 필터 적용해 보여주고 핀치 줌·더블탭 줌을 지원하는 뷰
import SwiftUI

struct ZoomablePageView: View {
    let page: DocumentPage

    @State private var image: UIImage?
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale)
                    .gesture(magnificationGesture)
                    .onTapGesture(count: 2, perform: toggleZoom)
            } else {
                ProgressView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .task(id: page.id) {
            image = await Self.render(page: page)
        }
    }

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                scale = max(1, min(lastScale * value, 5))
            }
            .onEnded { _ in
                lastScale = scale
            }
    }

    private func toggleZoom() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            scale = scale > 1 ? 1 : 2.5
            lastScale = scale
        }
    }

    private static func render(page: DocumentPage) async -> UIImage? {
        let imageData = page.imageData
        let filterTypeRaw = page.filterType
        return await Task.detached(priority: .userInitiated) {
            guard let uiImage = UIImage(data: imageData) else { return nil }
            let filter = ImageFilterType(rawValue: filterTypeRaw) ?? .original
            return ImageFilterEngine.apply(filter, to: uiImage)
        }.value
    }
}
