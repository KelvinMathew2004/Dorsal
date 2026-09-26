import Foundation
import ImagePlayground
import UIKit
import SwiftUI

actor ImageGenerationService {
    static let shared = ImageGenerationService()
    
    private(set) var isAvailable: Bool = false

    nonisolated static var supportsAutomaticGeneration: Bool {
        if #available(iOS 27, *) { return false }
        return true
    }
    
    init() {
        Task { await checkAvailability() }
    }
    
    func checkAvailability() async {
        // ImageCreator was discontinued in iOS 27; the detail view offers the system sheet.
        guard Self.supportsAutomaticGeneration else { isAvailable = false; return }
        do {
            _ = try await ImageCreator()
            isAvailable = true
        } catch {
            isAvailable = false
        }
    }
    
    func generate(prompt: String, places: [String] = [], emotions: [String] = [], profileImageData: Data? = nil) async throws -> Data {
        guard Self.supportsAutomaticGeneration else { throw DreamError.imageNotSupported }
        try Task.checkCancellation()
        do {
            return try await performGeneration(prompt: prompt, profileImageData: profileImageData)
        } catch {
            guard !Task.isCancelled, DreamFailure.shouldRetryImageWithSimplerPrompt(error) else { throw error }
            var fallbackPrompt = ""
            
            if !places.isEmpty {
                fallbackPrompt = places.joined(separator: ", ")
            } else if !emotions.isEmpty {
                fallbackPrompt = "An artistic illustration of " + emotions.joined(separator: ", ")
            }
            
            if !fallbackPrompt.isEmpty && fallbackPrompt != prompt {
                return try await performGeneration(prompt: fallbackPrompt, profileImageData: profileImageData)
            }
            
            throw error
        }
    }
    
    private func performGeneration(prompt: String, profileImageData: Data?) async throws -> Data {
        let creator = try await ImageCreator()
        
        guard !creator.availableStyles.isEmpty else { throw DreamError.imageUnavailable }
        let style: ImagePlaygroundStyle = creator.availableStyles.contains(.animation)
            ? .animation
            : (creator.availableStyles.first ?? .illustration)
        
        var concepts: [ImagePlaygroundConcept] = [.text(prompt)]
        if UserDefaults.standard.object(forKey: "imageIncludeMyself") as? Bool ?? true,
           let profileImageData,
           let profileImage = UIImage(data: profileImageData)?.cgImage {
            concepts.append(.image(profileImage))
            concepts.append(.text("Use the image as reference for the dreamer's appearance. It is not the dream setting."))
        }
        let stream = creator.images(for: concepts, style: style, limit: 1)
        
        for try await image in stream {
            if let uiImage = UIImage(cgImage: image.cgImage).pngData() {
                return uiImage
            }
        }
        
        throw DreamError.imageGenerationFailed
    }
}
