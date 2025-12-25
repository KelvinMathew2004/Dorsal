import SwiftUI
import AVFoundation
import ImagePlayground
import FoundationModels

// Filter State Model
struct DreamFilter: Equatable {
    var people: Set<String> = []
    var places: Set<String> = []
    var emotions: Set<String> = []
    var tags: Set<String> = []
    
    var isEmpty: Bool {
        people.isEmpty && places.isEmpty && emotions.isEmpty && tags.isEmpty
    }
}

@MainActor
class DreamStore: NSObject, ObservableObject {
    @Published var dreams: [Dream] = []
    
    // Filtering & Search
    @Published var searchQuery: String = ""
    @Published var activeFilter = DreamFilter()
    
    // New: Weekly Insights
    @Published var weeklyInsight: WeeklyInsightResult?
    @Published var isGeneratingInsights: Bool = false
    
    // UI State
    @Published var selectedTab: Int = 0
    @Published var navigationPath = NavigationPath()
    @Published var isProcessing: Bool = false
    @Published var permissionError: String?
    @Published var showPermissionAlert: Bool = false
    
    // Recorder State
    @Published var currentTranscript: String = ""
    @Published var isRecording: Bool = false
    @Published var isPaused: Bool = false
    @Published var audioPower: Float = 0.0
    
    // Mock Data Helpers
    private var mockTimer: Timer?
    private var mockIndex = 0
    
    // Interactive Questions (for RecordView)
    @Published var activeQuestion: ChecklistItem?
    @Published var isQuestionSatisfied: Bool = false
    struct ChecklistItem: Identifiable, Hashable {
        let id = UUID(); let question: String; let keywords: [String]
    }
    
    override init() {
        super.init()
        loadDreams()
    }
    
    // MARK: - COMPUTED PROPERTIES FOR VIEWS
    
    var filteredDreams: [Dream] {
        dreams.filter { dream in
            // Search Text
            let matchesSearch = searchQuery.isEmpty ||
                dream.rawTranscript.localizedCaseInsensitiveContains(searchQuery) ||
                dream.analysis.title.localizedCaseInsensitiveContains(searchQuery) ||
                dream.analysis.summary.localizedCaseInsensitiveContains(searchQuery)
            
            if !matchesSearch { return false }
            
            // Filters
            if !activeFilter.people.isEmpty && !activeFilter.people.isSubset(of: Set(dream.analysis.people)) { return false }
            if !activeFilter.places.isEmpty && !activeFilter.places.isSubset(of: Set(dream.analysis.places)) { return false }
            if !activeFilter.emotions.isEmpty && !activeFilter.emotions.isSubset(of: Set(dream.analysis.emotions)) { return false }
            if !activeFilter.tags.isEmpty && !activeFilter.tags.isSubset(of: Set(dream.analysis.symbols)) { return false }
            
            return true
        }
    }
    
    var allPeople: [String] {
        Array(Set(dreams.flatMap { $0.analysis.people })).sorted()
    }
    var allPlaces: [String] {
        Array(Set(dreams.flatMap { $0.analysis.places })).sorted()
    }
    var allEmotions: [String] {
        Array(Set(dreams.flatMap { $0.analysis.emotions })).sorted()
    }
    var allTags: [String] {
        Array(Set(dreams.flatMap { $0.analysis.symbols })).sorted()
    }
    
    // MARK: - INTENTS
    
    func deleteDream(_ dream: Dream) {
        if let index = dreams.firstIndex(where: { $0.id == dream.id }) {
            dreams.remove(at: index)
            saveToDisk()
        }
    }
    
