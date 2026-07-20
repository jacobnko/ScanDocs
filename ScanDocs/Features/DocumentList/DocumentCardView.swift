// 문서 목록 그리드에 쓰이는 카드형 썸네일 컴포넌트
import SwiftUI

struct DocumentCardView: View {
    let thumbnail: UIImage?
    let title: String
    let pageCount: Int
    let createdAt: Date
    let isSelecting: Bool
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                thumbnailView
                    .aspectRatio(3.0 / 4.0, contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(.black.opacity(0.06))
                    }
                    .shadow(color: .black.opacity(0.14), radius: 8, y: 4)

                if isSelecting {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(isSelected ? Color.white : .white, isSelected ? Color.accentColor : .black.opacity(0.35))
                        .font(.title3)
                        .padding(8)
                        .shadow(color: .black.opacity(0.25), radius: 3)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text("\(pageCount) page\(pageCount == 1 ? "" : "s") · \(createdAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    @ViewBuilder
    private var thumbnailView: some View {
        if let thumbnail {
            Image(uiImage: thumbnail)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                LinearGradient(
                    colors: [Color.accentColor.opacity(0.25), Color.accentColor.opacity(0.08)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(Color.accentColor)
            }
        }
    }
}

#Preview {
    HStack(spacing: 16) {
        DocumentCardView(
            thumbnail: nil,
            title: "Insurance Form",
            pageCount: 3,
            createdAt: .now,
            isSelecting: false,
            isSelected: false
        )
        DocumentCardView(
            thumbnail: nil,
            title: "Contract",
            pageCount: 1,
            createdAt: .now,
            isSelecting: true,
            isSelected: true
        )
    }
    .padding()
    .frame(width: 400, height: 300)
    .preferredColorScheme(.light)
}
