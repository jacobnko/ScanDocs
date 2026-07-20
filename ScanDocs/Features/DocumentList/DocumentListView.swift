// 저장된 스캔 문서 목록을 보여주는 홈 화면
import SwiftUI
import SwiftData
import VisionKit

struct DocumentListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ScannedDocument.createdAt, order: .reverse) private var documents: [ScannedDocument]

    @State private var isShowingScanner = false
    @State private var isShowingUnsupportedAlert = false
    @State private var isShowingEditor = false
    @State private var pagesPendingEdit: [UIImage] = []
    @State private var searchText = ""

    private var filteredDocuments: [ScannedDocument] {
        guard !searchText.isEmpty else { return documents }
        return documents.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredDocuments) { document in
                    NavigationLink(value: document) {
                        DocumentRowView(
                            thumbnail: thumbnail(for: document),
                            title: document.title,
                            pageCount: document.pages.count,
                            createdAt: document.createdAt
                        )
                    }
                }
                .onDelete(perform: deleteDocuments)
            }
            .overlay {
                if documents.isEmpty {
                    ContentUnavailableView(
                        "No Documents",
                        systemImage: "doc.viewfinder",
                        description: Text("Tap + to scan a document.")
                    )
                }
            }
            .navigationTitle("ScanDocs")
            .searchable(text: $searchText, prompt: "Search documents")
            .navigationDestination(for: ScannedDocument.self) { document in
                DocumentDetailView(document: document)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: startScan) {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .frame(width: 380)
        .fullScreenCover(isPresented: $isShowingScanner) {
            DocumentScannerView(
                onFinish: { pages in
                    isShowingScanner = false
                    pagesPendingEdit = pages
                    isShowingEditor = true
                },
                onCancel: {
                    isShowingScanner = false
                }
            )
            .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $isShowingEditor) {
            DocumentEditorView(
                initialPages: pagesPendingEdit,
                onSave: { editedPages in
                    await saveDocument(pages: editedPages)
                    isShowingEditor = false
                },
                onCancel: {
                    isShowingEditor = false
                }
            )
        }
        .alert("Scanning Not Supported", isPresented: $isShowingUnsupportedAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("This device or simulator does not support document scanning.")
        }
    }

    private func startScan() {
        guard VNDocumentCameraViewController.isSupported else {
            isShowingUnsupportedAlert = true
            return
        }
        isShowingScanner = true
    }

    private func thumbnail(for document: ScannedDocument) -> UIImage? {
        guard let firstPage = document.pages.min(by: { $0.order < $1.order }),
              let image = UIImage(data: firstPage.imageData) else { return nil }
        let filter = ImageFilterType(rawValue: firstPage.filterType) ?? .original
        return ImageFilterEngine.apply(filter, to: image)
    }

    // 편집 화면에서 확정된 페이지들(필터 종류 포함)을 OCR 처리 후 SwiftData에 저장
    private func saveDocument(pages: [EditablePage]) async {
        guard !pages.isEmpty else { return }
        let document = ScannedDocument(title: "Untitled \(documents.count + 1)")
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
        modelContext.insert(document)
    }

    private func deleteDocuments(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(filteredDocuments[index])
        }
    }
}

#Preview {
    DocumentListView()
        .modelContainer(for: ScannedDocument.self, inMemory: true)
        .frame(width: 400, height: 600)
        .preferredColorScheme(.light)
}
