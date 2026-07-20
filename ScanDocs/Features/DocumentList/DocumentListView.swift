// 저장된 스캔 문서를 카드 그리드로 보여주는 홈 화면
import SwiftUI
import SwiftData
import VisionKit

struct DocumentListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ScannedDocument.createdAt, order: .reverse) private var documents: [ScannedDocument]

    @State private var navigationPath = NavigationPath()
    @State private var isShowingScanner = false
    @State private var isShowingUnsupportedAlert = false
    @State private var isShowingEditor = false
    @State private var pagesPendingEdit: [UIImage] = []
    @State private var searchText = ""
    @State private var isSelecting = false
    @State private var selectedDocumentIDs = Set<UUID>()
    @State private var isShowingShareSheet = false
    @State private var shareItems: [Any] = []

    private let columns = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]

    // 제목뿐 아니라 OCR로 추출해둔 페이지 본문 텍스트까지 검색 대상에 포함
    private var filteredDocuments: [ScannedDocument] {
        guard !searchText.isEmpty else { return documents }
        return documents.filter { document in
            document.title.localizedCaseInsensitiveContains(searchText) ||
            document.pages.contains { ($0.recognizedText ?? "").localizedCaseInsensitiveContains(searchText) }
        }
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(filteredDocuments) { document in
                        cardButton(for: document)
                    }
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
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
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isSelecting ? "Done" : "Select") {
                        isSelecting.toggle()
                        if !isSelecting { selectedDocumentIDs.removeAll() }
                    }
                    .disabled(documents.isEmpty)
                }
                ToolbarItemGroup(placement: .bottomBar) {
                    if isSelecting {
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
            .overlay(alignment: .bottomTrailing) {
                if !isSelecting {
                    scanButton
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

    private func cardButton(for document: ScannedDocument) -> some View {
        Button {
            if isSelecting {
                toggleSelection(document.id)
            } else {
                navigationPath.append(document)
            }
        } label: {
            DocumentCardView(
                thumbnail: thumbnail(for: document),
                title: document.title,
                pageCount: document.pages.count,
                createdAt: document.createdAt,
                isSelecting: isSelecting,
                isSelected: selectedDocumentIDs.contains(document.id)
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                Task { await sharePDFs(for: [document]) }
            } label: {
                Label("Share PDF", systemImage: "square.and.arrow.up")
            }
            Button(role: .destructive) {
                modelContext.delete(document)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private var scanButton: some View {
        Button(action: startScan) {
            Image(systemName: "camera.fill")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 60, height: 60)
                .background(
                    LinearGradient(
                        colors: [Color.accentColor, Color.accentColor.opacity(0.75)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(Circle())
                .shadow(color: Color.accentColor.opacity(0.45), radius: 12, y: 6)
        }
        .padding(24)
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
            Text("Tap the camera button to scan your first document.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    private func toggleSelection(_ id: UUID) {
        if selectedDocumentIDs.contains(id) {
            selectedDocumentIDs.remove(id)
        } else {
            selectedDocumentIDs.insert(id)
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

    private func deleteSelected() {
        for document in selectedDocuments {
            modelContext.delete(document)
        }
        selectedDocumentIDs.removeAll()
        isSelecting = false
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
