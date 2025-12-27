import SwiftUI
import AVFoundation
import ImagePlayground
import FoundationModels
import SwiftData

// ... (Filter Structs) ...
struct DreamFilter: Equatable {
    var people: Set<String> = []
    var places: Set<String> = []
    var emotions: Set<String> = []
    var tags: Set<String> = []
    var isEmpty: Bool { people.isEmpty && places.isEmpty && emotions.isEmpty && tags.isEmpty }
}

@MainActor
class DreamStore: NSObject, ObservableObject {
    @Published var dreams: [Dream] = []
    @Published var currentDreamID: UUID?
    
    var modelContext: ModelContext?
    
    @Published var searchQuery: String = ""
    @Published var activeFilter = DreamFilter()
    @Published var weeklyInsight: WeeklyInsightResult?
    @Published var isGeneratingInsights: Bool = false
    
    @Published var selectedTab: Int = 0
    @Published var navigationPath = NavigationPath()
    @Published var isProcessing: Bool = false
    @Published var permissionError: String?
    @Published var showPermissionAlert: Bool = false
    
    @Published var currentTranscript: String = ""
    @Published var isRecording: Bool = false
    @Published var isPaused: Bool = false
    @Published var audioPower: Float = 0.0
    private var mockTimer: Timer?
    private var mockIndex = 0
    
    @Published var activeQuestion: ChecklistItem?
    @Published var isQuestionSatisfied: Bool = false
    @Published var answeredQuestions: Set<UUID> = []
    private var recommendationCache: [UUID: [String]] = [:]
    
    struct ChecklistItem: Identifiable, Hashable { let id = UUID(); let question: String; let keywords: [String]; let contextType: String }
    private let questions: [ChecklistItem] = [
        ChecklistItem(question: "Who was in the dream with you?", keywords: ["mom", "dad", "friend", "brother", "sister", "he", "she", "they", "someone", "person", "man", "woman", "grandma", "grandpa", "teacher", "celebrity", "bear", "octopus", "librarian", "taylor", "dad"], contextType: "person"),
        ChecklistItem(question: "Where did it take place?", keywords: ["home", "school", "work", "outside", "inside", "room", "forest", "city", "water", "place", "house", "building", "kitchen", "hallway", "mountain", "underwater", "library", "party", "car", "downtown"], contextType: "place"),
        ChecklistItem(question: "How did you feel?", keywords: ["happy", "sad", "scared", "anxious", "excited", "confused", "calm", "angry", "felt", "feeling", "joyful", "terrified", "empowered", "lonely", "relief", "curious", "starstruck"], contextType: "emotion")
    ]
    private var updateStateTask: Task<Void, Never>?
    
    override init() {
        super.init()
    }
    
    func setContext(_ context: ModelContext) {
        self.modelContext = context
        fetchAllData()
    }
    
    func fetchAllData() {
        guard let context = modelContext else { return }
        do {
            let descriptor = FetchDescriptor<SavedDream>(sortBy: [SortDescriptor(\.date, order: .reverse)])
            let savedDreams = try context.fetch(descriptor)
            self.dreams = savedDreams.map { Dream(from: $0) }
        } catch { print("Fetch error: \(error)") }
        
        do {
            var descriptor = FetchDescriptor<SavedWeeklyInsight>(sortBy: [SortDescriptor(\.dateGenerated, order: .reverse)])
            descriptor.fetchLimit = 1
            if let latest = try context.fetch(descriptor).first {
                self.weeklyInsight = WeeklyInsightResult(
                    periodOverview: latest.periodOverview,
                    dominantTheme: latest.dominantTheme,
                    mentalHealthTrend: latest.mentalHealthTrend,
                    strategicAdvice: latest.strategicAdvice
                )
            }
        } catch { print("Insight fetch error: \(error)") }
    }
    
    // ... Computed Props ...
    var filteredDreams: [Dream] {
        dreams.filter { dream in
            let matchesSearch = searchQuery.isEmpty || dream.rawTranscript.localizedCaseInsensitiveContains(searchQuery)
            if !matchesSearch { return false }
            if !activeFilter.people.isEmpty {
                let dreamPeople = Set(dream.core?.people ?? [])
                if activeFilter.people.isDisjoint(with: dreamPeople) { return false }
            }
            if !activeFilter.places.isEmpty {
                let dreamPlaces = Set(dream.core?.places ?? [])
                if activeFilter.places.isDisjoint(with: dreamPlaces) { return false }
            }
            if !activeFilter.emotions.isEmpty {
                let dreamEmotions = Set(dream.core?.emotions ?? [])
                if activeFilter.emotions.isDisjoint(with: dreamEmotions) { return false }
            }
            if !activeFilter.tags.isEmpty {
                let dreamTags = Set(dream.core?.symbols ?? [])
                if activeFilter.tags.isDisjoint(with: dreamTags) { return false }
            }
            return true
        }
    }
    
