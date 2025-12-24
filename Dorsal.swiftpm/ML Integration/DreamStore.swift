import SwiftUI
import Speech
import AVFoundation

struct DreamFilter: Equatable {
    var tags: Set<String> = []
    var people: Set<String> = []
    var places: Set<String> = []
    var emotions: Set<String> = []
    var isEmpty: Bool { tags.isEmpty && people.isEmpty && places.isEmpty && emotions.isEmpty }
    mutating func clear() { tags.removeAll(); people.removeAll(); places.removeAll(); emotions.removeAll() }
}

final class AudioEngineManager: @unchecked Sendable {
    static let shared = AudioEngineManager()
    private var engine: AVAudioEngine?
    private let lock = NSLock()
    private init() {}
    func createEngine() -> AVAudioEngine { lock.lock(); defer { lock.unlock() }; destroyEngineUnsafe(); let new = AVAudioEngine(); engine = new; return new }
    func destroyEngine() { lock.lock(); defer { lock.unlock() }; destroyEngineUnsafe() }
    private func destroyEngineUnsafe() { if let existing = engine { if existing.isRunning { existing.stop() }; existing.inputNode.removeTap(onBus: 0) }; engine = nil }
    func getEngine() -> AVAudioEngine? { lock.lock(); defer { lock.unlock() }; return engine }
}

@MainActor
class DreamStore: ObservableObject {
    @Published var dreams: [Dream] = []
    @Published var insights: [TherapeuticInsight] = []
    @Published var selectedTab: Int = 0
    @Published var navigationPath = NavigationPath()
    @Published var activeFilter = DreamFilter()
    @Published var searchQuery: String = ""
    @Published var currentTranscript: String = ""
    @Published var isRecording = false
    @Published var isPaused = false
    @Published var audioPower: Float = 0.0
    @Published var permissionError: String? = nil
    @Published var showPermissionAlert: Bool = false
    @Published var isProcessing: Bool = false
    @Published var activeQuestion: ChecklistItem?
    @Published var remainingQuestions: [ChecklistItem] = []
    @Published var isQuestionSatisfied: Bool = false
    
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var mockTimer: Timer?
    private let useMockMode = true
    private var mockDreamIndex = 0
    
    init() {
        loadDreams()
        setupChecklist()
        Task { await refreshInsights() }
    }
    
