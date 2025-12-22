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
    @Published var searchQuery: String = ""
    
    // Recording State
    @Published var currentTranscript: String = ""
    @Published var isRecording = false
    @Published var isPaused = false
    @Published var audioPower: Float = 0.0
    
    // Smart Checklist State
    @Published var activeQuestion: ChecklistItem?
    @Published var remainingQuestions: [ChecklistItem] = []
    @Published var isQuestionSatisfied: Bool = false // UI Trigger
    
    // Internal Engines
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    override init() {
        super.init()
        loadDreams()
        setupChecklist()
    }
    
    // MARK: - Filtering Logic
    var filteredDreams: [Dream] {
        var result = dreams
        
        if let tag = filterTag {
            result = result.filter { $0.keyEntities.contains(tag) }
        }
        
        if !searchQuery.isEmpty {
            result = result.filter {
                $0.rawTranscript.localizedCaseInsensitiveContains(searchQuery) ||
                $0.smartSummary.localizedCaseInsensitiveContains(searchQuery) ||
                $0.keyEntities.contains(where: { $0.localizedCaseInsensitiveContains(searchQuery) })
            }
        }
        
        return result
    }
    
    var allTags: [String] {
        Array(Set(dreams.flatMap { $0.keyEntities })).sorted()
    }
    
    // MARK: - Actions
    func selectTagFilter(_ tag: String) {
        filterTag = tag
        searchQuery = "" // Clear search when tagging
        selectedTab = 1 // Switch to Journal
        navigationPath = NavigationPath() // Reset stack to root
    }
    
    func clearFilter() {
        filterTag = nil
        searchQuery = ""
    }
    
    // MARK: - Recording
    func startRecording() {
        currentTranscript = ""
        setupChecklist()
        
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
            Task {
                let newDream = await createAndSaveDream()
                await MainActor.run {
                    selectedTab = 1
                    navigationPath = NavigationPath() // Clear stack first
                    navigationPath.append(newDream) // Push new dream
                }
            }
        }
    }
    
    func pauseRecording() {
        if isPaused { try? audioEngine.start() } else { audioEngine.pause() }
        withAnimation { isPaused.toggle() }
    }
    
    // MARK: - Checklist Logic
    private func analyzeChecklist() {
        guard let current = activeQuestion, !isQuestionSatisfied else { return }
        
        let lower = currentTranscript.lowercased()
        
        // Check if current question is satisfied
        for keyword in current.keywords {
            if lower.contains(keyword) {
                triggerSuccessAndAdvance()
                return
            }
        }
    }
    
    private func triggerSuccessAndAdvance() {
        withAnimation { isQuestionSatisfied = true }
        
        // Delay to show green state, then swap
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.advanceQuestion()
        }
    }
    
    private func advanceQuestion() {
        guard !remainingQuestions.isEmpty else {
            withAnimation { activeQuestion = nil }
            return
        }
        
        // Smart Selection: Find a question triggered by current text context
        let lower = currentTranscript.lowercased()
        var nextIndex = 0
        
        for (index, q) in remainingQuestions.enumerated() {
            for trigger in q.triggerKeywords {
                if lower.contains(trigger) {
                    nextIndex = index
                    break
                }
            }
        }
        
        withAnimation {
            isQuestionSatisfied = false
            activeQuestion = remainingQuestions.remove(at: nextIndex)
        }
    }
    
    private func setupChecklist() {
        // Pool of questions
        var pool = [
            ChecklistItem(question: "Who was there with you?", keywords: ["mom", "dad", "friend", "brother", "sister", "people", "someone", "dog", "cat", "nobody", "alone"], triggerKeywords: ["saw", "met", "with"]),
            ChecklistItem(question: "Where did it take place?", keywords: ["house", "home", "school", "work", "outside", "forest", "room", "sky", "beach", "space", "city"], triggerKeywords: ["went", "at", "in"]),
            ChecklistItem(question: "How did the environment feel?", keywords: ["day", "night", "dark", "bright", "cold", "hot", "rain", "fog", "clear"], triggerKeywords: ["outside", "sky", "weather"]),
            ChecklistItem(question: "Did you feel safe?", keywords: ["safe", "scared", "terrified", "anxious", "happy", "ok", "fine", "good"], triggerKeywords: ["felt", "scary", "weird"]),
            ChecklistItem(question: "What were you doing?", keywords: ["run", "walk", "fly", "still", "stuck", "froze", "swim", "drive", "eating", "talking"], triggerKeywords: ["then", "started"]),
            ChecklistItem(question: "Were there any distinct colors?", keywords: ["red", "blue", "green", "black", "white", "yellow", "purple", "dark", "neon"], triggerKeywords: ["looked", "saw"])
        ]
        
        activeQuestion = pool.removeFirst() // Start with "Who"
        remainingQuestions = pool
        isQuestionSatisfied = false
    }
    
    private func createAndSaveDream() async -> Dream {
        let sentiment = IntelligenceService.analyzeSentiment(text: currentTranscript)
        let allTags = self.allTags
        
        let entities = IntelligenceService.extractEntities(text: currentTranscript, existingTags: allTags)
        let people = IntelligenceService.extractPeople(from: currentTranscript)
        let places = IntelligenceService.extractPlaces(from: currentTranscript)
        let emotions = IntelligenceService.extractEmotions(from: currentTranscript)
        
        // Use new smart summary logic
        let summary = IntelligenceService.generateSmartSummary(from: currentTranscript, entities: entities, emotions: emotions)
        
        // Generate Image using Simulated API
        let imageHex = try? await ImageCreator.shared.generateImage(prompt: summary, style: .illustration)
        
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
            generatedImageHex: imageHex
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
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("dorsal_dreams_v4.json")
    }
}