    var allPeople: [String] { Array(Set(dreams.flatMap { $0.core?.people ?? [] })).sorted() }
    var allPlaces: [String] { Array(Set(dreams.flatMap { $0.core?.places ?? [] })).sorted() }
    var allEmotions: [String] { Array(Set(dreams.flatMap { $0.core?.emotions ?? [] })).sorted() }
    var allTags: [String] { Array(Set(dreams.flatMap { $0.core?.symbols ?? [] })).sorted() }
    
    func getRecommendations(for item: ChecklistItem) -> [String] {
        if let cached = recommendationCache[item.id] { return cached }
        let newRecs = generateRecommendations(for: item)
        recommendationCache[item.id] = newRecs
        return newRecs
    }
    
    private func generateRecommendations(for item: ChecklistItem) -> [String] {
        var recs: [String] = []
        switch item.contextType {
        case "person": recs = ["My Mom", "A Friend", "Stranger"]; let history = Array(Set(dreams.flatMap { $0.core?.people ?? [] })).prefix(3); recs.insert(contentsOf: history, at: 0)
        case "place": recs = ["Home", "School", "Work"]; let history = Array(Set(dreams.flatMap { $0.core?.places ?? [] })).prefix(3); recs.insert(contentsOf: history, at: 0)
        case "emotion": recs = ["Scared", "Happy", "Confused", "Calm"]; let history = Array(Set(dreams.flatMap { $0.core?.emotions ?? [] })).prefix(3); recs.insert(contentsOf: history, at: 0)
        default: break
        }
        return Array(Set(recs))
    }
    
