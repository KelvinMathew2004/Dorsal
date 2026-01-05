import SwiftUI
import Speech
import AVFoundation

@MainActor
class SpeechRecognizerManager: ObservableObject {
    @Published var transcript: String = ""
    @Published var isProcessing: Bool = false
    @Published var errorMessage: String?
    @Published var hasPermission: Bool = false
    
    // Permission status
    @Published var permissionStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    @Published var transcriptionResult: SFTranscription?
    
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    init() {
        // Lazy init
    }
    
    func transcribeAudioFile(url: URL, completion: @escaping (String) -> Void) {
        // Just-in-time authorization check
        let status = SFSpeechRecognizer.authorizationStatus()
        if status == .notDetermined {
            SFSpeechRecognizer.requestAuthorization { [weak self] authStatus in
                DispatchQueue.main.async {
                    if authStatus == .authorized {
                        self?.hasPermission = true
                        self?.performTranscription(url: url, completion: completion)
                    } else {
                        self?.errorMessage = "Speech recognition permission declined."
                        self?.isProcessing = false
                    }
                }
            }
            return
        } else if status == .denied || status == .restricted {
            self.errorMessage = "Speech recognition permission is required to analyze the file."
            self.isProcessing = false
            return
        }
        
        performTranscription(url: url, completion: completion)
    }
    
    private func performTranscription(url: URL, completion: @escaping (String) -> Void) {
        
        // Cancel previous task if any
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // Reset state
        self.transcript = ""
        self.transcriptionResult = nil
        self.isProcessing = true
        self.errorMessage = nil
        
        // Init Recognizer
        let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        self.speechRecognizer = recognizer
        
        guard let recognizer = recognizer, recognizer.isAvailable else {
            self.errorMessage = "Speech recognition not available."
            self.isProcessing = false
            return
        }
        
        // Create Request
        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = true
        
        // Start Task
        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }
            
            Task { @MainActor in
                if let result = result {
                    self.transcript = result.bestTranscription.formattedString
                    self.transcriptionResult = result.bestTranscription
                }
                
                if let error = error {
                    print("Transcription error: \(error)")
                    // Don't show error for cancellation
                    if (error as NSError).code != 216 { // 216 is cancellation
                         self.errorMessage = "Transcription failed: \(error.localizedDescription)"
                    }
                    self.isProcessing = false
                } else if result?.isFinal == true {
                    self.isProcessing = false
                    completion(result?.bestTranscription.formattedString ?? "")
                }
            }
        }
    }
    
    func cancelProcessing() {
        recognitionTask?.cancel()
        recognitionTask = nil
        isProcessing = false
    }
    
    func reset() {
        cancelProcessing()
        transcript = ""
        transcriptionResult = nil
        errorMessage = nil
        isProcessing = false
    }
}
