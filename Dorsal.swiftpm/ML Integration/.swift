//
//  DreamFilter.swift
//  Dorsal
//
//  Created by Kelvin Mathew on 12/24/25.
//


import SwiftUI
import Speech
import AVFoundation

// MARK: - Filter State
struct DreamFilter: Equatable {
    var tags: Set<String> = []
    var people: Set<String> = []
    var places: Set<String> = []
    var emotions: Set<String> = []
    
    var isEmpty: Bool {
        tags.isEmpty && people.isEmpty && places.isEmpty && emotions.isEmpty
    }
    
    mutating func clear() {
        tags.removeAll()
        people.removeAll()
        places.removeAll()
        emotions.removeAll()
    }
}

// MARK: - Audio Engine Manager (Thread-safe)
final class AudioEngineManager: @unchecked Sendable {
    static let shared = AudioEngineManager()
    private var engine: AVAudioEngine?
    private let lock = NSLock()
    private init() {}
    func createEngine() -> AVAudioEngine {
        lock.lock(); defer { lock.unlock() }
        destroyEngineUnsafe(); let new = AVAudioEngine(); engine = new; return new
    }
    func destroyEngine() {
        lock.lock(); defer { lock.unlock() }
        destroyEngineUnsafe()
    }
    private func destroyEngineUnsafe() {
        if let existing = engine { if existing.isRunning { existing.stop() }; existing.inputNode.removeTap(onBus: 0) }; engine = nil
    }
    func getEngine() -> AVAudioEngine? {
        lock.lock(); defer { lock.unlock() }; return engine
    }
}

@MainActor
class DreamStore: NSObject, ObservableObject {
    @Published var dreams: [Dream] = []
    @Published var insights: [TherapeuticInsight] = []
    
    // Navigation
    @Published var selectedTab: Int = 0
    @Published var navigationPath = NavigationPath()
    @Published var activeFilter = DreamFilter()
    @Published var searchQuery: String = ""
    
    // Recording
    @Published var currentTranscript: String = ""
    @Published var isRecording = false
    @Published var isPaused = false
    @Published var audioPower: Float = 0.0
    @Published var permissionError: String? = nil
    @Published var showPermissionAlert: Bool = false
    @Published var isProcessing: Bool = false
    
    // Checklist
    @Published var activeQuestion: ChecklistItem?
    @Published var remainingQuestions: [ChecklistItem] = []
    @Published var isQuestionSatisfied: Bool = false
    
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    // Mock
    private var mockTimer: Timer?
    private let useMockMode = true
    private var mockDreamIndex = 0
    
    private let audioQueue = DispatchQueue(label: "com.dorsal.audio", qos: .userInteractive)
    
    override init() {
        super.init()
        loadDreams()
        setupChecklist()
        Task { await refreshInsights() }
    }
    
    deinit { AudioEngineManager.shared.destroyEngine() }
    
    // MARK: - Filtering Logic (Restored)
    var filteredDreams: [Dream] {
        var result = dreams
        
        // 1. Apply Filters
        if !activeFilter.isEmpty {
            result = result.filter { dream in
                let matchesTags = activeFilter.tags.isEmpty || !activeFilter.tags.isDisjoint(with: dream.keyEntities)
                let matchesPeople = activeFilter.people.isEmpty || !activeFilter.people.isDisjoint(with: dream.people)
                let matchesPlaces = activeFilter.places.isEmpty || !activeFilter.places.isDisjoint(with: dream.places)
                let matchesEmotions = activeFilter.emotions.isEmpty || !activeFilter.emotions.isDisjoint(with: dream.emotions)
                
                return matchesTags && matchesPeople && matchesPlaces && matchesEmotions
            }
        }
        
        // 2. Apply Search
        if !searchQuery.isEmpty {
            result = result.filter {
                $0.rawTranscript.localizedCaseInsensitiveContains(searchQuery) ||
                $0.smartSummary.localizedCaseInsensitiveContains(searchQuery) ||
                $0.keyEntities.contains(where: { $0.localizedCaseInsensitiveContains(searchQuery) })
            }
        }
        
        return result
    }
    
    // Dynamic Filter Lists
    var allTags: [String] { Array(Set(dreams.flatMap { $0.keyEntities })).sorted() }
    var allPeople: [String] { Array(Set(dreams.flatMap { $0.people })).sorted() }
    var allPlaces: [String] { Array(Set(dreams.flatMap { $0.places })).sorted() }
    var allEmotions: [String] { Array(Set(dreams.flatMap { $0.emotions })).sorted() }
    