    func openSettings() { if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) } }
    
    var filteredDreams: [Dream] {
        var result = dreams
        if !activeFilter.isEmpty {
            result = result.filter { dream in
                let matchesTags = activeFilter.tags.isEmpty || !activeFilter.tags.isDisjoint(with: dream.keyEntities)
                let matchesPeople = activeFilter.people.isEmpty || !activeFilter.people.isDisjoint(with: dream.people)
                let matchesPlaces = activeFilter.places.isEmpty || !activeFilter.places.isDisjoint(with: dream.places)
                let matchesEmotions = activeFilter.emotions.isEmpty || !activeFilter.emotions.isDisjoint(with: dream.emotions)
                return matchesTags && matchesPeople && matchesPlaces && matchesEmotions
            }
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
    
    var allTags: [String] { Array(Set(dreams.flatMap { $0.keyEntities })).sorted() }
    var allPeople: [String] { Array(Set(dreams.flatMap { $0.people })).sorted() }
    var allPlaces: [String] { Array(Set(dreams.flatMap { $0.places })).sorted() }
    var allEmotions: [String] { Array(Set(dreams.flatMap { $0.emotions })).sorted() }
    
    func toggleTagFilter(_ tag: String) { if activeFilter.tags.contains(tag) { activeFilter.tags.remove(tag) } else { activeFilter.tags.insert(tag) } }
    func togglePersonFilter(_ person: String) { if activeFilter.people.contains(person) { activeFilter.people.remove(person) } else { activeFilter.people.insert(person) } }
    func togglePlaceFilter(_ place: String) { if activeFilter.places.contains(place) { activeFilter.places.remove(place) } else { activeFilter.places.insert(place) } }
    func toggleEmotionFilter(_ emotion: String) { if activeFilter.emotions.contains(emotion) { activeFilter.emotions.remove(emotion) } else { activeFilter.emotions.insert(emotion) } }
    
    func jumpToFilter(type: String, value: String) {
        activeFilter.clear()
        switch type {
        case "person": activeFilter.people.insert(value); case "place": activeFilter.places.insert(value); case "emotion": activeFilter.emotions.insert(value); case "tag": activeFilter.tags.insert(value); default: break
        }
        selectedTab = 1; navigationPath = NavigationPath()
    }
    
    func clearFilter() { activeFilter.clear(); searchQuery = "" }
    
    func deleteDream(_ dream: Dream) {
        if let index = dreams.firstIndex(where: { $0.id == dream.id }) {
            dreams.remove(at: index)
            saveDreamsToDisk()
            Task { await refreshInsights() }
        }
    }
    
    func refreshInsights() async {
        guard !dreams.isEmpty else { return }
        do {
            let newInsights = try await DreamAnalyzer.shared.generateInsights(recentDreams: dreams)
            await MainActor.run { withAnimation { self.insights = newInsights } }
        } catch { print("Insight generation failed: \(error)") }
    }
    
    func startRecording() { guard !isRecording else { return }; if useMockMode { startMockRecording(); return } }
    
    private func startMockRecording() {
        currentTranscript = ""; setupChecklist(); withAnimation { isRecording = true; isPaused = false }
        
        let mockSequences = [
            // 1. Deep Ocean (Dorsal Theme)
            [
                "I was swimming deep underwater with Sarah.",
                "No scuba gear, just breathing water naturally.",
                "Just infinite blue darkness for miles.",
                "I realized I was sinking, pulled by a heavy Anchor.",
                "I wasn't scared, just felt heavy and sleepy.",
                "I saw a Clock ticking underwater."
            ],
            // 2. High School Anxiety
            [
                "I was back in High School giving a presentation.",
                "My Mom and Dad were in the front row watching.",
                "I looked down and my notes were soaking wet.",
                "Then my teeth started feeling loose and wobbly.",
                "I spit one out and it was a white seashell.",
                "Everyone stared at me in silence."
            ],
            // 3. Glass Forest Chase
            [
                "I was running through a dense Forest at night.",
                "The trees were made of transparent, sharp glass.",
                "Something was chasing me but I couldn't look back.",
                "I reached my Childhood Home but the door was locked.",
                "Then the glass trees started shattering behind me.",
                "I woke up terrified just as the shards hit me."
            ],
            // 4. Flying over City
            [
                "I was flying over a huge futuristic City.",
                "The wind felt amazing, I was so free.",
                "I saw my Brother waving from a skyscraper roof.",
                "I tried to land but gravity stopped working.",
                "I just kept floating higher into the clouds.",
                "It was peaceful but a little lonely."
            ],
            // 5. The Empty Mall
            [
                "I was walking through a massive shopping Mall.",
                "But it was completely empty, no people anywhere.",
                "Just smooth jazz playing over the speakers.",
                "I went into a store and all the mannequins turned to look at me.",
                "They didn't have faces, just smooth plastic.",
                "I felt like I wasn't supposed to be there."
            ],
            // 6. Teeth Falling Out (Variant)
            [
                "I was at a dinner party with my Boss.",
                "I tried to eat an apple but my teeth crumbled like chalk.",
                "I tried to hide it but my mouth was full of dust.",
                "My Boss asked me a question and I couldn't speak.",
                "I felt so embarrassed and helpless."
            ],
            // 7. Late for Exam
            [
                "I realized I had a math final Exam in 5 minutes.",
                "But I was in a Hotel on the other side of town.",
                "I tried to run but my legs were moving in slow motion.",
                "The hallway kept stretching longer and longer.",
                "I knew I was going to fail and ruin everything."
            ],
            // 8. Talking Animal
            [
                "I was in my Kitchen making breakfast.",
                "A large brown Bear walked in and sat at the table.",
                "He asked me for coffee in perfect English.",
                "I wasn't scared, it felt totally normal.",
                "We talked about the weather and my job.",
                "He told me I need to rest more."
            ],
            // 9. Tornado
            [
                "I was standing in a flat open Field.",
                "The sky turned green and huge tornados formed.",
                "I tried to find shelter but there was nowhere to hide.",
                "The wind was deafening, roaring like a train.",
                "I held onto a fence post as the storm hit.",
                "I woke up heart pounding."
            ],
            // 10. Impossible House
            [
                "I discovered a new room in my Apartment.",
                "It was huge, like a ballroom with chandeliers.",
                "I couldn't believe I lived here and didn't know.",
                "But then the doors started disappearing.",
                "I got lost in my own house, trapping me inside.",
                "Every door led to a brick wall."
            ]
        ]
        
        let phrases = mockSequences[mockDreamIndex % mockSequences.count]
        mockDreamIndex += 1
        var phraseIndex = 0
        
        mockTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self = self, !self.isPaused else { return }
            Task { @MainActor in
                if phraseIndex < phrases.count {
                    self.currentTranscript += (self.currentTranscript.isEmpty ? "" : " ") + phrases[phraseIndex]
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
        withAnimation { isRecording = false; isPaused = false }
        if save && !currentTranscript.isEmpty {
            Task {
                await MainActor.run { self.isProcessing = true }
                let newDream = await createAndSaveDream()
                await refreshInsights()
                await MainActor.run { self.isProcessing = false; selectedTab = 1; navigationPath = NavigationPath(); navigationPath.append(newDream) }
            }
        } else if !save {
            currentTranscript = ""
        }
    }
    
    func pauseRecording() {
        withAnimation { isPaused.toggle() }
    }
    
    private func analyzeChecklist() { guard let current = activeQuestion, !isQuestionSatisfied else { return }; let lower = currentTranscript.lowercased(); for keyword in current.keywords { if lower.contains(keyword) { triggerSuccessAndAdvance(); return } } }
    private func triggerSuccessAndAdvance() { withAnimation { isQuestionSatisfied = true }; DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { self.advanceQuestion() } }
    private func advanceQuestion() { guard !remainingQuestions.isEmpty else { withAnimation { activeQuestion = nil }; return }; var nextIndex = 0; for (index, q) in remainingQuestions.enumerated() { for trigger in q.triggerKeywords { if currentTranscript.lowercased().contains(trigger) { nextIndex = index; break } } }; withAnimation { isQuestionSatisfied = false; activeQuestion = remainingQuestions.remove(at: nextIndex) } }
    
    private func setupChecklist() {
        var pool = [
            ChecklistItem(question: "Who was there?", keywords: ["mom", "dad", "friend", "brother", "sister", "people", "sarah", "boss", "bear"], triggerKeywords: ["saw", "met", "with"]),
            ChecklistItem(question: "Where did it take place?", keywords: ["home", "school", "work", "outside", "forest", "room", "office", "beach", "city", "mall", "hotel", "kitchen", "field", "apartment"], triggerKeywords: ["at", "in", "went"]),
            ChecklistItem(question: "How did you feel?", keywords: ["scared", "happy", "anxious", "calm", "weird", "heavy", "free", "helpless", "lonely"], triggerKeywords: ["felt", "was"])
        ]
        activeQuestion = pool.removeFirst(); remainingQuestions = pool; isQuestionSatisfied = false
    }
    
    func getRecommendations(for question: ChecklistItem) -> [String] {
        let lowerQuestion = question.question.lowercased()
        if lowerQuestion.contains("who") {
            return self.allPeople.isEmpty ? ["Mom", "Dad", "Friend"] : Array(self.allPeople.prefix(5)).map { $0.capitalized }
        } else if lowerQuestion.contains("where") {
            return self.allPlaces.isEmpty ? ["Home", "School", "Work"] : Array(self.allPlaces.prefix(5)).map { $0.capitalized }
        }
        return []
    }
    
    private func createAndSaveDream() async -> Dream {
        let text = currentTranscript
        
        let insight = try! await DreamAnalyzer.shared.analyze(transcript: text)
        let artPrompt = try! await DreamAnalyzer.shared.generateArtPrompt(transcript: text)
        let (imageData, imageHex) = try! await ImageCreator.shared.generateImage(llmPrompt: artPrompt, style: .illustration)
        
        let extracted = try! await DreamAnalyzer.shared.extractEntities(
            transcript: text,
            existingPeople: self.allPeople,
            existingPlaces: self.allPlaces
        )
        
        let newDream = Dream(
            id: UUID(),
            date: Date(),
            rawTranscript: text,
            smartSummary: insight.summary,
            interpretation: insight.interpretation,
            actionableAdvice: insight.actionableAdvice,
            emotion: insight.emotion,
            tone: insight.tone,
            sentimentScore: 0.5,
            voiceFatigue: Double.random(in: 0.1...0.9),
            keyEntities: extracted.keyEntities,
            people: extracted.people,
            places: extracted.places,
            emotions: extracted.emotions,
            generatedImageHex: imageHex,
            generatedImageData: imageData
        )
        
        dreams.insert(newDream, at: 0)
        saveDreamsToDisk()
        return newDream
    }
    
    private func loadDreams() { guard let data = try? Data(contentsOf: dreamsURL), let decoded = try? JSONDecoder().decode([Dream].self, from: data) else { return }; dreams = decoded }
    private func saveDreamsToDisk() { if let data = try? JSONEncoder().encode(dreams) { try? data.write(to: dreamsURL) } }
    private var dreamsURL: URL { FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("dorsal_dreams_v8.json") }
}
