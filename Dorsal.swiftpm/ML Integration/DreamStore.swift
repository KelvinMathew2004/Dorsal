import SwiftUI
import AVFoundation
import ImagePlayground
import FoundationModels
import SwiftData
import Combine
import Speech
import NaturalLanguage
import UserNotifications

struct DreamFilter: Equatable {
    var people: Set<String> = []
    var places: Set<String> = []
    var emotions: Set<String> = []
    var tags: Set<String> = []
    var showBookmarksOnly: Bool = false
    var isEmpty: Bool { people.isEmpty && places.isEmpty && emotions.isEmpty && tags.isEmpty && !showBookmarksOnly }
}

@MainActor
class DreamStore: NSObject, ObservableObject {
    @Published var dreams: [Dream] = []
    @Published var currentDreamID: UUID?
    
    @Published var generationError: String?
    
    @Published var firstName: String {
        didSet { UserDefaults.standard.set(firstName, forKey: "userFirstName") }
    }
    @Published var lastName: String {
        didSet { UserDefaults.standard.set(lastName, forKey: "userLastName") }
    }
    
    @Published var profileImageData: Data? {
        didSet {
            saveProfileImageToDisk(data: profileImageData)
            if profileImageData == nil {
                clearProfileColor()
            }
        }
    }
    
    @AppStorage("themeID") var currentThemeID: String = "gold" {
        didSet { objectWillChange.send() }
    }
    
    @AppStorage("isComplexVisualizerEnabled") var isComplexVisualizerEnabled: Bool = true {
        didSet { objectWillChange.send() }
    }
    
    @AppStorage("profileColorComponents") var profileColorComponents: String = ""

    var cachedProfileColor: Color? {
        if profileColorComponents.isEmpty { return nil }
        let components = profileColorComponents.split(separator: ",").compactMap { Double($0) }
        guard components.count >= 3 else { return nil }
        return Color(.sRGB, red: components[0], green: components[1], blue: components[2], opacity: components.count > 3 ? components[3] : 1)
    }

