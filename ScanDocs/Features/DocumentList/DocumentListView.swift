// 저장된 스캔 문서 목록을 보여주는 홈 화면
import SwiftUI
import SwiftData
import VisionKit

struct DocumentListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ScannedDocument.createdAt, order: .reverse) private var documents: [ScannedDocument]

    @State private var isShowingScanner = false
    @State private var isShowingUnsupportedAlert = false
    @State private var isProcessing = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(documents) { document in
                    DocumentRowView(
                        title: document.title,
                        pageCount: document.pages.count,
                        createdAt: document.createdAt
                    )
                }
                .onDelete(perform: deleteDocuments)
            }
            .overlay {
                if isProcessing {
                    ProgressView("Recognizing text…")
                } else if documents.isEmpty {
                    ContentUnavailableView(
                        "No Documents",
                        systemImage: "doc.viewfinder",
                        description: Text("Tap + to scan a document.")
                    )
                }
            }
            .navigationTitle("ScanDocs")
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
                    isProcessing = true
                    Task {
                        await saveScannedDocument(pages: pages)
                        isProcessing = false
                    }
                },
                onCancel: {
                    isShowingScanner = false
                }
            )
            .ignoresSafeArea()
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

    private func saveScannedDocument(pages: [UIImage]) async {
        guard !pages.isEmpty else { return }
        let document = ScannedDocument(title: "Untitled \(documents.count + 1)")
        for (index, image) in pages.enumerated() {
            let imageData = image.jpegData(compressionQuality: 0.8) ?? Data()
            let recognizedText = await OCRService.recognizeText(in: image)
            let page = DocumentPage(order: index, imageData: imageData, recognizedText: recognizedText)
            page.document = document
            document.pages.append(page)
        }
        modelContext.insert(document)
    }

    private func deleteDocuments(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(documents[index])
        }
    }
}

#Preview {
    DocumentListView()
        .modelContainer(for: ScannedDocument.self, inMemory: true)
        .frame(width: 400, height: 600)
        .preferredColorScheme(.light)
}
