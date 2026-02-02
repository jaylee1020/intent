import SwiftUI

// MARK: - Crop Overlay
/// An overlay view showing crop rectangles on top of an image
struct CropOverlay: View {
    let frames: [Frame]
    let imageSize: CGSize
    let onFrameTap: (Frame) -> Void

    var body: some View {
        GeometryReader { geometry in
            let viewSize = geometry.size

            // Dark overlay covering entire image
            Rectangle()
                .fill(Theme.Colors.darkOverlay)

            // Cut out clear areas for each frame
            ForEach(frames) { frame in
                let rect = frameRect(for: frame, in: viewSize)

                Button {
                    onFrameTap(frame)
                } label: {
                    Rectangle()
                        .fill(.clear)
                        .background(.clear)
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)
                        .overlay {
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Theme.Colors.cropFrame, lineWidth: 2)
                                .frame(width: rect.width, height: rect.height)
                                .position(x: rect.midX, y: rect.midY)
                        }
                }
                .blendMode(.destinationOut)
            }
        }
        .compositingGroup()
    }

    private func frameRect(for frame: Frame, in viewSize: CGSize) -> CGRect {
        CGRect(
            x: frame.cropRect.x * viewSize.width,
            y: frame.cropRect.y * viewSize.height,
            width: frame.cropRect.width * viewSize.width,
            height: frame.cropRect.height * viewSize.height
        )
    }
}

// MARK: - Rule of Thirds Grid
/// A rule of thirds grid overlay for composition guidance
struct RuleOfThirdsGrid: View {
    var lineColor: Color = .white.opacity(0.7)
    var lineWidth: CGFloat = 1

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height

            Path { path in
                // Vertical lines
                path.move(to: CGPoint(x: width / 3, y: 0))
                path.addLine(to: CGPoint(x: width / 3, y: height))

                path.move(to: CGPoint(x: 2 * width / 3, y: 0))
                path.addLine(to: CGPoint(x: 2 * width / 3, y: height))

                // Horizontal lines
                path.move(to: CGPoint(x: 0, y: height / 3))
                path.addLine(to: CGPoint(x: width, y: height / 3))

                path.move(to: CGPoint(x: 0, y: 2 * height / 3))
                path.addLine(to: CGPoint(x: width, y: 2 * height / 3))
            }
            .stroke(lineColor, lineWidth: lineWidth)
        }
    }
}

// MARK: - Draggable Crop Rectangle
/// An interactive crop rectangle that can be moved and resized
struct DraggableCropRect: View {
    @Binding var cropRect: CropRect
    let aspectRatio: AspectRatio
    let containerSize: CGSize
    var showGrid: Bool = false

    @State private var isDragging = false
    @State private var dragStartRect: CropRect?
    @State private var activeHandle: Handle?

    enum Handle {
        case topLeft, topRight, bottomLeft, bottomRight
        case top, bottom, left, right
        case center
    }

    private let handleSize: CGFloat = 24
    private let minCropSize: CGFloat = 0.1 // 10% minimum

