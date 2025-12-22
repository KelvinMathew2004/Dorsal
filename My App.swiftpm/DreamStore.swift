import SwiftUI
import Speech
import AVFoundation

@MainActor
class DreamStore: NSObject, ObservableObject, SFSpeechRecognizerDelegate {
    @Published var dreams: [Dream] = []
    
    // Navigation & Filtering
    @Published var selectedTab: Int = 0
    @Published var navigationPath = NavigationPath()
    @Published var filterTag: String? = nil
    
    // Recording State
    @Published var currentTranscript: String = ""
    @Published var isRecording = false
    @Published var isPaused = false
    @Published var audioPower: Float = 0.0
    
    // Smart Checklist State
    @Published var checklist: [ChecklistItem] = []
    @Published var currentQuestionIndex: Int = 0
    
    // Internal Engines
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    override init() {
        super.init()
        loadDreams()
        resetChecklist()
    }
    
    var activeQuestion: ChecklistItem? {
        if currentQuestionIndex < checklist.count {
            return checklist[currentQuestionIndex]
        }
        return nil
    }
    
    var filteredDreams: [Dream] {
        if let tag = filterTag {
            return dreams.filter { $0.keyEntities.contains(tag) }
        }
        return dreams
    }
    
    var allTags: [String] {
        Array(Set(dreams.flatMap { $0.keyEntities })).sorted()
    }
    
    // MARK: - Actions
    func selectTagFilter(_ tag: String) {
        filterTag = tag
        selectedTab = 1 // Switch to Journal
    }
    
    func clearFilter() {
        filterTag = nil
    }
    
    // MARK: - Recording Logic
    func startRecording() {
        currentTranscript = ""
        resetChecklist()
        
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try? audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { return }
        recognitionRequest.shouldReportPartialResults = true
        
        let inputNode = audioEngine.inputNode
        
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { result, error in
            if let result = result {
                DispatchQueue.main.async {
                    self.currentTranscript = result.bestTranscription.formattedString
                    self.analyzeChecklist()
                }
            }
        }
        
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            self.recognitionRequest?.append(buffer)
            let channelData = buffer.floatChannelData?[0]
            let channelDataValue = Array(UnsafeBufferPointer(start: channelData, count: Int(buffer.frameLength)))
            let avgPower = channelDataValue.map { $0 * $0 }.reduce(0, +) / Float(buffer.frameLength)
            DispatchQueue.main.async { self.audioPower = avgPower }
        }
        
        audioEngine.prepare()
        try? audioEngine.start()
        withAnimation { isRecording = true; isPaused = false }
    }
    
    func stopRecording(save: Bool) {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        
        withAnimation { isRecording = false; isPaused = false }
        
        if save {
            let newDream = createAndSaveDream()
            selectedTab = 1
            navigationPath.append(newDream)
        }
    }
    
    func pauseRecording() {
        if isPaused { try? audioEngine.start() } else { audioEngine.pause() }
        withAnimation { isPaused.toggle() }
    }
    
    // MARK: - Checklist Logic
    private func analyzeChecklist() {
        let lower = currentTranscript.lowercased()
        if currentQuestionIndex < checklist.count {
            let currentItem = checklist[currentQuestionIndex]
            for keyword in currentItem.keywords {
                if lower.contains(keyword) {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                        checklist[currentQuestionIndex].isSatisfied = true
                        currentQuestionIndex += 1
                    }
                    break
                }
            }
        }
    }
    
    private func resetChecklist() {
        currentQuestionIndex = 0
        checklist = [
            ChecklistItem(question: "Where did the dream take place?", keywords: ["house", "home", "school", "work", "outside", "forest", "room", "sky", "beach", "space", "city"]),
            ChecklistItem(question: "Who was with you?", keywords: ["mom", "dad", "friend", "brother", "sister", "people", "someone", "dog", "cat", "nobody", "alone"]),
            ChecklistItem(question: "Was it day or night?", keywords: ["day", "night", "sun", "moon", "dark", "bright", "light", "morning"]),
            ChecklistItem(question: "Did you feel safe?", keywords: ["safe", "scared", "terrified", "anxious", "happy", "ok", "fine", "good"]),
            ChecklistItem(question: "Were you moving or still?", keywords: ["run", "walk", "fly", "still", "stuck", "froze", "swim", "drive"]),
            ChecklistItem(question: "What colors stood out?", keywords: ["red", "blue", "green", "black", "white", "yellow", "purple", "dark", "neon"])
        ]
    }
    
    private func createAndSaveDream() -> Dream {
        let sentiment = IntelligenceService.analyzeSentiment(text: currentTranscript)
        let entities = IntelligenceService.extractEntities(text: currentTranscript, existingTags: allTags)
        let summary = IntelligenceService.generateSmartSummary(from: currentTranscript)
        
        // NEW: Extract specific categories
        let people = IntelligenceService.extractPeople(from: currentTranscript)
        let places = IntelligenceService.extractPlaces(from: currentTranscript)
        let emotions = IntelligenceService.extractEmotions(from: currentTranscript)
        
        let newDream = Dream(
            id: UUID(),
            date: Date(),
            rawTranscript: currentTranscript,
            smartSummary: summary,
            sentimentScore: sentiment,
            voiceFatigue: Double.random(in: 0.1...0.9),
            keyEntities: entities,
            people: people,
            places: places,
            emotions: emotions,
            artSeed: Int.random(in: 0...1000),
            dominantColorHex: sentiment < 0 ? "#1A103C" : "#2A9D8F"
        )
        
        dreams.insert(newDream, at: 0)
        saveDreamsToDisk()
        return newDream
    }
    
    private func loadDreams() {
        guard let data = try? Data(contentsOf: dreamsURL),
              let decoded = try? JSONDecoder().decode([Dream].self, from: data) else { return }
        dreams = decoded
    }
    
    private func saveDreamsToDisk() {
        if let data = try? JSONEncoder().encode(dreams) {
            try? data.write(to: dreamsURL)
        }
    }
    
    private var dreamsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("dorsal_dreams_v3.json")
    }
}
