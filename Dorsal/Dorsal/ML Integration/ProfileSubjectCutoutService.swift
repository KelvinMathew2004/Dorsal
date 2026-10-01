import CoreImage
import Foundation
import UIKit
import Vision

/// Produces a transparent PNG containing the people from a profile photo.
actor ProfileSubjectCutoutService {
    static let shared = ProfileSubjectCutoutService()

    func cutout(from imageData: Data) -> Data? {
        do {
            let request = VNGeneratePersonInstanceMaskRequest()
            let handler = VNImageRequestHandler(data: imageData, options: [:])
            try handler.perform([request])

            guard let observation = request.results?.first,
                  !observation.allInstances.isEmpty else { return nil }

            let maskedBuffer = try observation.generateMaskedImage(
                ofInstances: observation.allInstances,
                from: handler,
                croppedToInstancesExtent: true
            )
            let image = CIImage(cvPixelBuffer: maskedBuffer)
            guard let cgImage = CIContext().createCGImage(image, from: image.extent) else { return nil }
            return UIImage(cgImage: cgImage).pngData()
        } catch {
            return nil
        }
    }
}
