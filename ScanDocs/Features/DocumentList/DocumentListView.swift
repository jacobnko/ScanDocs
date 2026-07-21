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
    @State private var editMode: EditMode = .inactive
    @State private var selectedDocumentIDs = Set<UUID>()
    @State private var isShowingShareSheet = false
    @State private var shareItems: [Any] = []

    // 제목뿐 아니라 OCR로 추출해둔 페이지 본문 텍스트까지 검색 대상에 포함
    private var filteredDocuments: [ScannedDocument] {
        guard !searchText.isEmpty else { return documents }
        return documents.filter { document in
            document.title.localizedCaseInsensitiveContains(searchText) ||
            document.pages.contains { ($0.recognizedText ?? "").localizedCaseInsensitiveContains(searchText) }
        }
    }

    var body: some View {
        NavigationStack {
            List(selection: $selectedDocumentIDs) {
                ForEach(filteredDocuments) { document in
                    NavigationLink(value: document) {
                        let firstPage = document.pages.min { $0.order < $1.order }
                        DocumentRowView(
                            title: document.title,
                            pageCount: document.pages.count,
                            createdAt: document.createdAt,
                            thumbnailData: firstPage?.imageData,
                            thumbnailFilterType: firstPage?.filterType ?? ImageFilterType.original.rawValue
                        )
                    }
                }
                .onDelete(perform: deleteDocuments)
            }
            .environment(\.editMode, $editMode)
            .overlay {
                if documents.isEmpty {
                    emptyState
                }
            }
            .navigationTitle("ScanDocs")
            .searchable(text: $searchText, prompt: "Search title or text")
            .navigationDestination(for: ScannedDocument.self) { document in
                DocumentDetailView(document: document)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: startScan) {
                        Image(systemName: "camera.fill")
                    }
                }
                ToolbarItemGroup(placement: .bottomBar) {
                    if editMode == .active {
                        Button(role: .destructive, action: deleteSelected) {
                            Label("Delete", systemImage: "trash")
                        }
                        .disabled(selectedDocumentIDs.isEmpty)

                        Spacer()

                        Button {
                            Task { await sharePDFs(for: selectedDocuments) }
                        } label: {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                        .disabled(selectedDocumentIDs.isEmpty)
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
        .sheet(isPresented: $isShowingShareSheet) {
            ActivityView(activityItems: shareItems)
        }
        .alert("Scanning Not Supported", isPresented: $isShowingUnsupportedAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("This device or simulator does not support document scanning.")
        }
    }

    private var selectedDocuments: [ScannedDocument] {
        documents.filter { selectedDocumentIDs.contains($0.id) }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.accentColor.opacity(0.28), Color.accentColor.opacity(0.08)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 96, height: 96)
                Image(systemName: "doc.text.viewfinder")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.accentColor)
            }
            Text("No Documents Yet")
                .font(.headline)
            Text("Scan your first document to get started.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button(action: startScan) {
                Label("Scan a Document", systemImage: "camera.fill")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.accentColor, in: Capsule())
                    .foregroundStyle(.white)
            }
            .buttonStyle(PressableButtonStyle())
            .padding(.top, 4)
        }
    }

    private func startScan() {
        guard VNDocumentCameraViewController.isSupported else {
            isShowingUnsupportedAlert = true
            return
        }
        Haptics.impact(.medium)
        isShowingScanner = true
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
        Haptics.success()
    }

    private func deleteDocuments(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(filteredDocuments[index])
        }
    }

    private func deleteSelected() {
        for document in selectedDocuments {
            modelContext.delete(document)
        }
        selectedDocumentIDs.removeAll()
        editMode = .inactive
    }

    private func sharePDFs(for docs: [ScannedDocument]) async {
        var urls: [URL] = []
        for document in docs {
            let data = await PDFExporter.makePDF(from: document)
            let safeName = document.title.replacingOccurrences(of: "/", with: "-")
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("\(safeName)-\(document.id.uuidString.prefix(6)).pdf")
            if (try? data.write(to: url)) != nil {
                urls.append(url)
            }
        }
        guard !urls.isEmpty else { return }
        shareItems = urls
        isShowingShareSheet = true
    }
}

#Preview {
    DocumentListView()
        .modelContainer(for: ScannedDocument.self, inMemory: true)
        .frame(width: 400, height: 600)
        .preferredColorScheme(.light)
}
