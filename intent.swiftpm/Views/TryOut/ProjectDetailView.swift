import SwiftUI

// MARK: - Project Detail View
/// Shows the original photo with crop frame overlays
struct ProjectDetailView: View {
    let projectId: UUID
    @EnvironmentObject var projectStorage: ProjectStorage
    @State private var showingCropView = false
    @State private var selectedFrame: Frame?
    @State private var showingFullScreenCrop = false

    /// Get the current project from storage (ensures we always have latest data)
    private var project: Project? {
        projectStorage.projects.first { $0.id == projectId }
    }

    var body: some View {
        Group {
            if let project = project {
                projectContent(project: project)
            } else {
                ContentUnavailableView("Project Not Found", systemImage: "exclamationmark.triangle")
            }
        }
        .navigationTitle(project?.name ?? "Project")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showingCropView) {
            if let project = project {
                CropView(project: project)
                    .environmentObject(projectStorage)
            }
        }
        .fullScreenCover(isPresented: $showingFullScreenCrop) {
            if let frame = selectedFrame, let project = project, let image = project.originalImage {
                FullScreenCropView(frame: frame, originalImage: image, project: project)
                    .environmentObject(projectStorage)
            }
        }
    }

    @ViewBuilder
    private func projectContent(project: Project) -> some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: Theme.Spacing.md) {
                    // Original image with frame overlays
                    if let image = project.originalImage {
                        ZStack {
                            // Original image
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)

                            // Frame overlays (only if there are frames)
                            if !project.frames.isEmpty {
                                GeometryReader { imageGeometry in
                                    FrameOverlayView(
                                        frames: project.frames,
                                        containerSize: imageGeometry.size,
                                        onFrameTap: { frame in
                                            HapticManager.mediumImpact()
                                            selectedFrame = frame
                                            showingFullScreenCrop = true
                                        }
                                    )
                                }
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
                        .padding(.horizontal, Theme.Spacing.md)
                    }

                    // Frame count info
                    if !project.frames.isEmpty {
                        HStack {
                            Image(systemName: "square.on.square")
                                .foregroundStyle(.secondary)

                            Text("\(project.frames.count) frame\(project.frames.count == 1 ? "" : "s") created")
                                .font(Theme.Typography.subheadline)
                                .foregroundStyle(.secondary)

                            Spacer()
                        }
                        .padding(.horizontal, Theme.Spacing.lg)
                    }

                    // Frame thumbnails
                    if !project.frames.isEmpty, let originalImage = project.originalImage {
                        FrameThumbnailGrid(
                            frames: project.frames,
                            originalImage: originalImage,
                            onFrameTap: { frame in
                                HapticManager.mediumImpact()
                                selectedFrame = frame
                                showingFullScreenCrop = true
                            }
                        )
                        .padding(.horizontal, Theme.Spacing.md)
                    }

                    // Add frame button
                    LiquidGlassFullWidthButton(
                        title: "Add Frame",
                        icon: "plus.viewfinder"
                    ) {
                        HapticManager.mediumImpact()
                        showingCropView = true
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.top, Theme.Spacing.sm)

                    // Instructions
                    if project.frames.isEmpty {
                        VStack(spacing: Theme.Spacing.xs) {
                            Text("Tap \"Add Frame\" to find multiple photos")
                                .font(Theme.Typography.subheadline)
                                .foregroundStyle(.secondary)

                            Text("within this single image.")
                                .font(Theme.Typography.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, Theme.Spacing.sm)
                    }

                    Spacer()
                        .frame(height: Theme.Spacing.xl)
                }
                .padding(.top, Theme.Spacing.md)
            }
        }
    }
}

// MARK: - Frame Overlay View
/// Shows dark overlay with clear cutouts for each frame
struct FrameOverlayView: View {
    let frames: [Frame]
    let containerSize: CGSize
    let onFrameTap: (Frame) -> Void

    var body: some View {
        Canvas { context, size in
            // Draw dark overlay
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .color(.black.opacity(0.5))
            )

            // Cut out frame areas
            for frame in frames {
                let rect = CGRect(
                    x: frame.cropRect.x * size.width,
                    y: frame.cropRect.y * size.height,
                    width: frame.cropRect.width * size.width,
                    height: frame.cropRect.height * size.height
                )

                context.blendMode = .destinationOut
                context.fill(Path(rect), with: .color(.white))
                context.blendMode = .normal
            }
        }
        .compositingGroup()
        .allowsHitTesting(false)

