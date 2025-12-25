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
    
    // Interactive Questions
    @Published var activeQuestion: ChecklistItem?
    @Published var isQuestionSatisfied: Bool = false
    @Published var answeredQuestions: Set<UUID> = []
    
    // Cache for recommendations to prevent UI flickering
    private var recommendationCache: [UUID: [String]] = [:]
    
    struct ChecklistItem: Identifiable, Hashable {
        let id = UUID()
        let question: String
        let keywords: [String] // Keywords to detect answer
        let contextType: String // "person", "place", "emotion"
    }
    
    // Define the question flow
    private let questions: [ChecklistItem] = [
        ChecklistItem(question: "Who was in the dream with you?", keywords: ["mom", "dad", "friend", "brother", "sister", "he", "she", "they", "someone", "person", "man", "woman", "grandma", "grandpa", "teacher", "celebrity", "bear", "octopus", "librarian", "no one", "taylor", "dad"], contextType: "person"),
        ChecklistItem(question: "Where did it take place?", keywords: ["home", "school", "work", "outside", "inside", "room", "forest", "city", "water", "place", "house", "building", "kitchen", "hallway", "mountain", "underwater", "library", "party", "car", "downtown"], contextType: "place"),
        ChecklistItem(question: "How did you feel?", keywords: ["happy", "sad", "scared", "anxious", "excited", "confused", "calm", "angry", "felt", "feeling", "joyful", "terrified", "empowered", "lonely", "relief", "curious", "starstruck"], contextType: "emotion")
    ]
    
    // Debounce timer for question state updates
    private var updateStateTask: Task<Void, Never>?
    
    override init() {
        super.init()
        loadDreams()
    }
    
    // MARK: - COMPUTED PROPERTIES FOR VIEWS
    var filteredDreams: [Dream] {
        dreams.filter { dream in
            let matchesSearch = searchQuery.isEmpty ||
                dream.rawTranscript.localizedCaseInsensitiveContains(searchQuery) ||
                dream.analysis.title.localizedCaseInsensitiveContains(searchQuery) ||
                dream.analysis.summary.localizedCaseInsensitiveContains(searchQuery)
            
            if !matchesSearch { return false }
            
            if !activeFilter.people.isEmpty && !activeFilter.people.isSubset(of: Set(dream.analysis.people)) { return false }
            if !activeFilter.places.isEmpty && !activeFilter.places.isSubset(of: Set(dream.analysis.places)) { return false }
            if !activeFilter.emotions.isEmpty && !activeFilter.emotions.isSubset(of: Set(dream.analysis.emotions)) { return false }
            if !activeFilter.tags.isEmpty && !activeFilter.tags.isSubset(of: Set(dream.analysis.symbols)) { return false }
            
            return true
        }
    }
    
    var allPeople: [String] { Array(Set(dreams.flatMap { $0.analysis.people })).sorted() }
    var allPlaces: [String] { Array(Set(dreams.flatMap { $0.analysis.places })).sorted() }
    var allEmotions: [String] { Array(Set(dreams.flatMap { $0.analysis.emotions })).sorted() }
    var allTags: [String] { Array(Set(dreams.flatMap { $0.analysis.symbols })).sorted() }
    
    // MARK: - RECOMMENDATIONS
    func getRecommendations(for item: ChecklistItem) -> [String] {
        if let cached = recommendationCache[item.id] {
            return cached
        }
        let newRecs = generateRecommendations(for: item)
        recommendationCache[item.id] = newRecs
        return newRecs
    }
    
    private func generateRecommendations(for item: ChecklistItem) -> [String] {
        var recs: [String] = []
        switch item.contextType {
        case "person":
            recs = ["My Mom", "A Friend", "Stranger", "No one"]
            let history = Array(Set(dreams.flatMap { $0.analysis.people })).prefix(3)
            recs.insert(contentsOf: history, at: 0)
        case "place":
            recs = ["Home", "School", "Work", "Unknown"]
            let history = Array(Set(dreams.flatMap { $0.analysis.places })).prefix(3)
            recs.insert(contentsOf: history, at: 0)
        case "emotion":
            recs = ["Scared", "Happy", "Confused", "Calm"]
            let history = Array(Set(dreams.flatMap { $0.analysis.emotions })).prefix(3)
            recs.insert(contentsOf: history, at: 0)
        default: break
        }
        return Array(Set(recs))
    }
    
    // MARK: - LOGIC: QUESTION FLOW
    private func updateQuestionState() {
        // If we are currently in the "Success/Green" state, do NOT process updates.
        // This prevents the transition task from being cancelled by the next timer tick.
        if isQuestionSatisfied { return }
        
        // Cancel previous pending check
        updateStateTask?.cancel()
        
        updateStateTask = Task { @MainActor in
            // Debounce
            try? await Task.sleep(nanoseconds: 100_000_000)
            if Task.isCancelled { return }
            
            // 1. Identify active question (or first unanswered)
            guard let nextQuestion = questions.first(where: { !answeredQuestions.contains($0.id) }) else {
                if activeQuestion != nil {
                    withAnimation {
                        activeQuestion = nil
                        isQuestionSatisfied = true // All done
                    }
                }
                return
            }
            
            // 2. Check content
            let transcriptLower = currentTranscript.lowercased()
            let isSatisfied = nextQuestion.keywords.contains { keyword in
                transcriptLower.contains(keyword.lowercased())
            }
            
            // 3. Update State
            if isSatisfied {
                if activeQuestion?.id == nextQuestion.id {
                    // Start the success sequence
                    // This sets isQuestionSatisfied = true, which BLOCKS further calls to this function
                    // effectively "locking" the state until the transition completes.
                    withAnimation { isQuestionSatisfied = true }
                    
                    // Wait for user to see green
                    try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5s
                    if Task.isCancelled { return }
                    
                    // Move to next
                    withAnimation(.easeInOut(duration: 0.5)) {
                        answeredQuestions.insert(nextQuestion.id)
                        
                        // Find next
                        if let following = questions.first(where: { !answeredQuestions.contains($0.id) }) {
                            activeQuestion = following
                            // Important: Reset satisfaction state AFTER switching question
                            // to allow the new question to appear fresh
                            isQuestionSatisfied = false
                        } else {
                            activeQuestion = nil
                            isQuestionSatisfied = true // Keep "Done" state for listening mode
                        }
                    }
                } else if activeQuestion == nil {
                    // First load or recovery
                    activeQuestion = nextQuestion
                }
            } else {
                // Not satisfied yet, ensure correct question is shown
                if activeQuestion?.id != nextQuestion.id {
                    withAnimation {
                        activeQuestion = nextQuestion
                        isQuestionSatisfied = false
                    }
                }
            }
        }
    }
    
    // MARK: - INTENTS
    func deleteDream(_ dream: Dream) {
        if let index = dreams.firstIndex(where: { $0.id == dream.id }) {
            dreams.remove(at: index)
            saveToDisk()
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
    }
    
    // MARK: - RECORDING (MOCK)
    func startRecording() {
        withAnimation { isRecording = true; isPaused = false }
        currentTranscript = ""
        answeredQuestions = []
        isQuestionSatisfied = false
        recommendationCache = [:]
        
        activeQuestion = questions.first
        
        // Detailed, natural, rambling mock narratives
        let extendedScenarios = [
            "Um... so, I woke up feeling really strange today. In the dream, I was walking through this... dense, foggy forest. (Pause). It felt like... I don't know, like I was searching for something. Then I saw my grandmother sitting on a mushroom. (Pause). She looked exactly like she did when I was a kid. I felt a sense of calm but also confusion. (Pause). Why was she there?",
            
            "Okay, so I was late for an exam I didn't study for. Classic nightmare, right? The classroom was... weirdly enough, underwater. (Pause). Like, I could breathe, but everything was floating. My teacher was a giant octopus. (Pause). Yeah, an octopus with glasses. I felt anxious, just panic rising in my chest. (Pause). I couldn't find my pen.",
            
            "I was flying over a city made of crystal. (Pause). The sun was setting and everything was pink. My best friend was there, flying next to me, handing me a golden key. (Pause). I felt empowered and joyful. (Pause). Like nothing could stop us.",
            
            "It was dark... like pitch black. I was in a long hallway with too many doors. (Pause). I could hear someone whispering... maybe it was a ghost or just a shadow person. (Pause). I felt terrified. (Pause). My heart was pounding so fast I thought I'd wake up.",
            
            "So I was in my kitchen, but it was huge, like a stadium. (Pause). I was baking cookies with... um, Taylor Swift? (Pause). Yeah, just hanging out. She was really nice. I felt happy (Pause) and just... starstruck I guess. The cookies smelled like cinnamon.",
            
            "I was running a marathon, but my legs... they wouldn't move right. (Pause). I was in the city, downtown I think. (Pause). There was no one around, just empty streets. I felt heavy, burdened, and exhausted. (Pause). I just wanted to lie down on the pavement.",
            
            "I was lost in a library... but the books were flying. (Pause). The librarian was shushing me, but she was smiling. (Pause). It smelled like old paper. I felt curious (Pause) and eager to catch one of the books to see what it said.",
            
            "I was driving a car that had no steering wheel. (Pause). We were on a mountain road. (Pause). My dad was in the back seat sleeping. (Pause). I felt out of control, helpless. (Pause). I was screaming but no sound came out.",
            
            "I was at a party where everyone was wearing masks. (Pause). I couldn't find my sister. (Pause). I felt lonely (Pause) in the crowd. The music was too loud and distorting.",
            
            "I was climbing a mountain made of ice cream. (Pause). It was cold but sticky. I saw a snowman waving at me. (Pause). I felt accomplished (Pause) and kinda silly. I ate some of the snow."
        ]
        
        let text = extendedScenarios[mockIndex % extendedScenarios.count]
        mockIndex += 1
        
        let words = text.components(separatedBy: " ")
        var wordIndex = 0
        
        // SLOWED DOWN: 0.6s per word to simulate natural speech pauses/uhms
        mockTimer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                // Don't update if paused
                if self.isPaused { return }
                
                if wordIndex < words.count {
                    let word = words[wordIndex]
                    // If word contains "(Pause)", simulate a longer silence without adding text
                    if word.contains("(Pause)") {
                        self.audioPower = 0.05
                    } else {
                        self.currentTranscript += (self.currentTranscript.isEmpty ? "" : " ") + word
                        self.audioPower = Float.random(in: 0.3...0.7)
                        self.updateQuestionState()
                    }
                    wordIndex += 1
                } else {
                    self.audioPower = 0.1
                    self.updateQuestionState()
                    self.mockTimer?.invalidate()
                }
            }
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

    // MARK: - PROCESSING PIPELINE
    private func processDream(transcript: String) {
        Task {
            isProcessing = true
            do {
                let analysis = try await DreamAnalyzer.shared.analyze(transcript: transcript)
                var generatedImageData: Data?
                if #available(iOS 18.0, *) {
                    let creator = try await ImageCreator()
                    let concepts: [ImagePlaygroundConcept] = [.text(analysis.imagePrompt)]
                    let imageStream = creator.images(for: concepts, style: .illustration, limit: 1)
                    for try await image in imageStream {
                        let cgImage = image.cgImage
                        let uiImage = UIImage(cgImage: cgImage)
                        if let pngData = uiImage.pngData() {
                            generatedImageData = pngData
                            break
                        }
                    }
                }
                
                let newDream = Dream(
                    rawTranscript: transcript,
                    analysis: analysis,
                    generatedImageData: generatedImageData
                )
                dreams.insert(newDream, at: 0)
                saveToDisk()
                Task { await refreshWeeklyInsights() }
                isProcessing = false
                try? await Task.sleep(nanoseconds: 100_000_000)
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
