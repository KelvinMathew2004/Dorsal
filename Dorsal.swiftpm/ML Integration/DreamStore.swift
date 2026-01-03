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
    
    // MARK: - PERSISTENT USER DATA
    
    // Names backed by UserDefaults
    @Published var firstName: String {
        didSet { UserDefaults.standard.set(firstName, forKey: "userFirstName") }
    }
    @Published var lastName: String {
        didSet { UserDefaults.standard.set(lastName, forKey: "userLastName") }
    }
    
    // Profile Image backed by FileManager (more robust for large data)
    @Published var profileImageData: Data? {
        didSet { saveProfileImageToDisk(data: profileImageData) }
    }
    
    var userName: String {
        return "\(firstName) \(lastName)"
    }
    
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
    
    // MARK: - IMAGE GENERATION SUPPORT
    @Published var isImageGenerationAvailable: Bool = false
    
    // MARK: - UI UPDATE TRIGGERS
    // Used to force views to redraw when entities are updated in the background context
    @Published var entityUpdateTrigger: Int = 0
    
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
        self.firstName = UserDefaults.standard.string(forKey: "userFirstName") ?? ""
        self.lastName = UserDefaults.standard.string(forKey: "userLastName") ?? ""
        super.init()
        self.profileImageData = loadProfileImageFromDisk()
        
        // Check for Image Generation Support
        Task {
            await checkImageGenerationSupport()
        }
    }
    
    // MARK: - PERSISTENCE HELPERS
    
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private func saveProfileImageToDisk(data: Data?) {
        let url = getDocumentsDirectory().appendingPathComponent("profile_image.png")
        if let data = data {
            try? data.write(to: url)
        } else {
            try? FileManager.default.removeItem(at: url)
        }
    }
    
    private func loadProfileImageFromDisk() -> Data? {
        let url = getDocumentsDirectory().appendingPathComponent("profile_image.png")
        return try? Data(contentsOf: url)
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
    
    // MARK: - ENTITY MANAGEMENT
    
    func getEntity(name: String, type: String) -> SavedEntity? {
        guard let context = modelContext else { return nil }
        let id = "\(type):\(name)"
        let descriptor = FetchDescriptor<SavedEntity>(predicate: #Predicate { $0.id == id })
        return try? context.fetch(descriptor).first
    }
    
    func getRootEntities(type: String) -> [SavedEntity] {
        guard let context = modelContext else { return [] }
        _ = entityUpdateTrigger
        
        let descriptor = FetchDescriptor<SavedEntity>(predicate: #Predicate { $0.type == type })
        let savedEntities = (try? context.fetch(descriptor)) ?? []
        
        let dreamNames: [String]
        switch type {
        case "person": dreamNames = allPeopleNamesFromDreams
        case "place": dreamNames = allPlacesNamesFromDreams
        case "tag": dreamNames = allTagsNamesFromDreams
        default: dreamNames = []
        }
        
        var entityMap: [String: SavedEntity] = [:]
        for entity in savedEntities { entityMap[entity.name] = entity }
        
        var roots: [SavedEntity] = []
        for entity in savedEntities {
            if entity.parentID == nil { roots.append(entity) }
        }
        
        for name in dreamNames {
            if entityMap[name] == nil {
                let temp = SavedEntity(name: name, type: type)
                roots.append(temp)
                entityMap[name] = temp
            }
        }
        
        return roots.sorted { $0.name < $1.name }
    }
    
    func getChildren(for parentName: String, type: String) -> [SavedEntity] {
        guard let context = modelContext else { return [] }
        _ = entityUpdateTrigger
        let parentID = "\(type):\(parentName)"
        let descriptor = FetchDescriptor<SavedEntity>(predicate: #Predicate { $0.parentID == parentID })
        return (try? context.fetch(descriptor)) ?? []
    }
    
    func linkEntity(childName: String, childType: String, parentName: String, parentType: String) {
        guard let context = modelContext else { return }
        if childName == parentName || childType != parentType { return }
        
        if getEntity(name: childName, type: childType) == nil {
            context.insert(SavedEntity(name: childName, type: childType))
        }
        if getEntity(name: parentName, type: parentType) == nil {
            context.insert(SavedEntity(name: parentName, type: parentType))
        }
        
        if let child = getEntity(name: childName, type: childType) {
            let parentID = "\(parentType):\(parentName)"
            if let parent = getEntity(name: parentName, type: parentType), parent.parentID == child.id { return }
            child.parentID = parentID
            child.lastUpdated = Date()
            try? context.save()
            self.entityUpdateTrigger += 1
        }
    }
    
    func unlinkEntity(name: String, type: String) {
        guard let context = modelContext else { return }
        guard let entity = getEntity(name: name, type: type) else { return }
        entity.parentID = nil
        entity.lastUpdated = Date()
        try? context.save()
        self.entityUpdateTrigger += 1
    }
    
    func updateEntity(name: String, type: String, description: String, image: Data?) {
        guard let context = modelContext else { return }
        let id = "\(type):\(name)"
        do {
            let descriptor = FetchDescriptor<SavedEntity>(predicate: #Predicate { $0.id == id })
            if let existing = try context.fetch(descriptor).first {
                existing.details = description
                existing.imageData = image
                existing.lastUpdated = Date()
            } else {
                context.insert(SavedEntity(name: name, type: type, details: description, imageData: image))
            }
            try context.save()
            self.entityUpdateTrigger += 1
        } catch { print("Entity Save Error: \(error)") }
    }
    
    func deleteEntity(name: String, type: String) {
        guard let context = modelContext else { return }
        let id = "\(type):\(name)"
        do {
            let childrenDescriptor = FetchDescriptor<SavedEntity>(predicate: #Predicate { $0.parentID == id })
            if let children = try? context.fetch(childrenDescriptor) {
                for child in children { child.parentID = nil }
            }
            try context.delete(model: SavedEntity.self, where: #Predicate { $0.id == id })
            try context.save()
            self.entityUpdateTrigger += 1
        } catch { print("Entity Delete Error: \(error)") }
    }
    
    // MARK: - IMAGE GENERATION
    
    func checkImageGenerationSupport() async {
        do {
            _ = try await ImageCreator()
            self.isImageGenerationAvailable = true
        } catch {
            print("Image generation not supported: \(error)")
            self.isImageGenerationAvailable = false
        }
    }
    
    func generateImageFromPrompt(prompt: String) async throws -> Data {
        guard isImageGenerationAvailable else { throw DreamError.imageUnavailable }
        let creator = try await ImageCreator()
        let selectedStyle: ImagePlaygroundStyle = creator.availableStyles.contains(.illustration) ? .illustration : (creator.availableStyles.first ?? .illustration)
        
        for try await image in creator.images(for: [.text(prompt)], style: selectedStyle, limit: 1) {
            if let data = UIImage(cgImage: image.cgImage).pngData() { return data }
        }
        throw DreamError.imageGenerationFailed
    }
    
    // ... Computed Props ...
    
    private func resolveAliases(for names: Set<String>, type: String) -> Set<String> {
        guard let context = modelContext else { return names }
        var resolved = names
        for name in names {
            let parentID = "\(type):\(name)"
            let descriptor = FetchDescriptor<SavedEntity>(predicate: #Predicate { $0.parentID == parentID })
            if let children = try? context.fetch(descriptor) {
                for child in children { resolved.insert(child.name) }
            }
        }
        return resolved
    }
    
    var filteredDreams: [Dream] {
        let peopleFilter = resolveAliases(for: activeFilter.people, type: "person")
        let placesFilter = resolveAliases(for: activeFilter.places, type: "place")
        let tagsFilter = resolveAliases(for: activeFilter.tags, type: "tag")
        
        return dreams.filter { dream in
            let matchesSearch = searchQuery.isEmpty || dream.rawTranscript.localizedCaseInsensitiveContains(searchQuery)
            if !matchesSearch { return false }
            if !peopleFilter.isEmpty {
                let dreamPeople = Set(dream.core?.people ?? [])
                if peopleFilter.isDisjoint(with: dreamPeople) { return false }
            }
            if !placesFilter.isEmpty {
                let dreamPlaces = Set(dream.core?.places ?? [])
                if placesFilter.isDisjoint(with: dreamPlaces) { return false }
            }
            if !activeFilter.emotions.isEmpty {
                let dreamEmotions = Set(dream.core?.emotions ?? [])
                if activeFilter.emotions.isDisjoint(with: dreamEmotions) { return false }
            }
            if !tagsFilter.isEmpty {
                let dreamTags = Set(dream.core?.symbols ?? [])
                if tagsFilter.isDisjoint(with: dreamTags) { return false }
            }
            return true
        }
    }
    
    var currentStreak: Int {
        let calendar = Calendar.current
        let sortedDates = dreams.map { $0.date }.sorted(by: >)
        guard let lastDreamDate = sortedDates.first else { return 0 }
        
        if !calendar.isDateInToday(lastDreamDate) && !calendar.isDateInYesterday(lastDreamDate) { return 0 }
        
        var streak = 1
        var currentDate = lastDreamDate
        for i in 1..<sortedDates.count {
            let previousDate = sortedDates[i]
            if calendar.isDate(previousDate, inSameDayAs: currentDate) { continue }
            if let dayBefore = calendar.date(byAdding: .day, value: -1, to: currentDate), calendar.isDate(previousDate, inSameDayAs: dayBefore) {
                streak += 1
                currentDate = previousDate
            } else { break }
        }
        return streak
    }
    
    private var allPeopleNamesFromDreams: [String] { Array(Set(dreams.flatMap { $0.core?.people ?? [] })).sorted() }
    private var allPlacesNamesFromDreams: [String] { Array(Set(dreams.flatMap { $0.core?.places ?? [] })).sorted() }
    private var allTagsNamesFromDreams: [String] { Array(Set(dreams.flatMap { $0.core?.symbols ?? [] })).sorted() }
    
    var allPeople: [String] { getRootEntities(type: "person").map { $0.name } }
    var allPlaces: [String] { getRootEntities(type: "place").map { $0.name } }
    var allEmotions: [String] { Array(Set(dreams.flatMap { $0.core?.emotions ?? [] })).sorted() }
    var allTags: [String] { getRootEntities(type: "tag").map { $0.name } }
    
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
            "So… this one felt personal. I was scrolling through my phone, but none of the messages made sense. (Pause). Some were from people I hadn’t talked to in years. I tried replying, but the text wouldn’t send. Then the screen went blank. (Pause). I felt frustrated and kind of lonely. (Pause). Why couldn’t I reach anyone?",
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
                for try await partialCore in DreamAnalyzer.shared.streamCore(transcript: transcript, userName: self.firstName) {
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
                   let currentCore = dreams[index].core {
                    let repairedCore = await DreamAnalyzer.shared.ensureCoreFields(current: currentCore, transcript: transcript)
                    dreams[index].core = repairedCore
                }
                
                if let index = dreams.firstIndex(where: { $0.id == dreamID }),
                   let summary = dreams[index].core?.summary {
                    if isImageGenerationAvailable {
                        let manualPrompt = "\(summary). Artistic style: Dreamlike, surreal, soft lighting."
                        do {
                            let data = try await generateImageFromPrompt(prompt: manualPrompt)
                            dreams[index].generatedImageData = data
                        } catch {
                            print("Image generation error: \(error)")
                        }
                    }
                }
                
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
                
                if let index = dreams.firstIndex(where: { $0.id == dreamID }),
                   let currentExtras = dreams[index].extras {
                    let repairedExtras = await DreamAnalyzer.shared.ensureExtraFields(current: currentExtras, transcript: transcript)
                    dreams[index].extras = repairedExtras
                }
                
                if let finalDream = dreams.first(where: { $0.id == dreamID }) {
                    persistDream(finalDream)
                }
                
                isProcessing = false
                Task { await refreshWeeklyInsights() }
                
            } catch {
                print("Streaming failed: \(error)")
                isProcessing = false
            }
        }
    }
    
    func persistDream(_ dream: Dream) {
        guard let context = modelContext else { return }
        let id = dream.id
        do {
            try context.delete(model: SavedDream.self, where: #Predicate { $0.id == id })
        } catch { print("Delete error: \(error)") }
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
        
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        let now = Date()
        
        let weekInterval = calendar.dateInterval(of: .weekOfYear, for: now)
        ?? DateInterval(start: now.addingTimeInterval(-7*24*60*60), duration: 7*24*60*60)
        
        do {
            let recentDreams = dreams.filter { weekInterval.contains($0.date) }
            guard !recentDreams.isEmpty else {
                isGeneratingInsights = false
                return
            }
            
            let insights = try await DreamAnalyzer.shared.analyzeWeeklyTrends(dreams: recentDreams, userName: self.firstName)
            self.weeklyInsight = insights
            persistInsight(insights)
        } catch { print("Insights error: \(error)") }
        withAnimation { isGeneratingInsights = false }
    }
}
