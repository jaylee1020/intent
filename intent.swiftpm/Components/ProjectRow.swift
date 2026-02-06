import SwiftUI

// MARK: - Project Row
/// A row component for displaying a project in the Try Out tab
struct ProjectRow: View {
    let project: Project

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    private var formattedDate: String {
        Self.dateFormatter.string(from: project.dateCreated)
    }
    
    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Thumbnail
            Group {
                if let image = project.originalImage {
                    Image(uiImage: image)
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
            .frame(width: 72, height: 72)
            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.small))
            
            // Project info
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(project.name)
                    .font(Theme.Typography.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                
                Text(formattedDate)
                    .font(Theme.Typography.subheadline)
                    .foregroundStyle(.secondary)
                
                // Frame count badge
                HStack(spacing: Theme.Spacing.xxs) {
                    Image(systemName: "square.on.square")
                        .font(.system(size: 12))
                    Text("\(project.frames.count) frame\(project.frames.count == 1 ? "" : "s")")
                        .font(Theme.Typography.caption)
                }
                .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Arrow
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(Theme.Spacing.sm)
        .background(Theme.Colors.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
    }
}

// MARK: - Empty Project State
/// Displayed when no projects exist
struct EmptyProjectsView: View {
    let onAddProject: () -> Void
    
    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Spacer()
            
            // Icon
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 44))
                    .foregroundStyle(Color.accentColor)
            }
            
            // Text
            VStack(spacing: Theme.Spacing.xs) {
                Text("No Projects Yet")
                    .font(Theme.Typography.title2)
                
                Text("Import a photo to start finding\nmultiple frames within a single image.")
                    .font(Theme.Typography.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Add button
            Button(action: onAddProject) {
                Label("Import Photo", systemImage: "plus.circle.fill")
                    .font(Theme.Typography.headline)
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.vertical, Theme.Spacing.sm)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            
            Spacer()
        }
        .padding(Theme.Spacing.xl)
    }
}

// MARK: - Preview
#Preview {
    VStack {
        // Preview with sample project
        ProjectRow(project: Project(
            name: "Urban Architecture",
            originalImageData: UIImage(systemName: "photo")?.pngData() ?? Data()
        ))
        .padding()
        
        Divider()
        
        EmptyProjectsView {
            print("Add project tapped")
        }
    }
}
