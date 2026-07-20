// 스캔 직후 페이지 순서 변경·삭제·필터 적용·추가 스캔을 진행하는 편집 화면
import SwiftUI

// 편집 화면에서만 쓰이는 임시(비영속) 페이지 상태
struct EditablePage: Identifiable {
    let id = UUID()
    var image: UIImage
    var filter: ImageFilterType = .auto
}

struct DocumentEditorView: View {
    let onSave: (_ pages: [EditablePage]) async -> Void
    let onCancel: () -> Void

    @State private var pages: [EditablePage]
    @State private var selectedPageID: EditablePage.ID?
    @State private var isShowingScanner = false
    @State private var isShowingCropRotate = false
    @State private var isSaving = false

    init(
        initialPages: [UIImage],
        onSave: @escaping (_ pages: [EditablePage]) async -> Void,
        onCancel: @escaping () -> Void
    ) {
        let editablePages = initialPages.map { EditablePage(image: $0) }
        _pages = State(initialValue: editablePages)
        _selectedPageID = State(initialValue: editablePages.first?.id)
        self.onSave = onSave
        self.onCancel = onCancel
    }

    private var selectedPage: EditablePage? {
        pages.first { $0.id == selectedPageID }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if let selectedPage {
                    FilterPickerView(
                        originalImage: selectedPage.image,
                        selectedFilter: filterBinding(for: selectedPage.id)
                    )
                } else {
                    ContentUnavailableView("No Pages", systemImage: "doc.text")
                }

                Spacer(minLength: 0)

                PageThumbnailStrip(pages: $pages, selectedPageID: $selectedPageID)

                HStack {
                    Button {
                        isShowingCropRotate = true
                    } label: {
                        Label("Crop & Rotate", systemImage: "crop.rotate")
                    }
                    .buttonStyle(PressableButtonStyle())
                    .disabled(selectedPage == nil)

                    Spacer()

                    Button {
                        isShowingScanner = true
                    } label: {
                        Label("Add Pages", systemImage: "camera")
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }
            .padding()
            .frame(width: 380)
            .navigationTitle("Edit Scan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel, action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            isSaving = true
                            await onSave(pages)
                            isSaving = false
                        }
                    }
                    .disabled(pages.isEmpty || isSaving)
                }
            }
            .overlay {
                if isSaving {
                    ProgressView("Saving…")
                }
            }
        }
        .fullScreenCover(isPresented: $isShowingScanner) {
            DocumentScannerView(
                onFinish: { newPages in
                    isShowingScanner = false
                    let appended = newPages.map { EditablePage(image: $0) }
                    pages.append(contentsOf: appended)
                    if selectedPageID == nil {
                        selectedPageID = appended.first?.id
                    }
                },
                onCancel: {
                    isShowingScanner = false
                }
            )
            .ignoresSafeArea()
        }
        .sheet(isPresented: $isShowingCropRotate) {
            if let selectedPage {
                CropRotateView(
                    originalImage: selectedPage.image,
                    onApply: { newImage in
                        if let index = pages.firstIndex(where: { $0.id == selectedPage.id }) {
                            pages[index].image = newImage
                        }
                        isShowingCropRotate = false
                    },
                    onCancel: {
                        isShowingCropRotate = false
                    }
                )
            }
        }
    }

    private func filterBinding(for id: EditablePage.ID) -> Binding<ImageFilterType> {
        Binding(
            get: { pages.first { $0.id == id }?.filter ?? .original },
            set: { newValue in
                if let index = pages.firstIndex(where: { $0.id == id }) {
                    pages[index].filter = newValue
                }
            }
        )
    }
}

#Preview {
    DocumentEditorView(
        initialPages: [UIImage(systemName: "doc.text")!],
        onSave: { _ in },
        onCancel: {}
    )
    .frame(width: 400, height: 600)
    .preferredColorScheme(.light)
}
