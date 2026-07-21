// 문서 목록의 한 줄. 썸네일은 백그라운드에서 비동기로 렌더링해 메인 스레드 프리징을 막는다
import SwiftUI

struct DocumentRowView: View {
    let title: String
    let pageCount: Int
    let createdAt: Date
    let thumbnailData: Data?
    let thumbnailFilterType: String

    @State private var thumbnail: UIImage?

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.accentColor.opacity(0.12))
                        .overlay {
                            Image(systemName: "doc.text.fill")
                                .foregroundStyle(Color.accentColor)
                        }
                }
            }
            .frame(width: 48, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                Text("\(pageCount) page\(pageCount == 1 ? "" : "s") · \(createdAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
        .task(id: thumbnailData) {
            guard thumbnail == nil, let thumbnailData else { return }
            thumbnail = await Self.render(data: thumbnailData, filterType: thumbnailFilterType)
        }
    }

    private static func render(data: Data, filterType: String) async -> UIImage? {
        await Task.detached(priority: .userInitiated) {
            guard let image = UIImage(data: data) else { return nil }
            let filter = ImageFilterType(rawValue: filterType) ?? .original
            return ImageFilterEngine.apply(filter, to: image)
        }.value
    }
}

#Preview {
    DocumentRowView(
        title: "Sample Document",
        pageCount: 3,
        createdAt: .now,
        thumbnailData: nil,
        thumbnailFilterType: ImageFilterType.original.rawValue
    )
    .frame(width: 400, height: 600)
    .preferredColorScheme(.light)
}
