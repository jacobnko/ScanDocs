// ScanDocs 앱의 진입점
import SwiftUI
import SwiftData

@main
struct ScanDocsApp: App {
    var body: some Scene {
        WindowGroup {
            DocumentListView()
        }
        .modelContainer(for: [ScannedDocument.self, DocumentPage.self])
    }
}
