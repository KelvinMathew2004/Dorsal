import Foundation
import ImagePlayground
import UIKit
import SwiftUI

actor ImageGenerationService {
    static let shared = ImageGenerationService()
    
    private(set) var isAvailable: Bool = false
    
    init() {
        Task { await checkAvailability() }
    }
    
    func checkAvailability() async {
        do {
            _ = try await ImageCreator()
            isAvailable = true
        } catch {
            isAvailable = false
        }
    }
    
    func generate(prompt: String, places: [String] = [], emotions: [String] = []) async throws -> Data {
        if !isAvailable {
            await checkAvailability()
            guard isAvailable else { throw DreamError.imageUnavailable }
        }
        
        do {
            return try await performGeneration(prompt: prompt)
        } catch {
            var fallbackPrompt = ""
            
            if !places.isEmpty {
                fallbackPrompt = places.joined(separator: ", ")
            } else if !emotions.isEmpty {
                fallbackPrompt = "An artistic illustration of " + emotions.joined(separator: ", ")
            }
            
            if !fallbackPrompt.isEmpty && fallbackPrompt != prompt {
                return try await performGeneration(prompt: fallbackPrompt)
            }
            
            throw error
        }
    }
    
    private func performGeneration(prompt: String) async throws -> Data {
        let creator = try await ImageCreator()
        
        let style: ImagePlaygroundStyle = creator.availableStyles.contains(.animation)
            ? .animation
            : (creator.availableStyles.first ?? .illustration)
        
        let stream = creator.images(for: [.text(prompt)], style: style, limit: 1)
        
        for try await image in stream {
            if let uiImage = UIImage(cgImage: image.cgImage).pngData() {
                return uiImage
            }
        }
        
        throw DreamError.imageGenerationFailed
    }
}