    func saveProfileColor(_ color: Color) {
        let uiColor = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        if uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            profileColorComponents = "\(red),\(green),\(blue),\(alpha)"
        }
    }
    
    func clearProfileColor() {
        profileColorComponents = ""
    }
    
    var themeAccentColor: Color {
        return Theme.availableThemes.first(where: { $0.id == currentThemeID })?.accent ?? Theme.availableThemes[0].accent
    }
    
    var themeSecondaryColor: Color {
        return Theme.availableThemes.first(where: { $0.id == currentThemeID })?.secondary ?? Theme.availableThemes[0].secondary
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
    @Published var isAnalyzingFatigue: Bool = false
    
    @Published var permissionError: String?
    @Published var showPermissionAlert: Bool = false
    
    @Published var hasMicAccess: Bool = false
    @Published var hasSpeechAccess: Bool = false
    
    @Published var hasNotificationAccess: Bool = false
    @AppStorage("reminderTime") var reminderTime: Double = 0
    @AppStorage("isReminderEnabled") var isReminderEnabled: Bool = false
    
    private var currentAnalysisTask: Task<Void, Never>?
    
    var isOnboardingComplete: Bool {
        hasMicAccess && hasSpeechAccess && UserDefaults.standard.bool(forKey: "isOnboardingFullyComplete")
    }
    
    func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "isOnboardingFullyComplete")
        objectWillChange.send()
    }
    
    func resetOnboarding() {
        UserDefaults.standard.set(false, forKey: "isOnboardingFullyComplete")
        objectWillChange.send()
    }
    
    @Published var isImageGenerationAvailable: Bool = false
    
    @Published var entityUpdateTrigger: Int = 0
    
    @Published var currentTranscript: String = ""
    @Published var isRecording: Bool = false
    @Published var isPaused: Bool = false
    @Published var audioPower: Float = 0.0
    
    @Published var isSpeechModelReady: Bool = false
    @Published var isSpeechModelInstalling: Bool = false
    
    private let audioRecorder = LiveAudioRecorder()
    private var cancellables = Set<AnyCancellable>()
    
    @Published var activeQuestion: ChecklistItem?
    @Published var isQuestionSatisfied: Bool = false
    @Published var answeredQuestions: Set<UUID> = []
    private var recommendationCache: [UUID: [String]] = [:]
    
    private let embedding = NLEmbedding.wordEmbedding(for: .english)
    
    struct ChecklistItem: Identifiable, Hashable {
        let id = UUID()
        let question: String
        let keywords: [String]
        let contextType: String
        let semanticConcepts: [String]
    }
    
    private let questions: [ChecklistItem] = [
        ChecklistItem(
            question: "Who was in the dream with you?",
            keywords: ["mom", "dad", "friend", "brother", "sister", "he", "she", "they", "someone", "person", "man", "woman", "grandma", "grandpa", "teacher", "celebrity", "bear", "octopus", "librarian", "taylor", "dad"],
            contextType: "person",
            semanticConcepts: ["relative", "friend", "stranger", "animal", "person", "family", "actor", "musician"]
        ),
        ChecklistItem(
            question: "Where did it take place?",
            keywords: ["home", "school", "work", "outside", "inside", "room", "forest", "city", "water", "place", "house", "building", "kitchen", "hallway", "mountain", "underwater", "library", "party", "car", "downtown"],
            contextType: "place",
            semanticConcepts: ["location", "place", "building", "nature", "landscape", "room", "city", "structure", "area", "environment"]
        ),
        ChecklistItem(
            question: "How did you feel?",
            keywords: ["happy", "sad", "scared", "anxious", "excited", "confused", "calm", "angry", "felt", "feeling", "joyful", "terrified", "empowered", "lonely", "relief", "curious", "starstruck"],
            contextType: "emotion",
            semanticConcepts: ["emotion", "feeling", "mood", "fear", "joy", "anger", "sadness", "surprise"]
        ),
        ChecklistItem(
            question: "How long did the dream feel?",
            keywords: ["minute", "minutes", "hour", "hours", "second", "seconds", "long", "short", "forever", "quick", "brief", "time", "eternity", "instant", "while", "lasted"],
            contextType: "duration",
            semanticConcepts: ["duration", "time", "length", "span"]
        ),
        ChecklistItem(
            question: "Any recent events that might have triggered this?",
            keywords: ["yesterday", "today", "recently", "watched", "saw", "movie", "show", "read", "book", "talked", "news", "happened", "because", "reminded", "trigger", "context", "real life", "work"],
            contextType: "context",
            semanticConcepts: ["cause", "reason", "event", "memory", "media", "day"]
        )
    ]
    private var updateStateTask: Task<Void, Never>?
    
    override init() {
        self.firstName = UserDefaults.standard.string(forKey: "userFirstName") ?? ""
        self.lastName = UserDefaults.standard.string(forKey: "userLastName") ?? ""
        super.init()
        self.profileImageData = loadProfileImageFromDisk()
        
        checkPermissions()
        checkNotificationStatus()
        setupObservers()
        
        Task {
            await checkImageGenerationSupport()
        }
    }
    
    private func setupObservers() {
        audioRecorder.$audioLevel
            .receive(on: RunLoop.main)
            .assign(to: \.audioPower, on: self)
            .store(in: &cancellables)
            
        audioRecorder.$liveTranscript
            .receive(on: RunLoop.main)
            .sink { [weak self] text in
                self?.currentTranscript = text
                self?.updateQuestionState()
            }
            .store(in: &cancellables)
            
        audioRecorder.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
            
        audioRecorder.$isPaused
            .receive(on: RunLoop.main)
            .assign(to: \.isPaused, on: self)
            .store(in: &cancellables)
        
        audioRecorder.$isModelReady
            .receive(on: RunLoop.main)
            .assign(to: \.isSpeechModelReady, on: self)
            .store(in: &cancellables)
            
        audioRecorder.$isModelInstalling
            .receive(on: RunLoop.main)
            .assign(to: \.isSpeechModelInstalling, on: self)
            .store(in: &cancellables)
    }
    
    func checkPermissions() {
        let micStatus = AVAudioApplication.shared.recordPermission
        self.hasMicAccess = (micStatus == .granted)
        
        let speechStatus = SFSpeechRecognizer.authorizationStatus()
        self.hasSpeechAccess = (speechStatus == .authorized)
    }
    
    func requestMicrophoneAccess() {
        let status = AVAudioApplication.shared.recordPermission
        switch status {
        case .undetermined:
            AVAudioApplication.requestRecordPermission { granted in
                Task { @MainActor [weak self] in
                    self?.hasMicAccess = granted
                }
            }
        case .denied:
            openSettings()
        case .granted:
            self.hasMicAccess = true
        @unknown default:
            break
        }
    }
    
    func requestSpeechAccess() {
        let status = SFSpeechRecognizer.authorizationStatus()
        switch status {
        case .notDetermined:
            SFSpeechRecognizer.requestAuthorization { newStatus in
                Task { @MainActor [weak self] in
                    self?.hasSpeechAccess = (newStatus == .authorized)
                }
            }
        case .denied, .restricted:
            openSettings()
        case .authorized:
            self.hasSpeechAccess = true
        @unknown default:
            break
        }
    }
    
    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
    
    func checkNotificationStatus() {
        let center = UNUserNotificationCenter.current()
        Task {
            let settings = await center.notificationSettings()
            await MainActor.run {
                self.hasNotificationAccess = (settings.authorizationStatus == .authorized)
            }
        }
    }

    func requestNotificationAccess() {
        let center = UNUserNotificationCenter.current()
        Task {
            let settings = await center.notificationSettings()
            let status = settings.authorizationStatus
            
            if status == .denied {
                await MainActor.run {
                    self.openSettings()
                }
            } else if status == .notDetermined {
                do {
                    let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
                    await MainActor.run {
                        self.hasNotificationAccess = granted
                        if granted && self.isReminderEnabled {
                            self.scheduleDailyReminder()
                        }
                    }
                } catch {
                    print("Error requesting notification authorization: \(error)")
                }
            } else if status == .authorized {
                await MainActor.run {
                    self.hasNotificationAccess = true
                }
            }
        }
    }
    
    func toggleReminder(enabled: Bool) {
        isReminderEnabled = enabled
        if enabled {
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                if settings.authorizationStatus == .authorized {
                    Task { @MainActor in self.scheduleDailyReminder() }
                } else if settings.authorizationStatus == .notDetermined {
                    Task { @MainActor in self.requestNotificationAccess() }
                }
            }
        } else {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["dailyDreamReminder"])
        }
    }
    
    func scheduleDailyReminder() {
        guard hasNotificationAccess && isReminderEnabled else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Record your dream!"
        content.body = "Take a moment to capture what you dreamt about last night."
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        
        let date = Date(timeIntervalSince1970: reminderTime)
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: date)
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: "dailyDreamReminder", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().add(request)
    }
    
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    var storageUsageString: String {
        let fileManager = FileManager.default
        guard let docDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return "Unknown" }
        
        do {
            let resourceKeys: [URLResourceKey] = [.fileSizeKey]
            let enumerator = fileManager.enumerator(at: docDir, includingPropertiesForKeys: resourceKeys)!
            var totalSize: Int64 = 0
            
            for case let fileURL as URL in enumerator {
                let resourceValues = try fileURL.resourceValues(forKeys: Set(resourceKeys))
                if let fileSize = resourceValues.fileSize {
                    totalSize += Int64(fileSize)
                }
            }
            
            let formatter = ByteCountFormatter()
            formatter.countStyle = .file
            return formatter.string(fromByteCount: totalSize)
        } catch {
            return "Unknown"
        }
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
    
    func updateEntity(name: String, type: String, description: String, image: Data?, contactId: String? = nil) {
        guard let context = modelContext else { return }
        let id = "\(type):\(name)"
        do {
            let descriptor = FetchDescriptor<SavedEntity>(predicate: #Predicate { $0.id == id })
            if let existing = try context.fetch(descriptor).first {
                existing.details = description
                existing.imageData = image
                existing.contactId = contactId
                existing.lastUpdated = Date()
            } else {
                let newEntity = SavedEntity(name: name, type: type, details: description, imageData: image)
                newEntity.contactId = contactId
                context.insert(newEntity)
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
            
            if activeFilter.showBookmarksOnly && !dream.isBookmarked { return false }
            
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
        let recs: [String] = switch item.contextType {
            case "person": ["My Mom", "A Friend", "Stranger"] + Array(Set(dreams.flatMap { $0.core?.people ?? [] })).prefix(3)
            case "place": ["Home", "School", "Work"] + Array(Set(dreams.flatMap { $0.core?.places ?? [] })).prefix(3)
            case "emotion": ["Scared", "Happy", "Confused"] + Array(Set(dreams.flatMap { $0.core?.emotions ?? [] })).prefix(3)
            default: []
        }
        let final = Array(Set(recs))
        recommendationCache[item.id] = final
        return final
    }
    
    private func updateQuestionState() {
        if isQuestionSatisfied { return }
        
        updateStateTask?.cancel()
        updateStateTask = Task {
            try? await Task.sleep(nanoseconds: 200_000_000)
            if Task.isCancelled { return }
            
            let transcriptSnapshot = await MainActor.run { self.currentTranscript }
            guard !transcriptSnapshot.isEmpty else { return }
            
            let unansweredQuestions = await MainActor.run {
                self.questions.filter { !self.answeredQuestions.contains($0.id) }
            }
            
            guard !unansweredQuestions.isEmpty else { return }
            
            let transcriptLower = transcriptSnapshot.lowercased()
            
            let tagger = NLTagger(tagSchemes: [.tokenType])
            let words = transcriptSnapshot.split(separator: " ")
            let recentText = words.suffix(15).joined(separator: " ")
            tagger.string = recentText
            
            for question in unansweredQuestions {
                var isSatisfied = false
                
                if question.keywords.contains(where: { transcriptLower.contains($0.lowercased()) }) {
                    isSatisfied = true
                }
                else if let embedding = self.embedding {
                    tagger.enumerateTags(in: recentText.startIndex..<recentText.endIndex, unit: .word, scheme: .tokenType, options: [.omitPunctuation, .omitWhitespace]) { _, tokenRange in
                        let word = String(recentText[tokenRange]).lowercased()
                        if word.count < 3 { return true }
                        
                        for concept in question.semanticConcepts {
                            let distance = embedding.distance(between: word, and: concept)
                            if distance < 0.65 {
                                isSatisfied = true; return false
                            }
                        }
                        for keyword in question.keywords {
                            let distance = embedding.distance(between: word, and: keyword)
                            if distance < 0.4 {
                                isSatisfied = true; return false
                            }
                        }
                        return true
                    }
                }
                
                if isSatisfied {
                    await MainActor.run {
                        self.handleSatisfiedQuestion(questionID: question.id)
                    }
                }
            }
        }
    }
    
    private func handleSatisfiedQuestion(questionID: UUID) {
        if answeredQuestions.contains(questionID) { return }
        
        if activeQuestion?.id == questionID {
            withAnimation { self.isQuestionSatisfied = true }
            Task {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                withAnimation(.easeInOut(duration: 0.5)) {
                    self.answeredQuestions.insert(questionID)
                    if let nextQ = self.questions.first(where: { !self.answeredQuestions.contains($0.id) }) {
                        self.activeQuestion = nextQ; self.isQuestionSatisfied = false
                    } else {
                        self.activeQuestion = nil; self.isQuestionSatisfied = true
                    }
                }
            }
        } else {
            self.answeredQuestions.insert(questionID)
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
    func toggleBookmarkFilter() { activeFilter.showBookmarksOnly.toggle() }
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
    
    func toggleBookmark(id: UUID) {
        if let index = dreams.firstIndex(where: { $0.id == id }) {
            dreams[index].isBookmarked.toggle()
            if let context = modelContext {
                let dreamID = id
                let descriptor = FetchDescriptor<SavedDream>(predicate: #Predicate { $0.id == dreamID })
                if let saved = try? context.fetch(descriptor).first {
                    saved.isBookmarked = dreams[index].isBookmarked
                    try? context.save()
                }
            }
        }
    }

    func startRecording() {
        currentTranscript = ""
        answeredQuestions = []
        isQuestionSatisfied = false
        recommendationCache = [:]
        activeQuestion = questions.first
        
        let keywords = questions.flatMap { $0.keywords }
        
        audioRecorder.startRecording(keywords: keywords) { [weak self] success in
            Task { @MainActor [weak self] in
                guard let self = self, success else { return }
                withAnimation { self.isRecording = true; self.isPaused = false }
            }
        }
    }
    
    func pauseRecording() {
        withAnimation { isPaused = true }
        audioRecorder.pauseRecording()
    }
    
    func resumeRecording() {
        withAnimation { isPaused = false }
        audioRecorder.resumeRecording()
    }
        
    func stopRecording(save: Bool) {
        guard let url = audioRecorder.stopRecording() else {
            withAnimation { isRecording = false; isPaused = false }
            return
        }
        withAnimation { isRecording = false; isPaused = false }
        
        if save && !currentTranscript.isEmpty {
            processDream(transcript: currentTranscript, audioURL: url)
        }
        if !save { currentTranscript = "" }
    }

    private func processDream(transcript: String, audioURL: URL) {
        currentAnalysisTask?.cancel()
        
        isProcessing = true
        let newID = UUID()
        currentDreamID = newID
        
        let newDream = Dream(id: newID, rawTranscript: transcript)
        dreams.insert(newDream, at: 0)
        
        persistDream(newDream)
        
        selectedTab = 1
        navigationPath = NavigationPath()
        navigationPath.append(newDream)
        
        runAnalysis(for: newID, transcript: transcript, audioURL: audioURL, existingFatigue: nil)
    }
    
    func regenerateDream(_ dream: Dream) {
        guard !isProcessing else { return }
        
        currentAnalysisTask?.cancel()
        
        guard let index = dreams.firstIndex(where: { $0.id == dream.id }) else { return }
        
        isProcessing = true
        currentDreamID = dream.id
        
        let existingFatigue = dreams[index].voiceFatigue
        
        dreams[index].core = nil
        dreams[index].extras = nil
        dreams[index].generatedImageData = nil
        dreams[index].analysisError = nil
        
        dreams[index].voiceFatigue = existingFatigue
        
        persistDream(dreams[index])
        
        runAnalysis(for: dream.id, transcript: dream.rawTranscript, audioURL: nil, existingFatigue: existingFatigue)
    }
    
    private func runAnalysis(for dreamID: UUID, transcript: String, audioURL: URL?, existingFatigue: Int?) {
        currentAnalysisTask = Task {
            do {
                for try await partialCore in DreamAnalyzer.shared.streamCore(transcript: transcript, userName: self.firstName) {
                    if Task.isCancelled { return }
                    
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
                
                var fatigueScore = 0
                await MainActor.run {
                     withAnimation { self.isAnalyzingFatigue = true }
                }

                if let existing = existingFatigue, existing > 0 {
                    fatigueScore = existing
                } else if let url = audioURL {
                    do {
                        fatigueScore = try await DreamAnalyzer.shared.analyzeVocalFatigue(audioURL: url)
                    } catch {
                        print("CoreML failed, falling back to text analysis: \(error)")
                        fatigueScore = await DreamAnalyzer.shared.estimateFallbackFatigue(transcript: transcript)
                    }
                } else {
                    fatigueScore = await DreamAnalyzer.shared.estimateFallbackFatigue(transcript: transcript)
                }

                await MainActor.run {
                    if let index = dreams.firstIndex(where: { $0.id == dreamID }) {
                        dreams[index].voiceFatigue = fatigueScore
                        persistDream(dreams[index])
                    }
                    withAnimation { self.isAnalyzingFatigue = false }
                }
                
                if let index = dreams.firstIndex(where: { $0.id == dreamID }),
                   let summary = dreams[index].core?.summary {
                    if isImageGenerationAvailable {
                        // ALWAYS SANITIZE PROMPT to avoid identity issues
                        do {
                            let sanitizedPrompt = try await DreamAnalyzer.shared.generateVisualPrompt(transcript: transcript)
                            let data = try await generateImageFromPrompt(prompt: sanitizedPrompt)
                            await MainActor.run {
                                if let idx = dreams.firstIndex(where: { $0.id == dreamID }) {
                                    dreams[idx].generatedImageData = data
                                }
                            }
                        } catch {
                            // If sanitization or generation fails, set error state
                            print("Image generation error: \(error)")
                            await MainActor.run {
                                if let idx = dreams.firstIndex(where: { $0.id == dreamID }) {
                                    // Use the specific DreamError cases if possible
                                    if let dreamError = error as? DreamError {
                                        dreams[idx].analysisError = dreamError.localizedDescription
                                    } else {
                                        dreams[idx].analysisError = "Could not visualize dream. \(error.localizedDescription)"
                                    }
                                    persistDream(dreams[idx])
                                }
                            }
                        }
                    }
                }
                
                for try await partialExtra in DreamAnalyzer.shared.streamExtras(transcript: transcript) {
                    if Task.isCancelled { return }
                    
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
                isAnalyzingFatigue = false
                Task { await refreshWeeklyInsights() }
                
            } catch {
                if Task.isCancelled { return }
                print("Analysis failed: \(error)")
                
                if let index = dreams.firstIndex(where: { $0.id == dreamID }) {
                    dreams[index].analysisError = error.localizedDescription
                    persistDream(dreams[index])
                }
                
                isProcessing = false
                isAnalyzingFatigue = false
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
