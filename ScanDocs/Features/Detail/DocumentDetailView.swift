// 문서 상세 화면: 페이지 스와이프 뷰어, 파일명 변경, 재편집, PDF/이미지 공유, 사진 앱 저장
import SwiftUI
import SwiftData

struct DocumentDetailView: View {
    let document: ScannedDocument

    @Environment(\.modelContext) private var modelContext
    @State private var isEditingTitle = false
    @State private var editedTitle = ""
    @State private var isShowingEditor = false
    @State private var selectedPageIndex = 0
    @State private var isShowingShareSheet = false
    @State private var shareItems: [Any] = []
    @State private var isShowingSaveResultAlert = false
    @State private var saveResultMessage = ""

    private var sortedPages: [DocumentPage] {
        document.pages.sorted { $0.order < $1.order }
    }

    var body: some View {
        TabView(selection: $selectedPageIndex) {
            ForEach(Array(sortedPages.enumerated()), id: \.offset) { index, page in
                ZoomablePageView(page: page)
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .automatic))
        .background(Color(.secondarySystemBackground))
        .overlay(alignment: .top) {
            if sortedPages.count > 1 {
                Text("\(selectedPageIndex + 1) of \(sortedPages.count)")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.thinMaterial, in: Capsule())
                    .padding(.top, 8)
            }
        }
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
                    Divider()
                    Button("Share PDF", systemImage: "doc.richtext") {
                        Task { presentShareSheet(with: await makePDFShareURL()) }
                    }
                    Button("Share Current Page", systemImage: "photo") {
                        Task { presentShareSheet(with: await currentPageImage()) }
                    }
                    Button("Save Current Page to Photos", systemImage: "square.and.arrow.down") {
                        Task { await saveCurrentPageToPhotos() }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 32, height: 32)
                        .background(.thinMaterial, in: Circle())
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
        .alert("Save to Photos", isPresented: $isShowingSaveResultAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveResultMessage)
        }
        .sheet(isPresented: $isShowingShareSheet) {
            ActivityView(activityItems: shareItems)
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

    private func currentPageImage() async -> UIImage? {
        guard sortedPages.indices.contains(selectedPageIndex) else { return nil }
        let page = sortedPages[selectedPageIndex]
        let imageData = page.imageData
        let filterTypeRaw = page.filterType
        return await Task.detached(priority: .userInitiated) {
            guard let image = UIImage(data: imageData) else { return nil }
            let filter = ImageFilterType(rawValue: filterTypeRaw) ?? .original
            return ImageFilterEngine.apply(filter, to: image)
        }.value
    }

    private func makePDFShareURL() async -> URL? {
        let data = await PDFExporter.makePDF(from: document)
        let safeName = document.title.replacingOccurrences(of: "/", with: "-")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(safeName).pdf")
        do {
            try data.write(to: url)
            return url
        } catch {
            return nil
        }
    }

    private func presentShareSheet(with item: Any?) {
        guard let item else { return }
        shareItems = [item]
        isShowingShareSheet = true
    }

    private func saveCurrentPageToPhotos() async {
        guard let image = await currentPageImage() else { return }
        do {
            try await PhotoLibraryExporter.save(image)
            saveResultMessage = "Saved to Photos."
        } catch {
            saveResultMessage = "Couldn't save to Photos. Check permission in Settings."
        }
        isShowingSaveResultAlert = true
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
