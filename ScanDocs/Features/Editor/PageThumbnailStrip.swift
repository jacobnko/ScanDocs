// 편집 중인 페이지들을 가로로 보여주고 선택·드래그 순서변경·삭제하는 컴포넌트
import SwiftUI

struct PageThumbnailStrip: View {
    @Binding var pages: [EditablePage]
    @Binding var selectedPageID: EditablePage.ID?
    @State private var draggedPage: EditablePage?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(pages) { page in
                    PageThumbnailCell(
                        page: page,
                        isSelected: page.id == selectedPageID,
                        canDelete: pages.count > 1,
                        onSelect: { selectedPageID = page.id },
                        onDelete: { delete(page) }
                    )
                    .onDrag {
                        draggedPage = page
                        return NSItemProvider(object: page.id.uuidString as NSString)
                    }
                    .onDrop(
                        of: [.text],
                        delegate: PageDropDelegate(item: page, pages: $pages, draggedPage: $draggedPage)
                    )
                }
            }
            .padding(.horizontal, 4)
        }
        .frame(width: 380, height: 100)
    }

    private func delete(_ page: EditablePage) {
        pages.removeAll { $0.id == page.id }
        if selectedPageID == page.id {
            selectedPageID = pages.first?.id
        }
    }
}

// 필터/크롭 결과를 백그라운드에서 렌더링하고 캐시해 드래그·삭제 중 메인 스레드가 멈추지 않게 함
private struct PageThumbnailCell: View {
    let page: EditablePage
    let isSelected: Bool
    let canDelete: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void

    @State private var thumbnail: UIImage?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                } else {
                    Color.secondary.opacity(0.15)
                }
            }
            .frame(width: 64, height: 84)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : .clear, lineWidth: 2)
            }
            .onTapGesture(perform: onSelect)

            if canDelete {
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .black.opacity(0.6))
                }
                .offset(x: 6, y: -6)
            }
        }
        .task(id: "\(page.filter.rawValue)-\(page.version)") {
            let image = page.image
            let filter = page.filter
            thumbnail = await Task.detached(priority: .userInitiated) {
                ImageFilterEngine.apply(filter, to: image)
            }.value
        }
    }
}

private struct PageDropDelegate: DropDelegate {
    let item: EditablePage
    @Binding var pages: [EditablePage]
    @Binding var draggedPage: EditablePage?

    func dropEntered(info: DropInfo) {
        guard let draggedPage,
              draggedPage.id != item.id,
              let fromIndex = pages.firstIndex(where: { $0.id == draggedPage.id }),
              let toIndex = pages.firstIndex(where: { $0.id == item.id }) else { return }

        if pages[toIndex].id != draggedPage.id {
            pages.move(
                fromOffsets: IndexSet(integer: fromIndex),
                toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex
            )
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedPage = nil
        return true
    }
}
