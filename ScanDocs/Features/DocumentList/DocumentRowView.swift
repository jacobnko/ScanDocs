// 문서 목록의 한 줄(썸네일, 제목, 페이지 수, 날짜)을 그리는 컴포넌트
import SwiftUI

struct DocumentRowView: View {
    let title: String
    let pageCount: Int
    let createdAt: Date

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.secondary.opacity(0.15))
                .frame(width: 44, height: 56)
                .overlay {
                    Image(systemName: "doc.text")
                        .foregroundStyle(.secondary)
                }
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body)
                Text("\(pageCount) page(s) · \(createdAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 380, alignment: .leading)
    }
}

#Preview {
    DocumentRowView(title: "Sample Document", pageCount: 3, createdAt: .now)
        .frame(width: 400, height: 600)
        .preferredColorScheme(.light)
}
