import Foundation
import FoundationModels
import ImagePlayground

nonisolated enum AnalysisAvailability: Equatable {
    case available, notReady, disabled, unsupported, unknown

    init(_ availability: SystemLanguageModel.Availability) {
        switch availability {
        case .available: self = .available
        case .unavailable(.modelNotReady): self = .notReady
        case .unavailable(.appleIntelligenceNotEnabled): self = .disabled
        case .unavailable(.deviceNotEligible): self = .unsupported
        default: self = .unknown
        }
    }

    var message: String? {
        switch self {
        case .available: return nil
        case .notReady: return "Apple Intelligence isn’t ready yet. You can still record and save your dream, then retry analysis later."
        case .disabled: return "Turn on Apple Intelligence in Settings to analyze dreams. Recording and saving are still available."
        case .unsupported: return "Apple Intelligence isn’t supported on this device. You can still record and save your dreams."
        case .unknown: return "Dream analysis is temporarily unavailable. You can still record and save your dreams."
        }
    }
}

nonisolated enum DreamFailure {
    static func analysisMessage(for error: Error) -> String {
        if let error = error as? DreamError { return error.localizedDescription }
        if #available(iOS 27, *) {
            if error is SystemLanguageModel.Error { return DreamError.modelUnavailable.localizedDescription }
            if let error = error as? LanguageModelSession.Error, error == .concurrentRequests {
                return DreamError.systemBusy.localizedDescription
            }
            if let error = error as? LanguageModelError {
                switch error {
                case .contextSizeExceeded: return DreamError.tooLong.localizedDescription
                case .rateLimited: return DreamError.systemBusy.localizedDescription
                case .unsupportedLanguageOrLocale: return DreamError.unsupportedLanguage.localizedDescription
                case .guardrailViolation, .refusal:
                    return "Apple Intelligence couldn’t analyze this content. Your original dream is still available."
                default: return "Analysis couldn’t finish. Your dream is still available. Please try again."
                }
            }
        }
        guard let error = error as? LanguageModelSession.GenerationError else {
            return "Analysis couldn’t finish. Your dream is still available. Please try again."
        }
        switch error {
        case .assetsUnavailable:
            return DreamError.modelUnavailable.localizedDescription
        case .guardrailViolation, .refusal:
            return "Apple Intelligence couldn’t analyze this content. Your original dream is still available."
        case .exceededContextWindowSize:
            return DreamError.tooLong.localizedDescription
        case .unsupportedLanguageOrLocale:
            return DreamError.unsupportedLanguage.localizedDescription
        case .rateLimited, .concurrentRequests:
            return DreamError.systemBusy.localizedDescription
        case .decodingFailure, .unsupportedGuide:
            return "Analysis couldn’t finish. Your original dream is still available. Please try again."
        @unknown default:
            return "Analysis is temporarily unavailable. Your original dream is still available. Please try again."
        }
    }

    static func imageMessage(for error: Error) -> String {
        guard let error = error as? ImageCreator.Error else {
            return "The illustration couldn’t be created. Your dream and analysis are still available."
        }
        switch error {
        case .notSupported: return "Automatic illustrations aren’t supported on this device."
        case .unavailable: return "Illustrations are temporarily unavailable. Please try again later."
        case .backgroundCreationForbidden: return "Keep Dorsal open to create an illustration, then try again."
        case .unsupportedLanguage: return "Image creation doesn’t support this language."
        case .conceptsRequirePersonIdentity: return "This illustration needs a person selected in Image Playground."
        default: return "The illustration couldn’t be created. Your dream and analysis are still available."
        }
    }

    static func shouldRetryImageWithSimplerPrompt(_ error: Error) -> Bool {
        guard let error = error as? ImageCreator.Error else { return false }
        return error == .creationFailed || error == .conceptsRequirePersonIdentity
    }

    static func isCancellation(_ error: Error) -> Bool {
        error is CancellationError || (error as? ImageCreator.Error) == .creationCancelled
    }
}

// Kept separate from UI publishing so finishing a recording uses the actual final text,
// rather than a Combine delivery that may still be queued on the main run loop.
nonisolated struct TranscriptAccumulator {
    private(set) var finalized = ""
    private(set) var text = ""

    mutating func append(_ passage: String, isFinal: Bool) {
        let combined = finalized + (finalized.isEmpty ? "" : " ") + passage
        if isFinal { finalized = combined }
        text = combined
    }
}

enum RecordingFiles {
    static var directory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Recordings", isDirectory: true)
    }

    static func makeURL() throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent(UUID().uuidString).appendingPathExtension("caf")
    }

    static func url(for fileName: String?) -> URL? {
        guard let fileName, fileName == URL(fileURLWithPath: fileName).lastPathComponent else { return nil }
        let url = directory.appendingPathComponent(fileName)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
}
