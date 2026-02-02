import SwiftUI
import Foundation

// MARK: - Aspect Ratio
/// Available aspect ratios for cropping
enum AspectRatio: String, CaseIterable, Codable, Identifiable {
    case free = "Free"
    case fourThree = "4:3"
    case sixteenNine = "16:9"
    case oneOne = "1:1"
    case threeTwo = "3:2"
    
    var id: String { rawValue }
    
    /// Returns the aspect ratio as a CGFloat (width/height)
    var ratio: CGFloat? {
        switch self {
        case .free: return nil
        case .fourThree: return 4.0 / 3.0
        case .sixteenNine: return 16.0 / 9.0
        case .oneOne: return 1.0
        case .threeTwo: return 3.0 / 2.0
        }
    }
    
    /// Description for UI display
    var description: String {
        switch self {
        case .free: return "Free"
        case .fourThree: return "4:3 (Default)"
        case .sixteenNine: return "16:9 (Cinematic)"
        case .oneOne: return "1:1 (Square)"
        case .threeTwo: return "3:2 (Classic)"
        }
    }
}

// MARK: - Frame Model
/// Represents a cropped region of an original photo
struct Frame: Identifiable, Codable {
    var id: UUID = UUID()
    var dateCreated: Date
    
    /// Crop region as percentages (0.0 to 1.0) of original image
    var cropRect: CropRect
    
    /// The aspect ratio used for this crop
    var aspectRatio: AspectRatio
    
    init(cropRect: CropRect, aspectRatio: AspectRatio = .free) {
        self.dateCreated = Date()
        self.cropRect = cropRect
        self.aspectRatio = aspectRatio
    }
}

// MARK: - Crop Rectangle
/// Stores crop region as percentages for resolution independence
struct CropRect: Codable {
    var x: CGFloat      // 0.0 to 1.0 - left edge position
    var y: CGFloat      // 0.0 to 1.0 - top edge position
    var width: CGFloat  // 0.0 to 1.0 - width as percentage
    var height: CGFloat // 0.0 to 1.0 - height as percentage
    
    init(x: CGFloat = 0.1, y: CGFloat = 0.1, width: CGFloat = 0.8, height: CGFloat = 0.8) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
    
    /// Convert to CGRect for a given image size
    func toCGRect(for imageSize: CGSize) -> CGRect {
        CGRect(
            x: x * imageSize.width,
            y: y * imageSize.height,
            width: width * imageSize.width,
            height: height * imageSize.height
        )
    }
    
    /// Create from CGRect and image size
    static func from(rect: CGRect, imageSize: CGSize) -> CropRect {
        // Guard against division by zero
        guard imageSize.width > 0, imageSize.height > 0 else {
            return CropRect()
        }

        return CropRect(
            x: rect.origin.x / imageSize.width,
            y: rect.origin.y / imageSize.height,
            width: rect.width / imageSize.width,
            height: rect.height / imageSize.height
        )
    }
}
