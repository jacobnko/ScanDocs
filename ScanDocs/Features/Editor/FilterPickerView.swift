// 페이지 이미지에 적용할 필터를 고르고 실시간으로 미리보기하는 컴포넌트
import SwiftUI

struct FilterPickerView: View {
    let originalImage: UIImage
    @Binding var selectedFilter: ImageFilterType

    @State private var previewImage: UIImage?

    var body: some View {
        VStack(spacing: 16) {
            Group {
                if let previewImage {
                    Image(uiImage: previewImage)
                        .resizable()
                        .scaledToFit()
                } else {
                    ProgressView()
                }
            }
            .frame(height: 320)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .task(id: selectedFilter) {
                previewImage = await Self.render(filter: selectedFilter, image: originalImage)
            }

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

    fileprivate static func render(filter: ImageFilterType, image: UIImage) async -> UIImage {
        await Task.detached(priority: .userInitiated) {
            ImageFilterEngine.apply(filter, to: image)
        }.value
    }
}

private struct FilterThumbnailButton: View {
    let filter: ImageFilterType
    let image: UIImage
    let isSelected: Bool
    let action: () -> Void

    @State private var thumbnail: UIImage?

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Group {
                    if let thumbnail {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Color.secondary.opacity(0.15)
                    }
                }
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
        .task {
            thumbnail = await FilterPickerView.render(filter: filter, image: image)
        }
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