    private func updateQuestionState() {
        if isQuestionSatisfied { return }
        updateStateTask?.cancel()
        updateStateTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 100_000_000)
            if Task.isCancelled { return }
            guard let nextQuestion = questions.first(where: { !answeredQuestions.contains($0.id) }) else {
                if activeQuestion != nil { withAnimation { activeQuestion = nil; isQuestionSatisfied = true } }
                return
            }
            let transcriptLower = currentTranscript.lowercased()
            let isSatisfied = nextQuestion.keywords.contains { keyword in transcriptLower.contains(keyword.lowercased()) }
            if isSatisfied {
                if activeQuestion?.id == nextQuestion.id {
                    withAnimation { isQuestionSatisfied = true }
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    if Task.isCancelled { return }
                    withAnimation(.easeInOut(duration: 0.5)) {
                        answeredQuestions.insert(nextQuestion.id)
                        if let following = questions.first(where: { !answeredQuestions.contains($0.id) }) {
                            activeQuestion = following; isQuestionSatisfied = false
                        } else {
                            activeQuestion = nil; isQuestionSatisfied = true
                        }
                    }
                } else if activeQuestion == nil { activeQuestion = nextQuestion }
            } else if activeQuestion?.id != nextQuestion.id {
                withAnimation { activeQuestion = nextQuestion; isQuestionSatisfied = false }
            }
        }
    }
    
    func deleteDream(_ dream: Dream) {
        if let index = dreams.firstIndex(where: { $0.id == dream.id }) {
            dreams.remove(at: index)
            if let context = modelContext {
                let id = dream.id
                try? context.delete(model: SavedDream.self, where: #Predicate { $0.id == id })
                try? context.save()
            }
        }
    }
    
    private func deleteDreamFromPersistenceOnly(_ dream: Dream) {
        guard let context = modelContext else { return }
        let id = dream.id
        try? context.delete(model: SavedDream.self, where: #Predicate { $0.id == id })
        try? context.save()
    }
    
    func ignoreErrorAndKeepDream(_ dream: Dream) {
        if let index = dreams.firstIndex(where: { $0.id == dream.id }) {
            dreams[index].analysisError = nil
            persistDream(dreams[index])
        }
    }
    
    func togglePersonFilter(_ item: String) { if activeFilter.people.contains(item) { activeFilter.people.remove(item) } else { activeFilter.people.insert(item) } }
    func togglePlaceFilter(_ item: String) { if activeFilter.places.contains(item) { activeFilter.places.remove(item) } else { activeFilter.places.insert(item) } }
    func toggleEmotionFilter(_ item: String) { if activeFilter.emotions.contains(item) { activeFilter.emotions.remove(item) } else { activeFilter.emotions.insert(item) } }
    func toggleTagFilter(_ item: String) { if activeFilter.tags.contains(item) { activeFilter.tags.remove(item) } else { activeFilter.tags.insert(item) } }
    func clearFilter() { activeFilter = DreamFilter() }
    
    // Logic updated to actually apply the filter
    func jumpToFilter(type: String, value: String) {
        clearFilter()
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

    // MARK: - RECORDING
    func startRecording() {
        withAnimation { isRecording = true; isPaused = false }
        currentTranscript = ""
        answeredQuestions = []
        isQuestionSatisfied = false
        recommendationCache = [:]
        activeQuestion = questions.first
        
        let extendedScenarios = [
            "Um... so, I woke up feeling really strange today. In the dream, I was walking through this... dense, foggy forest. (Pause). It felt like... I don't know, like I was searching for something. Then I saw my grandmother sitting on a mushroom. (Pause). She looked exactly like she did when I was a kid. I felt a sense of calm but also confusion. (Pause). Why was she there?",
            "Okay, so I was late for an exam I didn't study for. Classic nightmare, right? The classroom was... weirdly enough, underwater. (Pause). Like, I could breathe, but everything was floating. My teacher was a giant octopus. (Pause). Yeah, an octopus with glasses. I felt anxious, just panic rising in my chest. (Pause). I couldn't find my pen."
        ]
        let text = extendedScenarios[mockIndex % extendedScenarios.count]; mockIndex += 1
        let words = text.components(separatedBy: " "); var wordIndex = 0
        
        mockTimer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if self.isPaused { return }
                if wordIndex < words.count {
                    let word = words[wordIndex]
                    if word.contains("(Pause)") { self.audioPower = 0.05 } else {
                        self.currentTranscript += (self.currentTranscript.isEmpty ? "" : " ") + word
                        self.audioPower = Float.random(in: 0.3...0.7)
                        self.updateQuestionState()
                    }
                    wordIndex += 1
                } else {
                    self.audioPower = 0.1; self.updateQuestionState(); self.mockTimer?.invalidate()
                }
            }
        }
    }
    
    func pauseRecording() { withAnimation { isPaused.toggle() } }
    func openSettings() {}
    
    func stopRecording(save: Bool) {
        mockTimer?.invalidate()
        withAnimation { isRecording = false; isPaused = false }
        if save && !currentTranscript.isEmpty {
            processDream(transcript: currentTranscript)
        }
        currentTranscript = ""
    }

    // MARK: - PROCESSING PIPELINE (STREAMING)
    private func processDream(transcript: String) {
        isProcessing = true
        let newID = UUID()
        currentDreamID = newID
        
        var newDream = Dream(id: newID, rawTranscript: transcript)
        dreams.insert(newDream, at: 0)
        
        persistDream(newDream)
        
        selectedTab = 1
        navigationPath = NavigationPath()
        navigationPath.append(newDream)
        
        runAnalysis(for: newID, transcript: transcript)
    }
    
    func regenerateDream(_ dream: Dream) {
        guard !isProcessing else { return }
        guard let index = dreams.firstIndex(where: { $0.id == dream.id }) else { return }
        
        isProcessing = true
        currentDreamID = dream.id
        
        dreams[index].core = nil
        dreams[index].extras = nil
        dreams[index].generatedImageData = nil
        dreams[index].analysisError = nil
        
        persistDream(dreams[index])
        
        runAnalysis(for: dream.id, transcript: dream.rawTranscript)
    }
    
    private func runAnalysis(for dreamID: UUID, transcript: String) {
        Task {
            do {
                for try await partialCore in DreamAnalyzer.shared.streamCore(transcript: transcript) {
                    if let index = dreams.firstIndex(where: { $0.id == dreamID }) {
                        var currentCore = dreams[index].core ?? DreamCoreAnalysis()
                        
                        if let t = partialCore.title { currentCore.title = t }
                        if let s = partialCore.summary { currentCore.summary = s }
                        if let e = partialCore.emotion { currentCore.emotion = e }
                        if let p = partialCore.people { currentCore.people = p }
                        if let pl = partialCore.places { currentCore.places = pl }
                        if let em = partialCore.emotions { currentCore.emotions = em }
                        if let sym = partialCore.symbols { currentCore.symbols = sym }
                        if let i = partialCore.interpretation { currentCore.interpretation = i }
                        if let a = partialCore.actionableAdvice { currentCore.actionableAdvice = a }
                        if let f = partialCore.voiceFatigue { currentCore.voiceFatigue = f }
                        if let toneLabel = partialCore.tone?.label {
                            currentCore.tone = ToneAnalysis(label: toneLabel, confidence: partialCore.tone?.confidence)
                        }
                        
                        dreams[index].core = currentCore
                    }
                }
                
                if let index = dreams.firstIndex(where: { $0.id == dreamID }),
                   let summary = dreams[index].core?.summary {
                    let manualPrompt = "\(summary). Artistic style: Dreamlike, surreal, soft lighting."
                    do {
                        let creator = try await ImageCreator()
                        guard let firstAvailable = creator.availableStyles.first else {
                            throw DreamError.imageUnavailable
                        }
                        let selectedStyle: ImagePlaygroundStyle = creator.availableStyles.contains(.illustration) ? .illustration : firstAvailable
                        let concepts: [ImagePlaygroundConcept] = [.text(manualPrompt)]
                        
                        for try await image in creator.images(for: concepts, style: selectedStyle, limit: 1) {
                            let cgImage = image.cgImage
                            let uiImage = UIImage(cgImage: cgImage)
                            if let pngData = uiImage.pngData() {
                                dreams[index].generatedImageData = pngData
                                break
                            }
                        }
                    } catch let error as ImageCreator.Error {
                        let specificError: DreamError
                        switch error {
                        case .notSupported: specificError = .imageNotSupported
                        case .unavailable: specificError = .imageUnavailable
                        case .creationCancelled: return
                        case .conceptsRequirePersonIdentity: specificError = .personIdentityRequired
                        case .faceInImageTooSmall, .unsupportedInputImage: specificError = .imageInputInvalid
                        case .unsupportedLanguage: specificError = .unsupportedLanguage
                        case .backgroundCreationForbidden: specificError = .backgroundExecutionForbidden
                        case .creationFailed: specificError = .imageGenerationFailed
                        @unknown default: specificError = .imageGenerationFailed
                        }
                        
                        if let index = dreams.firstIndex(where: { $0.id == dreamID }) {
                            dreams[index].analysisError = specificError.localizedDescription
                            deleteDreamFromPersistenceOnly(dreams[index])
                        }
                    } catch {
                        print("Unknown Image error: \(error)")
                    }
                }
                
                // Stream Extras
                for try await partialExtra in DreamAnalyzer.shared.streamExtras(transcript: transcript) {
                    if let index = dreams.firstIndex(where: { $0.id == dreamID }) {
                        var currentExtras = dreams[index].extras ?? DreamExtraAnalysis()
                        if let s = partialExtra.sentimentScore { currentExtras.sentimentScore = s }
                        if let nm = partialExtra.isNightmare { currentExtras.isNightmare = nm }
                        if let l = partialExtra.lucidityScore { currentExtras.lucidityScore = l }
                        if let v = partialExtra.vividnessScore { currentExtras.vividnessScore = v }
                        if let c = partialExtra.coherenceScore { currentExtras.coherenceScore = c }
                        if let a = partialExtra.anxietyLevel { currentExtras.anxietyLevel = a }
                        dreams[index].extras = currentExtras
                    }
                }
                
                if let finalDream = dreams.first(where: { $0.id == dreamID }) {
                    persistDream(finalDream)
                }
                
                isProcessing = false
                Task { await refreshWeeklyInsights() }
                
            } catch {
                print("Streaming failed: \(error)")
                isProcessing = false
                if let index = dreams.firstIndex(where: { $0.id == dreamID }) {
                    dreams[index].analysisError = error.localizedDescription
                    deleteDreamFromPersistenceOnly(dreams[index])
                }
            }
        }
    }
    
    func persistDream(_ dream: Dream) {
        guard let context = modelContext else { return }
        
        let id = dream.id
        // Handle Upsert: Delete existing if present, then insert new
        do {
            try context.delete(model: SavedDream.self, where: #Predicate { $0.id == id })
        } catch {
            print("Delete error in persist: \(error)")
        }
        
        // Insert
        let saved = SavedDream(from: dream)
        context.insert(saved)
        try? context.save()
    }
    
    func persistInsight(_ insight: WeeklyInsightResult) {
        guard let context = modelContext else { return }
        let saved = SavedWeeklyInsight(
            periodOverview: insight.periodOverview ?? "",
            dominantTheme: insight.dominantTheme ?? "",
            mentalHealthTrend: insight.mentalHealthTrend ?? "",
            strategicAdvice: insight.strategicAdvice ?? ""
        )
        context.insert(saved)
        try? context.save()
    }
    
    func refreshWeeklyInsights() async {
        guard !dreams.isEmpty else { return }
        withAnimation { isGeneratingInsights = true }
        do {
            let recentDreams = dreams.filter { $0.date > Date().addingTimeInterval(-30*24*60*60) }
            guard !recentDreams.isEmpty else { isGeneratingInsights = false; return }
            let insights = try await DreamAnalyzer.shared.analyzeWeeklyTrends(dreams: recentDreams)
            self.weeklyInsight = insights
            persistInsight(insights)
        } catch { print("Insights error: \(error)") }
        withAnimation { isGeneratingInsights = false }
    }
}
