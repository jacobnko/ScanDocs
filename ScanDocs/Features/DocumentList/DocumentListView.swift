// 저장된 스캔 문서 목록을 보여주는 홈 화면
import SwiftUI
import SwiftData

struct DocumentListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ScannedDocument.createdAt, order: .reverse) private var documents: [ScannedDocument]

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
                if documents.isEmpty {
                    ContentUnavailableView(
                        "No Documents",
                        systemImage: "doc.viewfinder",
                        description: Text("Tap + to add a test document.")
                    )
                }
            }
            .navigationTitle("ScanDocs")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: addDummyDocument) {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .frame(width: 380)
    }

    // Step 2에서 실제 VisionKit 스캔 플로우로 교체될 임시 더미 데이터 생성 함수
    private func addDummyDocument() {
        let document = ScannedDocument(title: "Untitled \(documents.count + 1)")
        let page = DocumentPage(order: 0, imageData: Data())
        page.document = document
        document.pages.append(page)
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
