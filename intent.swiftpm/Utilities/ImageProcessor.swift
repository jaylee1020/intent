import SwiftUI
import UIKit
import Photos

// MARK: - Image Processing Utilities
struct ImageProcessor {
    
    /// Crops an image based on a CropRect (percentage-based region)
    static func cropImage(_ image: UIImage, with cropRect: CropRect) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        
        let imageSize = CGSize(width: cgImage.width, height: cgImage.height)
        let cropCGRect = cropRect.toCGRect(for: imageSize)
        
        // Ensure crop rect is within bounds
        let validRect = cropCGRect.intersection(CGRect(origin: .zero, size: imageSize))
        
        guard !validRect.isEmpty,
              let croppedCGImage = cgImage.cropping(to: validRect) else {
            return nil
        }
        
        return UIImage(cgImage: croppedCGImage, scale: image.scale, orientation: image.imageOrientation)
    }
    
    /// Saves an image to the user's photo library
    /// - Parameters:
    ///   - image: The image to save
    ///   - completion: Callback with (success, error, isDenied) - isDenied indicates if permission was denied
    static func saveToPhotoLibrary(_ image: UIImage, completion: @escaping (Bool, Error?, Bool) -> Void) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                let isDenied = (status == .denied || status == .restricted)
                DispatchQueue.main.async {
                    completion(false, NSError(domain: "ImageProcessor", code: 1, userInfo: [NSLocalizedDescriptionKey: "Photo library access denied"]), isDenied)
                }
                return
            }

            PHPhotoLibrary.shared().performChanges {
                PHAssetCreationRequest.creationRequestForAsset(from: image)
            } completionHandler: { success, error in
                DispatchQueue.main.async {
                    completion(success, error, false)
                }
            }
        }
    }
    
    /// Compresses image data for storage
    static func compressImage(_ image: UIImage, targetSize: CGSize? = nil, compressionQuality: CGFloat = 0.8) -> Data? {
        var imageToCompress = image
        
        if let targetSize = targetSize {
            imageToCompress = resizeImage(image, to: targetSize) ?? image
        }
        
        return imageToCompress.jpegData(compressionQuality: compressionQuality)
    }
    
    /// Resizes an image to fit within a target size while maintaining aspect ratio
    static func resizeImage(_ image: UIImage, to targetSize: CGSize) -> UIImage? {
        guard image.size.width > 0, image.size.height > 0 else { return nil }
        let widthRatio = targetSize.width / image.size.width
        let heightRatio = targetSize.height / image.size.height
        let ratio = min(widthRatio, heightRatio)
        
        let newSize = CGSize(
            width: image.size.width * ratio,
            height: image.size.height * ratio
        )
        
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
    
    /// Generates a thumbnail from an image
    static func generateThumbnail(_ image: UIImage, size: CGFloat = 200) -> UIImage? {
        guard image.size.width > 0, image.size.height > 0 else { return nil }
        let targetSize = CGSize(width: size, height: size)

        let widthRatio = targetSize.width / image.size.width
        let heightRatio = targetSize.height / image.size.height
        let ratio = max(widthRatio, heightRatio)
        
        let newSize = CGSize(
            width: image.size.width * ratio,
            height: image.size.height * ratio
        )
        
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            let origin = CGPoint(
                x: (targetSize.width - newSize.width) / 2,
                y: (targetSize.height - newSize.height) / 2
            )
            image.draw(in: CGRect(origin: origin, size: newSize))
        }
    }
}

// MARK: - UIImage Extension
extension UIImage {
    /// Returns the image with proper orientation applied
    var properlyOriented: UIImage {
        if imageOrientation == .up { return self }

        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