    // MARK: - Actions
    func toggleTagFilter(_ tag: String) { if activeFilter.tags.contains(tag) { activeFilter.tags.remove(tag) } else { activeFilter.tags.insert(tag) } }
    func togglePersonFilter(_ person: String) { if activeFilter.people.contains(person) { activeFilter.people.remove(person) } else { activeFilter.people.insert(person) } }
    func togglePlaceFilter(_ place: String) { if activeFilter.places.contains(place) { activeFilter.places.remove(place) } else { activeFilter.places.insert(place) } }
    func toggleEmotionFilter(_ emotion: String) { if activeFilter.emotions.contains(emotion) { activeFilter.emotions.remove(emotion) } else { activeFilter.emotions.insert(emotion) } }
    
    func jumpToFilter(type: String, value: String) {
        activeFilter.clear()
        switch type {
        case "person": activeFilter.people.insert(value)
        case "place": activeFilter.places.insert(value)
        case "emotion": activeFilter.emotions.insert(value)
        case "tag": activeFilter.tags.insert(value)
        default: break
        }
        selectedTab = 1
        navigationPath = NavigationPath()
    }

    func clearFilter() { activeFilter.clear(); searchQuery = "" }
    
    // MARK: - Data Management
    func deleteDream(_ dream: Dream) {
        if let index = dreams.firstIndex(where: { $0.id == dream.id }) {
            dreams.remove(at: index)
            saveDreamsToDisk()
            Task { await refreshInsights() }
        }
    }
    
    // MARK: - Insight Generation
    func refreshInsights() async {
        guard !dreams.isEmpty else { return }
        do {
            let newInsights = try await DreamAnalyzer.shared.generateInsights(recentDreams: dreams)
            await MainActor.run {
                withAnimation { self.insights = newInsights }
            }
        } catch {
            print("Insight generation failed: \(error)")
        }
    }
    
    // MARK: - Recording Logic
    func startRecording() {
        guard !isRecording else { return }
        if useMockMode { startMockRecording(); return }
        // (Real recording implementation would go here if not in mock mode)
    }
    