    var body: some View {
        GeometryReader { geometry in
            let rect = currentRect(in: geometry.size)

            ZStack {
                // Dark overlay outside crop area
                Rectangle()
                    .fill(Color.black.opacity(0.6))
                    .mask(
                        Rectangle()
                            .overlay(
                                Rectangle()
                                    .frame(width: rect.width, height: rect.height)
                                    .position(x: rect.midX, y: rect.midY)
                                    .blendMode(.destinationOut)
                            )
                    )
                    .compositingGroup()

                // Crop rectangle border
                Rectangle()
                    .stroke(Color.white, lineWidth: 2)
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)
                    .overlay {
                        if showGrid {
                            RuleOfThirdsGrid()
                                .frame(width: rect.width, height: rect.height)
                                .position(x: rect.midX, y: rect.midY)
                        }
                    }

                // Center drag area
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: rect.width - handleSize * 2, height: rect.height - handleSize * 2)
                    .position(x: rect.midX, y: rect.midY)
                    .gesture(dragGesture(for: .center, containerSize: geometry.size))

                // Corner handles
                cornerHandle(at: .topLeft, rect: rect, containerSize: geometry.size)
                cornerHandle(at: .topRight, rect: rect, containerSize: geometry.size)
                cornerHandle(at: .bottomLeft, rect: rect, containerSize: geometry.size)
                cornerHandle(at: .bottomRight, rect: rect, containerSize: geometry.size)
            }
        }
    }

    private func currentRect(in containerSize: CGSize) -> CGRect {
        CGRect(
            x: cropRect.x * containerSize.width,
            y: cropRect.y * containerSize.height,
            width: cropRect.width * containerSize.width,
            height: cropRect.height * containerSize.height
        )
    }

    @ViewBuilder
    private func cornerHandle(at handle: Handle, rect: CGRect, containerSize: CGSize) -> some View {
        let position = handlePosition(for: handle, rect: rect)
        let isActive = activeHandle == handle

        Circle()
            .fill(Color.white)
            .frame(width: isActive ? handleSize * 1.2 : handleSize,
                   height: isActive ? handleSize * 1.2 : handleSize)
            .shadow(radius: isActive ? 4 : 2)
            .position(position)
            .gesture(dragGesture(for: handle, containerSize: containerSize))
            .animation(Theme.Animation.snappy, value: isActive)
    }

    private func handlePosition(for handle: Handle, rect: CGRect) -> CGPoint {
        switch handle {
        case .topLeft:
            return CGPoint(x: rect.minX, y: rect.minY)
        case .topRight:
            return CGPoint(x: rect.maxX, y: rect.minY)
        case .bottomLeft:
            return CGPoint(x: rect.minX, y: rect.maxY)
        case .bottomRight:
            return CGPoint(x: rect.maxX, y: rect.maxY)
        default:
            return .zero
        }
    }

    private func dragGesture(for handle: Handle, containerSize: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { value in
                if !isDragging {
                    isDragging = true
                    dragStartRect = cropRect
                    activeHandle = handle
                    HapticManager.lightImpact()
                }

                guard let startRect = dragStartRect else { return }

                let deltaX = value.translation.width / containerSize.width
                let deltaY = value.translation.height / containerSize.height

                withAnimation(Theme.Animation.quick) {
                    updateCropRect(handle: handle, startRect: startRect, deltaX: deltaX, deltaY: deltaY)
                }
            }
            .onEnded { _ in
                HapticManager.lightImpact()
                withAnimation(Theme.Animation.spring) {
                    isDragging = false
                    dragStartRect = nil
                    activeHandle = nil
                }
            }
    }

    private func updateCropRect(handle: Handle, startRect: CropRect, deltaX: CGFloat, deltaY: CGFloat) {
        var newRect = startRect

        switch handle {
        case .center:
            // Move the entire rectangle
            newRect.x = max(0, min(startRect.x + deltaX, 1 - startRect.width))
            newRect.y = max(0, min(startRect.y + deltaY, 1 - startRect.height))

        case .topLeft:
            let newX = max(0, min(startRect.x + deltaX, startRect.x + startRect.width - minCropSize))
            let newY = max(0, min(startRect.y + deltaY, startRect.y + startRect.height - minCropSize))
            newRect.width = startRect.width - (newX - startRect.x)
            newRect.height = startRect.height - (newY - startRect.y)
            newRect.x = newX
            newRect.y = newY

        case .topRight:
            let newWidth = max(minCropSize, min(startRect.width + deltaX, 1 - startRect.x))
            let newY = max(0, min(startRect.y + deltaY, startRect.y + startRect.height - minCropSize))
            newRect.width = newWidth
            newRect.height = startRect.height - (newY - startRect.y)
            newRect.y = newY

        case .bottomLeft:
            let newX = max(0, min(startRect.x + deltaX, startRect.x + startRect.width - minCropSize))
            let newHeight = max(minCropSize, min(startRect.height + deltaY, 1 - startRect.y))
            newRect.x = newX
            newRect.width = startRect.width - (newX - startRect.x)
            newRect.height = newHeight

        case .bottomRight:
            newRect.width = max(minCropSize, min(startRect.width + deltaX, 1 - startRect.x))
            newRect.height = max(minCropSize, min(startRect.height + deltaY, 1 - startRect.y))

        default:
            break
        }

        // Apply aspect ratio constraint if needed
        if let ratio = aspectRatio.ratio, ratio > 0, newRect.height > 0, newRect.width > 0 {
            let currentRatio = newRect.width / newRect.height
            if currentRatio > ratio {
                newRect.width = newRect.height * ratio
            } else {
                newRect.height = newRect.width / ratio
            }
        }

        cropRect = newRect
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        Color.gray

        RuleOfThirdsGrid()
            .padding(40)
    }
    .ignoresSafeArea()
}
