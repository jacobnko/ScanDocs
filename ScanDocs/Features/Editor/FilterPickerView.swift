// 페이지 이미지에 적용할 필터를 고르고 실시간으로 미리보기하는 컴포넌트
import SwiftUI

struct FilterPickerView: View {
    let originalImage: UIImage
    @Binding var selectedFilter: ImageFilterType

    var body: some View {
        VStack(spacing: 16) {
            Image(uiImage: ImageFilterEngine.apply(selectedFilter, to: originalImage))
                .resizable()
                .scaledToFit()
                .frame(height: 320)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(ImageFilterType.allCases) { filter in
                        FilterThumbnailButton(
                            filter: filter,
                            image: originalImage,
                            isSelected: filter == selectedFilter
                        ) {
                            selectedFilter = filter
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .frame(width: 380)
    }
}

private struct FilterThumbnailButton: View {
    let filter: ImageFilterType
    let image: UIImage
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(uiImage: ImageFilterEngine.apply(filter, to: image))
                    .resizable()
                    .scaledToFill()
                    .frame(width: 64, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? Color.accentColor : .clear, lineWidth: 2)
                    }
                Text(filter.displayName)
                    .font(.caption2)
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    FilterPickerView(
        originalImage: UIImage(systemName: "doc.text")!,
        selectedFilter: .constant(.original)
    )
    .frame(width: 400, height: 600)
    .preferredColorScheme(.light)
}