        // Overlay tappable frame borders
        ForEach(frames) { frame in
            let rect = CGRect(
                x: frame.cropRect.x * containerSize.width,
                y: frame.cropRect.y * containerSize.height,
                width: frame.cropRect.width * containerSize.width,
                height: frame.cropRect.height * containerSize.height
            )

            Button {
                onFrameTap(frame)
            } label: {
                Rectangle()
                    .stroke(Color.white, lineWidth: 2)
                    .frame(width: rect.width, height: rect.height)
            }
            .position(x: rect.midX, y: rect.midY)
        }
    }
}

// MARK: - Frame Thumbnail Grid
struct FrameThumbnailGrid: View {
    let frames: [Frame]
    let originalImage: UIImage
    let onFrameTap: (Frame) -> Void

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Your Frames")
                .font(Theme.Typography.headline)
                .padding(.horizontal, Theme.Spacing.xs)

            LazyVGrid(columns: columns, spacing: Theme.Spacing.sm) {
                ForEach(frames) { frame in
                    FrameThumbnail(
                        frame: frame,
                        originalImage: originalImage
                    ) {
                        onFrameTap(frame)
                    }
                }
            }
        }
    }
}

// MARK: - Frame Thumbnail
struct FrameThumbnail: View {
    let frame: Frame
    let originalImage: UIImage
    let onTap: () -> Void

    @State private var croppedImage: UIImage?

    var body: some View {
        Button(action: {
            HapticManager.mediumImpact()
            onTap()
        }) {
            Group {
                if let cropped = croppedImage {
                    Image(uiImage: cropped)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Rectangle()
                        .fill(Theme.Colors.tertiaryBackground)
                        .overlay {
                            Image(systemName: "photo")
                                .foregroundStyle(.secondary)
                        }
                }
            }
            .frame(height: 100)
            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.small))
        }
        .buttonStyle(.plain)
        .task {
            // Cache the cropped image on first load
            if croppedImage == nil {
                croppedImage = ImageProcessor.cropImage(originalImage, with: frame.cropRect)
            }
        }
    }
}

// MARK: - Full Screen Crop View
struct FullScreenCropView: View {
    let frame: Frame
    let originalImage: UIImage
    let project: Project
    @EnvironmentObject var projectStorage: ProjectStorage
    @Environment(\.dismiss) private var dismiss
    @State private var showingSaveSuccess = false
    @State private var isSaving = false
    @State private var showingPermissionAlert = false
    @State private var croppedImage: UIImage?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let cropped = croppedImage {
                Image(uiImage: cropped)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                // Fallback if image fails to load
                VStack(spacing: Theme.Spacing.md) {
                    Image(systemName: "photo")
                        .font(.system(size: 48))
                        .foregroundStyle(.gray)
                    Text("Unable to load image")
                        .font(Theme.Typography.subheadline)
                        .foregroundStyle(.gray)
                }
            }

            // Top toolbar overlay
            VStack {
                HStack {
                    // Close button
                    Button {
                        dismiss()
                    } label: {
                        Text("Close")
                            .font(Theme.Typography.headline)
                            .foregroundStyle(.white)
                            .padding(.horizontal, Theme.Spacing.md)
                            .padding(.vertical, Theme.Spacing.sm)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                    }

                    Spacer()

                    // Save button
                    Button {
                        saveToPhotoLibrary()
                    } label: {
                        Group {
                            if isSaving {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "square.and.arrow.down")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                    }
                    .disabled(isSaving)

                    // Delete button
                    Button {
                        HapticManager.heavyImpact()
                        deleteFrame()
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.red)
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.top, Theme.Spacing.md)

                Spacer()
            }
        }
        .alert("Saved!", isPresented: $showingSaveSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("The cropped photo has been saved to your photo library.")
        }
        .permissionDeniedAlert(isPresented: $showingPermissionAlert, for: .photoLibrary)
        .task {
            // Cache the cropped image on first load
            if croppedImage == nil {
                croppedImage = ImageProcessor.cropImage(originalImage, with: frame.cropRect)
            }
        }
    }

    private func saveToPhotoLibrary() {
        guard let cropped = croppedImage else { return }
        isSaving = true

        ImageProcessor.saveToPhotoLibrary(cropped) { success, error, isDenied in
            isSaving = false
            if success {
                HapticManager.success()
                showingSaveSuccess = true
            } else if isDenied {
                showingPermissionAlert = true
            }
        }
    }

    private func deleteFrame() {
        var updatedProject = project
        updatedProject.frames.removeAll { $0.id == frame.id }
        projectStorage.updateProject(updatedProject)
        dismiss()
    }
}

// MARK: - Preview
#Preview {
    let storage = ProjectStorage()
    let sampleProject = Project(
        name: "Sample Project",
        originalImageData: UIImage(systemName: "photo")?.pngData() ?? Data()
    )
    storage.projects.append(sampleProject)

    return NavigationStack {
        ProjectDetailView(projectId: sampleProject.id)
            .environmentObject(storage)
    }
}