    private func startMockRecording() {
        print("[DreamStore] 🎭 Starting MOCK recording")
        currentTranscript = ""
        setupChecklist()
        withAnimation { isRecording = true; isPaused = false }
        
        // Mock sequences that trigger analysis
        let mockSequences = [
            [
                "I was swimming. Deep underwater.",
                "No scuba gear, just... breathing water. It felt natural.",
                "At first. Then I looked down and there was no bottom.",
                "Just infinite blue darkness. Miles of it.",
                "And I looked up and the surface was... a tiny speck of light.",
                "I realized I was... sinking? No, being pulled.",
                "Something heavy was tied to my ankle. An anchor?",
                "No... it was a clock. A grandfather clock.",
                "Ticking underwater. Tick. Tock. Loud.",
                "I tried to untie it but my fingers were numb.",
                "I wasn't scared though. I just felt... heavy. So heavy.",
                "I just felt like I wanted to sleep down there."
            ],
             [
                "Um, okay, so... I was back in high school?",
                "But it wasn't school, it was also my office. Weird.",
                "And I had to give this presentation about... I think it was about water safety? Ironically.",
                "And, uh, I looked down and my notes were just... soaking wet.",
                "Like, dripping onto the floor. Ruined.",
                "I tried to speak but my... my teeth felt loose.",
                "Yeah, wobbly. I spit one out into my hand...",
                "and it was... it was a seashell? A tiny white seashell.",
                "And everyone just stared at me. No one said a word.",
                "Ah, I felt so small. Just... disappearing into the floor."
            ]
        ]
        
        let phrases = mockSequences[mockDreamIndex % mockSequences.count]
        mockDreamIndex += 1
        var phraseIndex = 0
        
        mockTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                if phraseIndex < phrases.count {
                    let chunk = phrases[phraseIndex]
                    self.currentTranscript += (self.currentTranscript.isEmpty ? "" : " ") + chunk
                    self.audioPower = Float.random(in: 0.3...0.9)
                    self.analyzeChecklist()
                    phraseIndex += 1
                } else {
                    self.audioPower = 0.05
                    self.mockTimer?.invalidate()
                    self.mockTimer = nil
                }
            }
        }
    }
    
    func stopRecording(save: Bool) {
        if useMockMode { mockTimer?.invalidate(); mockTimer = nil; audioPower = 0 }
        else { AudioEngineManager.shared.destroyEngine(); recognitionTask?.cancel() }
        
        withAnimation { isRecording = false; isPaused = false }
        
        if save && !currentTranscript.isEmpty {
            Task {
                await MainActor.run { self.isProcessing = true }
                
                // --- INTEGRATION POINT: Foundation Models ---
                let newDream = await createAndSaveDream()
                
                await refreshInsights()
                await MainActor.run {
                    self.isProcessing = false
                    selectedTab = 1
                    navigationPath = NavigationPath()
                    navigationPath.append(newDream)
                }
            }
        }
    }
    
    func pauseRecording() {
         withAnimation { isPaused.toggle() }
    }
    
    // MARK: - Checklist Logic
    private func analyzeChecklist() {
        guard let current = activeQuestion, !isQuestionSatisfied else { return }
        let lower = currentTranscript.lowercased()
        for keyword in current.keywords { if lower.contains(keyword) { triggerSuccessAndAdvance(); return } }
    }
    
    private func triggerSuccessAndAdvance() {
        withAnimation { isQuestionSatisfied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { self.advanceQuestion() }
    }
    
    private func advanceQuestion() {
        guard !remainingQuestions.isEmpty else { withAnimation { activeQuestion = nil }; return }
        let lower = currentTranscript.lowercased()
        var nextIndex = 0
        for (index, q) in remainingQuestions.enumerated() {
            for trigger in q.triggerKeywords { if lower.contains(trigger) { nextIndex = index; break } }
        }
        withAnimation { isQuestionSatisfied = false; activeQuestion = remainingQuestions.remove(at: nextIndex) }
    }
    
    private func setupChecklist() {
        var pool = [
            ChecklistItem(question: "Who was there with you?", keywords: ["mom", "dad", "friend", "brother", "sister", "people", "someone", "dog", "cat", "nobody", "alone"], triggerKeywords: ["saw", "met", "with"]),
            ChecklistItem(question: "Where did it take place?", keywords: ["house", "home", "school", "work", "outside", "forest", "room", "sky", "beach", "space", "city"], triggerKeywords: ["went", "at", "in"]),
            ChecklistItem(question: "How did the environment feel?", keywords: ["day", "night", "dark", "bright", "cold", "hot", "rain", "fog", "clear"], triggerKeywords: ["outside", "sky", "weather"]),
            ChecklistItem(question: "Did you feel safe?", keywords: ["safe", "scared", "terrified", "anxious", "happy", "ok", "fine", "good"], triggerKeywords: ["felt", "scary", "weird"]),
            ChecklistItem(question: "What were you doing?", keywords: ["run", "walk", "fly", "still", "stuck", "froze", "swim", "drive", "eating", "talking"], triggerKeywords: ["then", "started"]),
            ChecklistItem(question: "Were there any distinct colors?", keywords: ["red", "blue", "green", "black", "white", "yellow", "purple", "dark", "neon"], triggerKeywords: ["looked", "saw"])
        ]
        activeQuestion = pool.removeFirst()
        remainingQuestions = pool
        isQuestionSatisfied = false
    }

    // MARK: - AI GENERATION PIPELINE
    private func createAndSaveDream() async -> Dream {
        let text = currentTranscript
        
        // 1. Foundation Models: Deep Analysis
        let analysis = try! await DreamAnalyzer.shared.analyze(transcript: text)
        
        // 2. Foundation Models: Image Prompt Generation
        let artPrompt = try! await DreamAnalyzer.shared.generateArtPrompt(transcript: text)
        
        // 3. Image Creation: Use the LLM prompt to generate the asset
        let (imageData, imageHex) = try! await ImageCreator.shared.generateImage(llmPrompt: artPrompt, style: .illustration)
        
        // 4. Basic Entity Extraction (Restored from IntelligenceService)
        // We still use this legacy service for the "tags" functionality until we fully migrate tags to LLM
        let entities = IntelligenceService.extractEntities(text: text, existingTags: self.allTags)
        let people = IntelligenceService.extractPeople(from: text)
        let places = IntelligenceService.extractPlaces(from: text)
        let emotions = IntelligenceService.extractEmotions(from: text)
        
        let newDream = Dream(
            id: UUID(),
            date: Date(),
            rawTranscript: text,
            smartSummary: analysis.summary,
            interpretation: analysis.interpretation,
            actionableAdvice: analysis.actionableAdvice,
            emotion: analysis.emotion,
            tone: analysis.tone,
            sentimentScore: 0.5, // Placeholder, could be derived
            voiceFatigue: Double.random(in: 0.1...0.9),
            keyEntities: entities,
            people: people,
            places: places,
            emotions: emotions, // Merge extracted emotions
            generatedImageHex: imageHex,
            generatedImageData: imageData
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
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("dorsal_dreams_v5.json")
    }
}