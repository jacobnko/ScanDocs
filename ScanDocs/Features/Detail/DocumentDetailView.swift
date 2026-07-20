// 문서 상세 화면: 페이지 스와이프 뷰어, 파일명 변경, 재편집 진입
import SwiftUI
import SwiftData

struct DocumentDetailView: View {
    let document: ScannedDocument

    @Environment(\.modelContext) private var modelContext
    @State private var isEditingTitle = false
    @State private var editedTitle = ""
    @State private var isShowingEditor = false

    private var sortedPages: [DocumentPage] {
        document.pages.sorted { $0.order < $1.order }
    }

    var body: some View {
        TabView {
            ForEach(sortedPages) { page in
                if let uiImage = UIImage(data: page.imageData) {
                    let filter = ImageFilterType(rawValue: page.filterType) ?? .original
                    Image(uiImage: ImageFilterEngine.apply(filter, to: uiImage))
                        .resizable()
                        .scaledToFit()
                        .padding()
                }
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .automatic))
        .frame(width: 380)
        .navigationTitle(document.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Rename", systemImage: "pencil", action: startRename)
                    Button("Edit Pages", systemImage: "slider.horizontal.3") {
                        isShowingEditor = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .alert("Rename Document", isPresented: $isEditingTitle) {
            TextField("Title", text: $editedTitle)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                document.title = editedTitle
            }
        }
        .fullScreenCover(isPresented: $isShowingEditor) {
            DocumentEditorView(
                initialPages: sortedPages.compactMap { UIImage(data: $0.imageData) },
                onSave: { editedPages in
                    await applyEdits(editedPages)
                    isShowingEditor = false
                },
                onCancel: {
                    isShowingEditor = false
                }
            )
        }
    }

    private func startRename() {
        editedTitle = document.title
        isEditingTitle = true
    }

    // 재편집 저장 시 기존 페이지를 전부 지우고 편집된 페이지로 교체
    private func applyEdits(_ pages: [EditablePage]) async {
        for page in document.pages {
            modelContext.delete(page)
        }
        document.pages.removeAll()

        for (index, page) in pages.enumerated() {
            let imageData = page.image.jpegData(compressionQuality: 0.8) ?? Data()
            let recognizedText = await OCRService.recognizeText(in: page.image)
            let documentPage = DocumentPage(
                order: index,
                imageData: imageData,
                filterType: page.filter.rawValue,
                recognizedText: recognizedText
            )
            documentPage.document = document
            document.pages.append(documentPage)
        }
    }
}
