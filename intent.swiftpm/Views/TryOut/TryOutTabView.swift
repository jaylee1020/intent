import SwiftUI
import PhotosUI
import AVFoundation

// MARK: - Try Out Tab View
/// The main Try Out tab for managing photography projects
struct TryOutTabView: View {
    @EnvironmentObject var projectStorage: ProjectStorage
    @StateObject private var permissionManager = PermissionManager()
    @State private var selectedItem: PhotosPickerItem?
    @State private var isLoading = false
    @State private var showingPhotoPicker = false
    @State private var showingCamera = false
    @State private var selectedProject: Project?
    @State private var projectToRename: Project?
    @State private var newProjectName = ""
    @State private var showingRenameAlert = false
    @State private var showingCameraPermissionAlert = false
    @State private var showingPhotoLibraryPermissionAlert = false
    @State private var showingImageLoadError = false

    /// Check if camera is available on this device
    private var isCameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    var body: some View {
        NavigationStack {
            Group {
                if projectStorage.projects.isEmpty {
                    EmptyProjectsView {
                        showingPhotoPicker = true
                    }
                } else {
                    projectListView
                }
            }
            .navigationTitle("Try Out")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !projectStorage.projects.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            if isCameraAvailable {
                                Button {
                                    handleCameraButtonTap()
                                } label: {
                                    Label("Take Photo", systemImage: "camera")
                                }
                            }

                            Button {
                                showingPhotoPicker = true
                            } label: {
                                Label("Choose from Library", systemImage: "photo.on.rectangle")
                            }
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .tint(.primary)
                    }
                }
            }
            .photosPicker(isPresented: $showingPhotoPicker, selection: $selectedItem, matching: .images)
            .fullScreenCover(isPresented: $showingCamera) {
                CameraPicker(isPresented: $showingCamera) { image in
                    handleCapturedImage(image)
                }
                .ignoresSafeArea()
            }
            .onChange(of: selectedItem) { oldValue, newValue in
                if let item = newValue {
                    loadImage(from: item)
                }
            }
            .navigationDestination(for: Project.self) { project in
                ProjectDetailView(projectId: project.id)
                    .environmentObject(projectStorage)
            }
            .alert("Rename Project", isPresented: $showingRenameAlert) {
                TextField("Project Name", text: $newProjectName)
                Button("Cancel", role: .cancel) {}
                Button("Save") {
                    if let project = projectToRename {
                        HapticManager.success()
                        projectStorage.renameProject(project, to: newProjectName)
                    }
                }
            }
            .permissionDeniedAlert(isPresented: $showingCameraPermissionAlert, for: .camera)
            .permissionDeniedAlert(isPresented: $showingPhotoLibraryPermissionAlert, for: .photoLibrary)
            .alert("Import Failed", isPresented: $showingImageLoadError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Unable to load the selected image. Please try again with a different photo.")
            }
            .overlay {
                if isLoading {
                    LoadingOverlay()
                }
            }
            .onAppear {
                permissionManager.updateStatuses()
            }
        }
    }

    // MARK: - Camera Button Handler
    private func handleCameraButtonTap() {
        if permissionManager.isCameraDenied {
            showingCameraPermissionAlert = true
        } else if permissionManager.cameraStatus == .notDetermined {
            permissionManager.requestCameraPermission { granted in
                if granted {
                    showingCamera = true
                } else {
                    showingCameraPermissionAlert = true
                }
            }
        } else {
            showingCamera = true
        }
    }

    // MARK: - Project List View
    private var projectListView: some View {
        ScrollView {
            LazyVStack(spacing: Theme.Spacing.sm) {
                ForEach(projectStorage.projects) { project in
                    NavigationLink(value: project) {
                        ProjectRow(project: project)
                    }
                    .buttonStyle(.plain)
                    .transition(.asymmetric(
                        insertion: .scale.combined(with: .opacity),
                        removal: .scale(scale: 0.8).combined(with: .opacity)
                    ))
                    .contextMenu {
                        Button {
                            projectToRename = project
                            newProjectName = project.name
                            showingRenameAlert = true
                        } label: {
                            Label("Rename", systemImage: "pencil")
                        }

                        Button(role: .destructive) {
                            HapticManager.heavyImpact()
                            withAnimation(Theme.Animation.smooth) {
                                projectStorage.deleteProject(project)
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            HapticManager.heavyImpact()
                            withAnimation(Theme.Animation.smooth) {
                                projectStorage.deleteProject(project)
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.bottom, Theme.Spacing.sm)
            .animation(Theme.Animation.smooth, value: projectStorage.projects.count)
        }
    }

    // MARK: - Load Image
    private func loadImage(from item: PhotosPickerItem) {
        isLoading = true

        Task {
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else {
                    await MainActor.run {
                        isLoading = false
                        selectedItem = nil
                        HapticManager.error()
                        showingImageLoadError = true
                    }
                    return
                }

                await MainActor.run {
                    // Compress the image for storage
                    if let uiImage = UIImage(data: data),
                       let compressedData = ImageProcessor.compressImage(uiImage, compressionQuality: 0.7) {
                        HapticManager.success()
                        let project = Project(originalImageData: compressedData)
                        projectStorage.addProject(project)
                    } else {
                        // Image creation or compression failed
                        HapticManager.error()
                        showingImageLoadError = true
                    }
                    isLoading = false
                    selectedItem = nil
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    selectedItem = nil
                    HapticManager.error()
                    showingImageLoadError = true
                }
                print("Failed to load image: \(error)")
            }
        }
    }

    // MARK: - Handle Captured Image
    private func handleCapturedImage(_ image: UIImage) {
        HapticManager.success()
        isLoading = true

        // Compress the image for storage
        if let compressedData = ImageProcessor.compressImage(image, compressionQuality: 0.7) {
            let project = Project(originalImageData: compressedData)
            projectStorage.addProject(project)
        }
        isLoading = false
    }
}

// MARK: - Loading Overlay
struct LoadingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: Theme.Spacing.md) {
                ProgressView()
                    .scaleEffect(1.2)
                    .tint(.white)

                Text("Importing...")
                    .font(Theme.Typography.subheadline)
                    .foregroundStyle(.white)
            }
            .padding(Theme.Spacing.lg)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
        }
    }
}

// MARK: - Camera Picker
/// A UIViewControllerRepresentable wrapper for UIImagePickerController to capture photos
struct CameraPicker: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let onImageCaptured: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        var parent: CameraPicker

        init(_ parent: CameraPicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            // Dismiss first, then process
            parent.isPresented = false

            // Capture the callback to avoid retain cycle
            let onImageCaptured = parent.onImageCaptured

            // Process image after a short delay to ensure dismissal completes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if let image = info[.originalImage] as? UIImage {
                    onImageCaptured(image)
                }
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.isPresented = false
        }
    }
}

// MARK: - Preview
#Preview {
    TryOutTabView()
        .environmentObject(ProjectStorage())
}
