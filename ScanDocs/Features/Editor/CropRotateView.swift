// 선택한 페이지를 회전하거나 사각형 크롭 핸들로 다듬는 화면
import SwiftUI

struct CropRotateView: View {
    let onApply: (_ newImage: UIImage) -> Void
    let onCancel: () -> Void

    @State private var workingImage: UIImage
    @State private var topLeft: CGPoint = .zero
    @State private var bottomRight: CGPoint = .zero
    @State private var containerSize: CGSize = .zero

    init(originalImage: UIImage, onApply: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
        _workingImage = State(initialValue: originalImage)
        self.onApply = onApply
        self.onCancel = onCancel
    }

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                let displayRect = imageDisplayRect(imageSize: workingImage.size, in: proxy.size)
                ZStack {
                    Image(uiImage: workingImage)
                        .resizable()
                        .scaledToFit()

                    CropOverlay(displayRect: displayRect, topLeft: $topLeft, bottomRight: $bottomRight)
                }
                .onAppear { setupHandles(in: proxy.size) }
                .onChange(of: proxy.size) { _, newSize in setupHandles(in: newSize) }
                .onChange(of: workingImage) { _, _ in setupHandles(in: proxy.size) }
            }
            .frame(width: 380, height: 420)
            .navigationTitle("Crop & Rotate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel, action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply", action: applyCrop)
                }
                ToolbarItemGroup(placement: .bottomBar) {
                    Button { rotate(clockwise: false) } label: {
                        Image(systemName: "rotate.left")
                    }
                    Spacer()
                    Text("Drag corners to crop")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button { rotate(clockwise: true) } label: {
                        Image(systemName: "rotate.right")
                    }
                }
            }
        }
    }

    private func rotate(clockwise: Bool) {
        workingImage = ImageTransformEngine.rotated90(workingImage, clockwise: clockwise)
    }

    private func setupHandles(in size: CGSize) {
        containerSize = size
        let displayRect = imageDisplayRect(imageSize: workingImage.size, in: size)
        let inset = min(displayRect.width, displayRect.height) * 0.08
        topLeft = CGPoint(x: displayRect.minX + inset, y: displayRect.minY + inset)
        bottomRight = CGPoint(x: displayRect.maxX - inset, y: displayRect.maxY - inset)
    }

    private func applyCrop() {
        let displayRect = imageDisplayRect(imageSize: workingImage.size, in: containerSize)
        guard displayRect.width > 0, displayRect.height > 0 else {
            onApply(workingImage)
            return
        }

        let normalizedRect = CGRect(
            x: (topLeft.x - displayRect.minX) / displayRect.width,
            y: (topLeft.y - displayRect.minY) / displayRect.height,
            width: (bottomRight.x - topLeft.x) / displayRect.width,
            height: (bottomRight.y - topLeft.y) / displayRect.height
        ).intersection(CGRect(x: 0, y: 0, width: 1, height: 1))

        guard normalizedRect.width > 0.02, normalizedRect.height > 0.02 else {
            onApply(workingImage)
            return
        }

        onApply(ImageTransformEngine.cropped(workingImage, to: normalizedRect))
    }
}

// SwiftUI 좌표계(위→아래, 컨테이너 기준)에서 .scaledToFit 이미지가 실제로 그려지는 사각형 계산
private func imageDisplayRect(imageSize: CGSize, in containerSize: CGSize) -> CGRect {
    guard imageSize.width > 0, imageSize.height > 0, containerSize.width > 0, containerSize.height > 0 else {
        return CGRect(origin: .zero, size: containerSize)
    }
    let imageAspect = imageSize.width / imageSize.height
    let containerAspect = containerSize.width / containerSize.height

    var displaySize = containerSize
    if imageAspect > containerAspect {
        displaySize.height = containerSize.width / imageAspect
    } else {
        displaySize.width = containerSize.height * imageAspect
    }
    let origin = CGPoint(
        x: (containerSize.width - displaySize.width) / 2,
        y: (containerSize.height - displaySize.height) / 2
    )
    return CGRect(origin: origin, size: displaySize)
}

private struct CropOverlay: View {
    let displayRect: CGRect
    @Binding var topLeft: CGPoint
    @Binding var bottomRight: CGPoint

    var body: some View {
        ZStack {
            Path { path in
                path.addRect(CGRect(
                    x: topLeft.x,
                    y: topLeft.y,
                    width: bottomRight.x - topLeft.x,
                    height: bottomRight.y - topLeft.y
                ))
            }
            .stroke(Color.accentColor, lineWidth: 2)

            handle(for: $topLeft, in: displayRect)
            handle(for: $bottomRight, in: displayRect)
        }
    }

    private func handle(for point: Binding<CGPoint>, in bounds: CGRect) -> some View {
        Circle()
            .fill(Color.accentColor)
            .frame(width: 24, height: 24)
            .position(point.wrappedValue)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        point.wrappedValue = CGPoint(
                            x: min(max(value.location.x, bounds.minX), bounds.maxX),
                            y: min(max(value.location.y, bounds.minY), bounds.maxY)
                        )
                    }
            )
    }
}

#Preview {
    CropRotateView(
        originalImage: UIImage(systemName: "doc.text")!,
        onApply: { _ in },
        onCancel: {}
    )
    .frame(width: 400, height: 600)
    .preferredColorScheme(.light)
}