    func togglePersonFilter(_ item: String) {
        if activeFilter.people.contains(item) { activeFilter.people.remove(item) } else { activeFilter.people.insert(item) }
    }
    func togglePlaceFilter(_ item: String) {
        if activeFilter.places.contains(item) { activeFilter.places.remove(item) } else { activeFilter.places.insert(item) }
    }
    func toggleEmotionFilter(_ item: String) {
        if activeFilter.emotions.contains(item) { activeFilter.emotions.remove(item) } else { activeFilter.emotions.insert(item) }
    }
    func toggleTagFilter(_ item: String) {
        if activeFilter.tags.contains(item) { activeFilter.tags.remove(item) } else { activeFilter.tags.insert(item) }
    }
    func clearFilter() {
        activeFilter = DreamFilter()
    }
    func jumpToFilter(type: String, value: String) {
        clearFilter()
        switch type {
        case "person": activeFilter.people.insert(value)
        case "place": activeFilter.places.insert(value)
        case "emotion": activeFilter.emotions.insert(value)
        case "tag": activeFilter.tags.insert(value)
        default: break
        }
        selectedTab = 1 // Jump to Journal
    }
    
    // MARK: - RECORDING (MOCK)
    func startRecording() {
        withAnimation { isRecording = true; isPaused = false }
        currentTranscript = ""
        // Mock logic...
        mockTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.audioPower = Float.random(in: 0.1...0.8)
            self.currentTranscript += " dream word"
        }
    }
    func stopRecording(save: Bool) {
        mockTimer?.invalidate()
        withAnimation { isRecording = false; isPaused = false }
        if save && !currentTranscript.isEmpty {
            processDream(transcript: currentTranscript)
        }
        currentTranscript = ""
    }
    func pauseRecording() {
        withAnimation { isPaused.toggle() }
    }
    func openSettings() {}
    func getRecommendations(for item: ChecklistItem) -> [String] { [] }

    
    // MARK: - PROCESSING PIPELINE
    
    private func processDream(transcript: String) {
        Task {
            isProcessing = true
            
            do {
                // 1. Foundation Models Analysis
                let analysis = try await DreamAnalyzer.shared.analyze(transcript: transcript)
                
                // 2. Image Generation
                var generatedImageData: Data?
                let creator = try await ImageCreator()
                let concepts: [ImagePlaygroundConcept] = [.text(analysis.imagePrompt)]
                let imageStream = creator.images(for: concepts, style: .illustration, limit: 1)
                
                for try await image in imageStream {
                    // Correct for iOS 18.4: image.cgImage is non-optional
                    let cgImage = image.cgImage
                    let uiImage = UIImage(cgImage: cgImage)
                    if let pngData = uiImage.pngData() {
                        generatedImageData = pngData
                        break
                    }
                }
                
                // 3. Create Model
                let newDream = Dream(
                    rawTranscript: transcript,
                    analysis: analysis,
                    generatedImageData: generatedImageData
                )
                
                // 4. Save
                dreams.insert(newDream, at: 0)
                saveToDisk()
                
                // 5. Trigger Insights Update
                Task { await refreshWeeklyInsights() }
                
                isProcessing = false
                selectedTab = 1 // Switch to Journal
                navigationPath = NavigationPath()
                navigationPath.append(newDream)
                
            } catch {
                print("Error processing dream: \(error)")
                isProcessing = false
            }
        }
    }
    
    // MARK: - INSIGHTS GENERATION
    
    func refreshWeeklyInsights() async {
        guard !dreams.isEmpty else { return }
        withAnimation { isGeneratingInsights = true }
        do {
            let recentDreams = dreams.filter { $0.date > Date().addingTimeInterval(-30*24*60*60) }
            guard !recentDreams.isEmpty else { isGeneratingInsights = false; return }
            
            let insights = try await DreamAnalyzer.shared.analyzeWeeklyTrends(dreams: recentDreams)
            self.weeklyInsight = insights
        } catch {
            print("Failed to generate insights: \(error)")
        }
        withAnimation { isGeneratingInsights = false }
    }
    
    // MARK: - PERSISTENCE
    private var fileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("dreams_v2.json")
    }
    
    private func loadDreams() {
        if let data = try? Data(contentsOf: fileURL),
           let saved = try? JSONDecoder().decode([Dream].self, from: data) {
            self.dreams = saved
        }
    }
    
    private func saveToDisk() {
        if let data = try? JSONEncoder().encode(dreams) {
            try? data.write(to: fileURL)
        }
    }
}
