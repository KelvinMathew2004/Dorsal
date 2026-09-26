import SwiftUI
import AVFoundation
import ImagePlayground
import FoundationModels
import SwiftData
import Combine
import Speech
import NaturalLanguage
import UserNotifications
import CloudKit
import PhotosUI
import HealthKit

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
    static let shared = DreamStore()
    
    @Published var dreams: [Dream] = []
    @Published var currentDreamID: UUID?
    
    @Published var generationError: String?
    @Published var analysisAvailability = AnalysisAvailability(SystemLanguageModel.default.availability)
    @Published var isStartingRecording = false
    @Published var isFinishingRecording = false
    @Published var transcriptionNotice: String?
    @Published var recordingError: String?
    @Published var persistenceError: String?
    @Published var transcribingDreamID: UUID?
    @Published var usesSleepData = UserDefaults.standard.bool(forKey: "usesSleepData") {
        didSet { UserDefaults.standard.set(usesSleepData, forKey: "usesSleepData") }
    }
    @Published var requestingSleepAccess = false
    @Published var sleepAccessMessage: String?

    var isHealthDataAvailable: Bool { SleepDataManager.shared.isAvailable }

    func requestSleepAccess() async {
        guard !requestingSleepAccess, isHealthDataAvailable else { return }
        requestingSleepAccess = true
        sleepAccessMessage = nil
        defer { requestingSleepAccess = false }
        do {
            try await SleepDataManager.shared.requestAuthorization()
            // Successful presentation does not reveal whether read permission was granted.
            usesSleepData = true
            if try await sleepSummary(for: Date()) == nil {
                sleepAccessMessage = "No sleep data is available to Dorsal. You can review sharing in the Health app."
            }
        } catch is CancellationError {
        } catch let error as HKError where error.code == .errorUserCanceled {
        } catch {
            sleepAccessMessage = "Sleep data couldn’t be opened. You can continue using Dorsal and try again later."
        }
    }
    private var unsavedDreamIDs: Set<UUID> = []
    private struct PendingEntityUpdate {
        let name: String, type: String, details: String
        let image: Data?
        let contactID: String?
        let place: LinkedPlace?
    }
    private var pendingEntityUpdates: [String: PendingEntityUpdate] = [:]
    private let recoveryStore = DreamRecoveryStore()
    var recordingIsBusy: Bool { isStartingRecording || isFinishingRecording }

    func refreshAvailability() async {
        analysisAvailability = availabilityProvider()
        await checkImageGenerationSupport()
    }

    
    // MARK: - Synced User Properties
    @Published var firstName: String {
        didSet {
            UserDefaults.standard.set(firstName, forKey: "userFirstName")
            NSUbiquitousKeyValueStore.default.set(firstName, forKey: "userFirstName")
        }
    }
    @Published var lastName: String {
        didSet {
            UserDefaults.standard.set(lastName, forKey: "userLastName")
            NSUbiquitousKeyValueStore.default.set(lastName, forKey: "userLastName")
        }
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
        didSet {
            // Push to iCloud whenever the user changes the theme
            NSUbiquitousKeyValueStore.default.set(currentThemeID, forKey: "themeID")
            objectWillChange.send()
        }
    }
    
    @AppStorage("isComplexVisualizerEnabled") var isComplexVisualizerEnabled: Bool = false {
        didSet { objectWillChange.send() }
    }
    
    @AppStorage("imageGenerationStyle") var imageGenerationStyle: String = "pixar" {
        didSet { objectWillChange.send() }
    }

    @AppStorage("imageIncludeMyself") var imageIncludeMyself: Bool = true {
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
    private var pendingIntentDream: UUID?
    private var hasPendingDreamIntent = false

    func openSectionFromIntent(_ section: DorsalSection) {
        // A newer navigation action supersedes any deferred entry request.
        pendingIntentDream = nil
        hasPendingDreamIntent = false
        switch section {
        case .recorder:
            selectedTab = 0
        case .journal:
            clearFilter()
            searchQuery = ""
            navigationPath = NavigationPath()
            selectedTab = 1
        case .insights: selectedTab = 2
        case .profile: selectedTab = 3
        }
    }

    func openDreamFromIntent(id: UUID? = nil) {
        pendingIntentDream = id
        hasPendingDreamIntent = true
        selectedTab = 1
        resolvePendingDreamIntent()
    }

    func searchDreamsFromIntent(_ query: String) {
        openSectionFromIntent(.journal)
        searchQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func resolvePendingDreamIntent() {
        guard hasPendingDreamIntent, modelContext != nil else { return }
        hasPendingDreamIntent = false
        let dream = pendingIntentDream.flatMap { id in dreams.first { $0.id == id } }
            ?? (pendingIntentDream == nil ? dreams.max { $0.date < $1.date } : nil)
        pendingIntentDream = nil
        navigationPath = NavigationPath()
        if let dream { navigationPath.append(dream) }
    }
    
    @Published var isProcessing: Bool = false
    @Published var isAnalyzingFatigue: Bool = false
    
    @Published var permissionError: String?
    @Published var showPermissionAlert: Bool = false
    @Published var showNotificationAlert: Bool = false
    
    @Published var hasMicAccess: Bool = false
    
    @Published var hasNotificationAccess: Bool = false
    @AppStorage("reminderTime") var reminderTime: Double = 0
    @AppStorage("isReminderEnabled") var isReminderEnabled: Bool = false
    
    private var currentAnalysisTask: Task<Void, Never>?
    
    // MARK: - Synced Onboarding Status
    var isOnboardingComplete: Bool {
        UserDefaults.standard.bool(forKey: "isOnboardingFullyComplete")
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
        
    private let audioRecorder: LiveAudioRecorder
    private let availabilityProvider: () -> AnalysisAvailability
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
    
    init(prepareServices: Bool = true,
         availabilityProvider: @escaping () -> AnalysisAvailability = { AnalysisAvailability(SystemLanguageModel.default.availability) }) {
        self.availabilityProvider = availabilityProvider
        self.audioRecorder = LiveAudioRecorder(prepareModels: prepareServices)
        let kvs = NSUbiquitousKeyValueStore.default
        self.firstName = kvs.string(forKey: "userFirstName") ?? UserDefaults.standard.string(forKey: "userFirstName") ?? ""
        self.lastName = kvs.string(forKey: "userLastName") ?? UserDefaults.standard.string(forKey: "userLastName") ?? ""
        
        super.init()
        guard prepareServices else { setupObservers(); return }

        // Initial Theme Pull
        self.currentThemeID = kvs.string(forKey: "themeID") ?? UserDefaults.standard.string(forKey: "themeID") ?? "gold"

        self.profileImageData = loadProfileImageFromDisk()
        
        checkPermissions()
        checkNotificationStatus()
        setupObservers()
        
        Task {
            await checkImageGenerationSupport()
        }
        
        // Listen for iCloud Key-Value changes (Name, Theme)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(iCloudDataDidChange),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: kvs
        )
        kvs.synchronize()
        
        // Listen for App returning to foreground
        NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                checkPermissions()
                checkNotificationStatus()
                await refreshAvailability()
                retryPendingSaves()
                if let newData = loadProfileImageFromDisk(), newData != profileImageData {
                    profileImageData = newData
                }
            }
        }
    }
    
    @objc private func iCloudDataDidChange(notification: Notification) {
        let kvs = NSUbiquitousKeyValueStore.default
        Task { @MainActor in
            let newFirst = kvs.string(forKey: "userFirstName") ?? ""
            if !newFirst.isEmpty && self.firstName != newFirst { self.firstName = newFirst }
            
            let newLast = kvs.string(forKey: "userLastName") ?? ""
            if !newLast.isEmpty && self.lastName != newLast { self.lastName = newLast }
            
            // Sync theme changes pulled from iCloud
            let newTheme = kvs.string(forKey: "themeID") ?? "gold"
            if self.currentThemeID != newTheme { self.currentThemeID = newTheme }
        }
    }
    
    private func setupObservers() {
        audioRecorder.$transcriptionMessage
            .sink { [weak self] in self?.transcriptionNotice = $0 }
            .store(in: &cancellables)
        audioRecorder.$recordingError
            .sink { [weak self] in self?.recordingError = $0 }
            .store(in: &cancellables)
        audioRecorder.$audioLevel
            .receive(on: RunLoop.main)
            .sink { [weak self] level in
                self?.audioPower = level
            }
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
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
            
        audioRecorder.$isPaused
            .receive(on: RunLoop.main)
            .sink { [weak self] paused in
                self?.isPaused = paused
            }
            .store(in: &cancellables)
    }
    
    func checkPermissions() {
        let micStatus = AVAudioApplication.shared.recordPermission
        self.hasMicAccess = (micStatus == .granted)
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
    
    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
    
    func checkNotificationStatus() {
        let center = UNUserNotificationCenter.current()
        Task {
            let settings = await center.notificationSettings()
            let status = settings.authorizationStatus
            await MainActor.run {
                self.hasNotificationAccess = (status == .authorized)
                
                // Trigger native popup on launch if onboarding was skipped via iCloud sync
                if status == .notDetermined && self.isOnboardingComplete {
                    self.requestNotificationAccess()
                }
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
                    self.showNotificationAlert = true
                    self.isReminderEnabled = false // Revert toggle if denied
                }
            } else if status == .notDetermined {
                do {
                    let granted = try await center.requestAuthorization(options: [.alert, .sound])
                    await MainActor.run {
                        self.hasNotificationAccess = granted
                        if granted && self.isReminderEnabled {
                            self.scheduleDailyReminder()
                        } else if !granted {
                            self.isReminderEnabled = false // Revert toggle if denied during native prompt
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
                } else {
                    Task { @MainActor in
                        self.showNotificationAlert = true
                        self.isReminderEnabled = false
                    }
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
        
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["dailyDreamReminder"])
        UNUserNotificationCenter.current().add(request)
    }
    
    // MARK: - iCloud Drive Ubiquity Container Fetch
    private func getDocumentsDirectory() -> URL {
        // Automatically checks if iCloud Drive is available and routes storage to the synced container
        if let icloudURL = FileManager.default.url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent("Documents") {
            if !FileManager.default.fileExists(atPath: icloudURL.path) {
                try? FileManager.default.createDirectory(at: icloudURL, withIntermediateDirectories: true, attributes: nil)
            }
            return icloudURL
        }
        
        // Fallback to local sandbox if iCloud is disabled
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    var storageUsageString: String {
        let fileManager = FileManager.default
        let docDir = getDocumentsDirectory()
        
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
            try? data.write(to: url, options: .atomic)
        } else {
            try? FileManager.default.removeItem(at: url)
        }
    }
    
    private func loadProfileImageFromDisk() -> Data? {
        let url = getDocumentsDirectory().appendingPathComponent("profile_image.png")
        return try? Data(contentsOf: url)
    }
    
    // MARK: - SwiftData CloudKit Fetching
    func setContext(_ context: ModelContext) {
        self.modelContext = context
        fetchAllData()
        recoverUnsavedDreams()
        resolvePendingDreamIntent()
    }
    
    func fetchAllData() {
        guard let context = modelContext else { return }
        do {
            let descriptor = FetchDescriptor<SavedDream>(sortBy: [SortDescriptor(\.date, order: .reverse)])
            let savedDreams = try context.fetch(descriptor)
            let unsaved = dreams.filter { unsavedDreamIDs.contains($0.id) }
            self.dreams = savedDreams.filter { !unsavedDreamIDs.contains($0.id) }.map { Dream(from: $0) } + unsaved
            self.dreams.sort { $0.date > $1.date }
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
    
    func updateEntity(name: String, type: String, description: String, image: Data?, contactId: String? = nil, linkedPlace: LinkedPlace? = nil) {
        let id = "\(type):\(name)"
        pendingEntityUpdates[id] = PendingEntityUpdate(name: name, type: type, details: description, image: image, contactID: contactId, place: linkedPlace)
        guard let context = modelContext else {
            persistenceError = "Profile changes are waiting to save. Keep Dorsal open and retry saving."
            return
        }
        do {
            let descriptor = FetchDescriptor<SavedEntity>(predicate: #Predicate { $0.id == id })
            if let existing = try context.fetch(descriptor).first {
                existing.details = description
                existing.imageData = image
                existing.contactId = contactId
                existing.linkedPlaceData = try linkedPlace.map { try JSONEncoder().encode($0) }
                existing.lastUpdated = Date()
            } else {
                let newEntity = SavedEntity(name: name, type: type, details: description, imageData: image)
                newEntity.contactId = contactId
                newEntity.linkedPlaceData = try linkedPlace.map { try JSONEncoder().encode($0) }
                context.insert(newEntity)
            }
            try context.save()
            pendingEntityUpdates.removeValue(forKey: id)
            if pendingEntityUpdates.isEmpty && unsavedDreamIDs.isEmpty { persistenceError = nil }
            self.entityUpdateTrigger += 1
        } catch {
            context.rollback()
            persistenceError = "Profile changes couldn’t be saved. They are kept in memory; keep Dorsal open and retry saving."
        }
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
            pendingEntityUpdates.removeValue(forKey: id)
            self.entityUpdateTrigger += 1
        } catch { print("Entity Delete Error: \(error)") }
    }
    
    func checkImageGenerationSupport() async {
        await ImageGenerationService.shared.checkAvailability()
        isImageGenerationAvailable = await ImageGenerationService.shared.isAvailable
    }

    func generateImageFromPrompt(prompt: String, places: [String] = [], emotions: [String] = [], profileImageData: Data? = nil) async throws -> Data {
        // Recheck at the point of use: a failed launch-time probe isn't permanent.
        return try await ImageGenerationService.shared.generate(prompt: prompt, places: places, emotions: emotions, profileImageData: profileImageData)
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
    private var linkedPeople: [String] {
        guard let modelContext else { return [] }
        let descriptor = FetchDescriptor<SavedEntity>(predicate: #Predicate { $0.type == "person" && $0.contactId != nil })
        return ((try? modelContext.fetch(descriptor)) ?? []).map(\.name).sorted()
    }
    private var analysisPeople: [String] {
        Array((linkedPeople + allPeople).reduce(into: [String]()) { result, name in
            if !result.contains(where: { $0.localizedCaseInsensitiveCompare(name) == .orderedSame }) { result.append(name) }
        }.prefix(12))
    }
    private var analysisPlaces: [String] { Array(allPlaces.prefix(12)) }
    var allEmotions: [String] { Array(Set(dreams.flatMap { $0.core?.emotions ?? [] })).sorted() }
    var allTags: [String] { getRootEntities(type: "tag").map { $0.name } }
    
    func getRecommendations(for item: ChecklistItem) -> [String] {
        if let cached = recommendationCache[item.id] { return cached }
        
        let recs: [String] = switch item.contextType {
        case "person":
            Array(Set(dreams.flatMap { $0.core?.people ?? [] })) + ["My Mom", "A Friend", "Stranger"]
        case "place":
            Array(Set(dreams.flatMap { $0.core?.places ?? [] })) + ["Home", "School", "Work"]
        case "emotion":
            Array(Set(dreams.flatMap { $0.core?.emotions ?? [] })) + ["Scared", "Happy", "Confused"]
        case "duration":
            ["A few minutes", "An hour", "Felt like forever"]
        case "context":
            ["Watched a movie", "Work", "A conversation"]
        default:
            []
        }
        
        // Remove duplicates case-insensitively while preserving the original array order
        var seen = Set<String>()
        let final = recs.filter { seen.insert($0.lowercased()).inserted }
        
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
            let embeddingRef = self.embedding
            
            Task.detached(priority: .userInitiated) { [weak self] in
                let tagger = NLTagger(tagSchemes: [.tokenType])
                let words = transcriptSnapshot.split(separator: " ")
                let recentText = words.suffix(15).joined(separator: " ")
                tagger.string = recentText
                
                for question in unansweredQuestions {
                    var isSatisfied = false
                    
                    if question.keywords.contains(where: { transcriptLower.contains($0.lowercased()) }) {
                        isSatisfied = true
                    }
                    else if let embedding = embeddingRef {
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
                            self?.handleSatisfiedQuestion(questionID: question.id)
                        }
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
        guard let context = modelContext else { return }
        do {
            let id = dream.id
            let descriptor = FetchDescriptor<SavedDream>(predicate: #Predicate { $0.id == id })
            for saved in try context.fetch(descriptor) { context.delete(saved) }
            try context.save()
            try recoveryStore.remove(id)
            if currentDreamID == id { currentAnalysisTask?.cancel() }
            dreams.removeAll { $0.id == id }
            unsavedDreamIDs.remove(id)
            if let url = RecordingFiles.url(for: dream.recordingFileName) { try? FileManager.default.removeItem(at: url) }
        } catch {
            context.rollback()
            persistenceError = "The dream couldn’t be deleted. Your entry has been kept; please try again."
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
            persistDream(dreams[index])
        }
    }

    func startRecording() {
        guard !isRecording, !recordingIsBusy, !isProcessing, transcribingDreamID == nil else { return }
        isStartingRecording = true
        recordingError = nil
        Task {
            defer { isStartingRecording = false }
            if AVAudioApplication.shared.recordPermission == .undetermined {
                hasMicAccess = await AVAudioApplication.requestRecordPermission()
            } else {
                checkPermissions()
            }
            guard hasMicAccess else { showPermissionAlert = true; return }
            currentTranscript = ""
            answeredQuestions = []
            isQuestionSatisfied = false
            recommendationCache = [:]
            activeQuestion = questions.first
            do {
                try await audioRecorder.startRecording(keywords: questions.flatMap { $0.keywords })
                withAnimation { isRecording = true; isPaused = false }
            } catch {
                recordingError = (error as? LiveAudioRecorder.RecordingError)?.localizedDescription
                    ?? "Recording couldn’t start. Check your microphone connection and available storage, then try again."
            }
        }
    }

    func pauseRecording() { audioRecorder.pauseRecording() }
    func resumeRecording() { audioRecorder.resumeRecording() }

    func stopRecording(save: Bool) {
        guard isRecording, !isFinishingRecording else { return }
        isFinishingRecording = true
        Task {
            let result = await audioRecorder.stopRecording(discard: !save)
            withAnimation { isRecording = false; isPaused = false }
            isFinishingRecording = false
            guard save, let result else { currentTranscript = ""; return }
            currentTranscript = result.transcript
            processDream(transcript: result.transcript, audioURL: result.url,
                         transcriptionMessage: result.transcriptionMessage)
            if result.audioWriteFailed {
                recordingError = "Some audio couldn’t be saved. Any recognized text has been kept. Check your device’s available storage."
            }
        }
    }

    private func processDream(transcript: String, audioURL: URL, transcriptionMessage: String?) {
        currentAnalysisTask?.cancel()
        
        isProcessing = true
        let newID = UUID()
        currentDreamID = newID
        
        var newDream = Dream(id: newID, rawTranscript: transcript)
        newDream.recordingFileName = audioURL.lastPathComponent
        newDream.transcriptionError = transcriptionMessage
        newDream.needsTranscription = transcript.isEmpty || transcriptionMessage != nil
        newDream.needsAnalysis = true
        dreams.insert(newDream, at: 0)
        
        persistDream(newDream)
        
        selectedTab = 1
        navigationPath = NavigationPath()
        navigationPath.append(newDream)
        
        if transcript.isEmpty {
            isProcessing = false
        } else {
            runAnalysis(for: newID, transcript: transcript, audioURL: audioURL, existingFatigue: nil)
        }
    }
    
    func regenerateDream(_ dream: Dream) {
        guard !isProcessing, !isRecording, !recordingIsBusy, transcribingDreamID == nil else { return }
        guard !dream.rawTranscript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        currentAnalysisTask?.cancel()
        
        guard let index = dreams.firstIndex(where: { $0.id == dream.id }) else { return }
        
        isProcessing = true
        currentDreamID = dream.id
        
        let existingFatigue = dreams[index].voiceFatigue
        
        // Keep the last successful analysis and illustration if a retry fails.
        dreams[index].analysisError = nil
        dreams[index].needsAnalysis = true
        
        dreams[index].voiceFatigue = existingFatigue
        
        persistDream(dreams[index])
        
        runAnalysis(for: dream.id, transcript: dream.rawTranscript,
                    audioURL: RecordingFiles.url(for: dream.recordingFileName), existingFatigue: existingFatigue)
    }

    func keepCreatedImage(for dream: Dream, from url: URL) {
        guard let index = dreams.firstIndex(where: { $0.id == dream.id }) else { return }
        do {
            let data = try Data(contentsOf: url)
            guard UIImage(data: data) != nil else { throw DreamError.imageGenerationFailed }
            withAnimation(.easeInOut(duration: 0.5)) {
                dreams[index].generatedImageData = data
                dreams[index].imageError = nil
            }
            persistDream(dreams[index])
        } catch {
            dreams[index].imageError = "The illustration couldn’t be saved. Your previous image and dream are still available."
        }
    }

    func regenerateDreamImage(_ dream: Dream) {
        guard !isProcessing, !isRecording, !recordingIsBusy, transcribingDreamID == nil else { return }
        guard let index = dreams.firstIndex(where: { $0.id == dream.id }) else { return }
        isProcessing = true
        currentDreamID = dream.id
        dreams[index].imageError = nil
        currentAnalysisTask = Task {
            defer { isProcessing = false }
            do {
                // An existing summary is enough to retry the picture independently of text AI.
                let prompt = dream.core?.summary ?? dream.rawTranscript
                let data = try await generateImageFromPrompt(prompt: prompt, places: dream.places, emotions: dream.emotions)
                try Task.checkCancellation()
                if let idx = dreams.firstIndex(where: { $0.id == dream.id }) {
                    dreams[idx].generatedImageData = data
                    dreams[idx].imageError = nil
                    persistDream(dreams[idx])
                }
            } catch {
                guard !Task.isCancelled, !DreamFailure.isCancellation(error) else { return }
                if let idx = dreams.firstIndex(where: { $0.id == dream.id }) {
                    dreams[idx].imageError = DreamFailure.imageMessage(for: error)
                    persistDream(dreams[idx])
                }
            }
            await checkImageGenerationSupport()
        }
    }

    func retryTranscription(_ dream: Dream) {
        guard !isProcessing, !isRecording, !recordingIsBusy, transcribingDreamID == nil else { return }
        guard let url = RecordingFiles.url(for: dream.recordingFileName) else {
            if let index = dreams.firstIndex(where: { $0.id == dream.id }) {
                dreams[index].transcriptionError = "The original audio isn’t available on this device. Any existing transcript is still available."
                persistDream(dreams[index])
            }
            return
        }
        transcribingDreamID = dream.id
        Task {
            defer { transcribingDreamID = nil }
            do {
                let text = try await audioRecorder.transcribeFile(at: url)
                guard let index = dreams.firstIndex(where: { $0.id == dream.id }) else { return }
                dreams[index].rawTranscript = text
                dreams[index].transcriptionError = nil
                dreams[index].needsTranscription = false
                dreams[index].needsAnalysis = true
                persistDream(dreams[index])
                isProcessing = true
                currentDreamID = dream.id
                runAnalysis(for: dream.id, transcript: text, audioURL: url, existingFatigue: dreams[index].voiceFatigue)
            } catch {
                if let index = dreams.firstIndex(where: { $0.id == dream.id }) {
                    dreams[index].transcriptionError = (error as? LiveAudioRecorder.RecordingError)?.localizedDescription
                        ?? "Transcription couldn’t finish. Your audio and any existing transcript are still available. Please try again."
                    persistDream(dreams[index])
                }
            }
        }
    }

    private func runAnalysis(for dreamID: UUID, transcript: String, audioURL: URL?, existingFatigue: Int?) {
        currentAnalysisTask = Task {
            defer { isProcessing = false; isAnalyzingFatigue = false }
            analysisAvailability = availabilityProvider()
            guard analysisAvailability == .available else {
                if let index = dreams.firstIndex(where: { $0.id == dreamID }) {
                    dreams[index].analysisError = analysisAvailability.message
                    dreams[index].needsAnalysis = true
                    persistDream(dreams[index])
                }
                return
            }
            let previousCore = dreams.first(where: { $0.id == dreamID })?.core
            let previousExtras = dreams.first(where: { $0.id == dreamID })?.extras
            do {
                let workingTranscript = try await DreamAnalyzer.shared.prepareAnalysisTranscript(transcript)
                var generatedCore = DreamCoreAnalysis()
                let knownPeople = analysisPeople
                let knownPlaces = analysisPlaces
                for try await partialCore in await DreamAnalyzer.shared.streamCore(transcript: workingTranscript, userName: self.firstName, knownPeople: knownPeople, knownPlaces: knownPlaces) {
                    if Task.isCancelled { return }
                    
                    if let index = dreams.firstIndex(where: { $0.id == dreamID }) {
                        var currentCore = generatedCore
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
                        generatedCore = currentCore
                        if previousCore == nil { dreams[index].core = currentCore }
                    }
                }
                
                var repairedCore = await DreamAnalyzer.shared.ensureCoreFields(current: generatedCore, transcript: workingTranscript)
                repairedCore.people = DreamEntityCanonicalizer.canonicalize(repairedCore.people ?? [], linkedNames: linkedPeople, historicalNames: knownPeople)
                repairedCore.places = DreamEntityCanonicalizer.canonicalize(repairedCore.places ?? [], linkedNames: [], historicalNames: knownPlaces)
                try Task.checkCancellation()
                if let index = dreams.firstIndex(where: { $0.id == dreamID }) {
                    dreams[index].core = repairedCore
                    persistDream(dreams[index])
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
                        fatigueScore = await DreamAnalyzer.shared.estimateFallbackFatigue(transcript: workingTranscript)
                    }
                } else {
                    fatigueScore = await DreamAnalyzer.shared.estimateFallbackFatigue(transcript: workingTranscript)
                }

                await MainActor.run {
                    if let index = dreams.firstIndex(where: { $0.id == dreamID }) {
                        dreams[index].voiceFatigue = fatigueScore
                        persistDream(dreams[index])
                    }
                    withAnimation { self.isAnalyzingFatigue = false }
                }
                
                await checkImageGenerationSupport()
                if let index = dreams.firstIndex(where: { $0.id == dreamID }),
                   let _ = dreams[index].core?.summary {
                    if isImageGenerationAvailable && dreams[index].generatedImageData == nil {
                        do {
                            let places = dreams[index].core?.places ?? []
                            let emotions = dreams[index].core?.emotions ?? []
                            let hasUsableProfileImage = profileImageData.flatMap(UIImage.init(data:))?.cgImage != nil
                            let includeProfile = imageIncludeMyself && hasUsableProfileImage
                            let sanitizedPrompt = try await DreamAnalyzer.shared.generateVisualPrompt(transcript: workingTranscript, allowsCharacters: includeProfile, includeMyself: includeProfile)
                            try Task.checkCancellation()
                            
                            let data = try await generateImageFromPrompt(prompt: sanitizedPrompt, places: places, emotions: emotions, profileImageData: includeProfile ? profileImageData : nil)
                            
                            await MainActor.run {
                                if let idx = dreams.firstIndex(where: { $0.id == dreamID }) {
                                    dreams[idx].generatedImageData = data
                                    dreams[idx].imageError = nil
                                }
                            }
                        } catch {
                            print("Image generation error: \(error)")
                            await MainActor.run {
                                if let idx = dreams.firstIndex(where: { $0.id == dreamID }) {
                                    if !DreamFailure.isCancellation(error) {
                                        dreams[idx].imageError = DreamFailure.imageMessage(for: error)
                                    }
                                    persistDream(dreams[idx])
                                }
                            }
                        }
                    }
                }
                
                var generatedExtras = DreamExtraAnalysis()
                for try await partialExtra in await DreamAnalyzer.shared.streamExtras(transcript: workingTranscript) {
                    if Task.isCancelled { return }
                    
                    if let index = dreams.firstIndex(where: { $0.id == dreamID }) {
                        var currentExtras = generatedExtras
                        if let s = partialExtra.sentimentScore { currentExtras.sentimentScore = s }
                        if let nm = partialExtra.isNightmare { currentExtras.isNightmare = nm }
                        if let l = partialExtra.lucidityScore { currentExtras.lucidityScore = l }
                        if let v = partialExtra.vividnessScore { currentExtras.vividnessScore = v }
                        if let c = partialExtra.coherenceScore { currentExtras.coherenceScore = c }
                        if let a = partialExtra.anxietyLevel { currentExtras.anxietyLevel = a }
                        generatedExtras = currentExtras
                        if previousExtras == nil { dreams[index].extras = currentExtras }
                    }
                }
                
                let repairedExtras = await DreamAnalyzer.shared.ensureExtraFields(current: generatedExtras, transcript: workingTranscript)
                try Task.checkCancellation()
                if let index = dreams.firstIndex(where: { $0.id == dreamID }) { dreams[index].extras = repairedExtras }
                
                if let index = dreams.firstIndex(where: { $0.id == dreamID }) {
                    dreams[index].analysisError = nil
                    dreams[index].needsAnalysis = false
                    persistDream(dreams[index])
                }
                
                isProcessing = false
                isAnalyzingFatigue = false
                Task { await refreshWeeklyInsights() }
                
            } catch {
                if Task.isCancelled { return }
                print("Analysis failed: \(error)")
                
                if let index = dreams.firstIndex(where: { $0.id == dreamID }) {
                    dreams[index].analysisError = DreamFailure.analysisMessage(for: error)
                    dreams[index].needsAnalysis = true
                    persistDream(dreams[index])
                }
                
                isProcessing = false
                isAnalyzingFatigue = false
            }
        }
    }
    
    @discardableResult
    func persistDream(_ dream: Dream) -> Bool {
        unsavedDreamIDs.insert(dream.id)
        var hasRecoveryCopy = false
        do { try recoveryStore.write(dream); hasRecoveryCopy = true }
        catch { print("Recovery copy failed: \(error)") }
        do {
            guard let context = modelContext else {
                throw NSError(domain: "Dorsal.Persistence", code: 1, userInfo: [NSLocalizedDescriptionKey: "The journal is not open yet."])
            }
            try DreamPersistence.save(dream, in: context) { try context.save() }
            // A cleanup failure does not mean the committed journal entry failed to save.
            do { try recoveryStore.remove(dream.id) }
            catch { print("Recovery cleanup deferred: \(error)") }
            unsavedDreamIDs.remove(dream.id)
            if unsavedDreamIDs.isEmpty && pendingEntityUpdates.isEmpty { persistenceError = nil }
            return true
        } catch {
            print("Dream save failed: \(error)")
            persistenceError = hasRecoveryCopy
                ? "The journal couldn’t finish saving. A recovery copy is kept on this device. Retry saving."
                : "Your latest changes couldn’t be saved. Keep Dorsal open, check available storage, and retry saving."
            return false
        }
    }

    func retryPendingSaves() {
        for dream in dreams where unsavedDreamIDs.contains(dream.id) { persistDream(dream) }
        for update in Array(pendingEntityUpdates.values) {
            updateEntity(name: update.name, type: update.type, description: update.details, image: update.image,
                         contactId: update.contactID, linkedPlace: update.place)
        }
    }

    private func recoverUnsavedDreams() {
        do {
            for recovered in try recoveryStore.load() {
                if let index = dreams.firstIndex(where: { $0.id == recovered.id }) { dreams[index] = recovered }
                else { dreams.append(recovered) }
                persistDream(recovered)
            }
            dreams.sort { $0.date > $1.date }
        } catch {
            persistenceError = "A recovery copy couldn’t be opened. The original files have been kept on this device."
        }
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
            
            let insights = try await DreamAnalyzer.shared.analyzeWeeklyTrendsWithContext(dreams: recentDreams, userName: self.firstName, searcher: self)
            self.weeklyInsight = insights
            persistInsight(insights)
        } catch { print("Insights error: \(error)") }
        withAnimation { isGeneratingInsights = false }
    }
}

// MARK: - DreamSearchable Conformance (Foundation Models Tool Calling)
extension DreamStore: DreamSearchable {
    func sleepSummary(for date: Date) async throws -> SleepSummary? {
        guard usesSleepData else { return nil }
        let summary = try await SleepDataManager.shared.fetchSleepForDate(date)
        guard usesSleepData else { return nil }
        return summary
    }

    nonisolated func searchDreams(query: String, limit: Int) async -> [DreamSearchResult] {
        let allDreams = await MainActor.run { self.dreams }
        let lowerQuery = String(query.trimmingCharacters(in: .whitespacesAndNewlines).prefix(120)).lowercased()
        guard !lowerQuery.isEmpty else { return [] }
        
        let matches = allDreams.filter { dream in
            let text = dream.rawTranscript.lowercased()
            let title = dream.core?.title?.lowercased() ?? ""
            let summary = dream.core?.summary?.lowercased() ?? ""
            let tags = dream.keyEntities.map { $0.lowercased() } + dream.emotions.map { $0.lowercased() } + dream.people.map { $0.lowercased() } + dream.places.map { $0.lowercased() }
            
            return text.contains(lowerQuery) || title.contains(lowerQuery) || summary.contains(lowerQuery) || tags.contains { $0.contains(lowerQuery) }
        }.sorted { $0.date > $1.date }.prefix(min(6, max(1, limit)))
        
        return matches.map { dream in
            DreamSearchResult(
                date: dream.date,
                title: dream.core?.title ?? "Untitled",
                summary: dream.core?.summary ?? "No summary available.",
                people: dream.people,
                places: dream.places,
                emotions: dream.emotions,
                symbols: dream.keyEntities,
                sentimentScore: dream.extras?.sentimentScore,
                anxietyLevel: dream.extras?.anxietyLevel,
                vividnessScore: dream.extras?.vividnessScore,
                lucidityScore: dream.extras?.lucidityScore
            )
        }
    }
    
    nonisolated func fetchMetricHistory(metric: String, days: Int) async -> [MetricDataPoint] {
        let allDreams = await MainActor.run { self.dreams }
        let cutoff = Calendar.current.date(byAdding: .day, value: -min(365, max(1, days)), to: Date()) ?? Date()
        
        let recentDreams = allDreams.filter { $0.date >= cutoff }.sorted { $0.date < $1.date }
        
        return recentDreams.compactMap { dream in
            let score: Int?
            switch metric.lowercased() {
            case "anxiety": score = dream.extras?.anxietyLevel
            case "sentiment": score = dream.extras?.sentimentScore
            case "lucidity": score = dream.extras?.lucidityScore
            case "vividness": score = dream.extras?.vividnessScore
            case "coherence": score = dream.extras?.coherenceScore
            case "fatigue": score = dream.voiceFatigue
            default: score = nil
            }
            
            guard let finalScore = score else { return nil }
            return MetricDataPoint(date: dream.date, score: finalScore)
        }
    }
}
