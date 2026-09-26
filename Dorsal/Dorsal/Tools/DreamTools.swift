import Foundation
import FoundationModels

nonisolated enum DreamContextDate {
    static func string(_ date: Date, timeZone: TimeZone = .current) -> String {
        date.formatted(Date.ISO8601FormatStyle(timeZone: timeZone).year().month().day())
    }
}

actor DreamToolBudget {
    private var remaining = 3
    func consume() throws {
        try Task.checkCancellation()
        guard remaining > 0 else { throw DreamToolError.callLimit }
        remaining -= 1
    }
}

nonisolated enum DreamToolError: Error { case callLimit, contextBudget }

nonisolated enum DreamToolPolicy {
    static func mayFallback(after error: Error) -> Bool {
        guard !(error is CancellationError), !Task.isCancelled else { return false }
        if error is DreamToolError { return true }
        if let failure = error as? LanguageModelSession.ToolCallError {
            return mayFallback(after: failure.underlyingError)
        }
        if #available(iOS 27, *), let failure = error as? LanguageModelError {
            switch failure {
            case .contextSizeExceeded, .unsupportedGenerationGuide, .unsupportedCapability: return true
            default: return false
            }
        }
        if let failure = error as? LanguageModelSession.GenerationError {
            switch failure {
            case .exceededContextWindowSize, .decodingFailure, .unsupportedGuide: return true
            default: return false
            }
        }
        return false
    }
}

struct QueryPastDreamsTool: Tool {
    let name = "queryPastDreams"
    let description = "Search saved dreams for a person, place, symbol, emotion, or theme. Results are excerpts, not a complete journal."
    @Generable struct Arguments {
        @Guide(description: "A specific person, place, symbol, emotion, or theme") var query: String
        @Guide(description: "Maximum matches", .range(1...6)) var limit: Int
    }
    let dreamSearcher: any DreamSearchable
    let budget: DreamToolBudget

    func call(arguments: Arguments) async throws -> String {
        try await budget.consume()
        let query = String(arguments.query.trimmingCharacters(in: .whitespacesAndNewlines).prefix(120))
        guard !query.isEmpty else { return "A specific search term is required." }
        let matches = await dreamSearcher.searchDreams(query: query, limit: min(6, max(1, arguments.limit)))
        try Task.checkCancellation()
        guard !matches.isEmpty else { return "No matching saved dreams were found. This does not establish that the theme never occurred." }
        let lines = matches.prefix(6).map { match in
            "\(DreamContextDate.string(match.date)) | \(match.title.prefix(60)) | \(match.summary.prefix(180))"
        }
        return "Saved dream excerpts (date | title | excerpt):\n" + lines.joined(separator: "\n")
    }
}

struct FetchMetricHistoryTool: Tool {
    let name = "fetchMetricHistory"
    let description = "Read up to 30 recent recorded scores for a dream metric. Missing scores are omitted; these subjective estimates are not medical measurements."
    @Generable enum Metric: String { case anxiety, sentiment, lucidity, vividness, fatigue, coherence }
    @Generable struct Arguments {
        var metric: Metric
        @Guide(description: "Days to look back", .range(7...365)) var daysBack: Int
    }
    let dreamSearcher: any DreamSearchable
    let budget: DreamToolBudget

    func call(arguments: Arguments) async throws -> String {
        try await budget.consume()
        let days = min(365, max(7, arguments.daysBack))
        let history = await dreamSearcher.fetchMetricHistory(metric: arguments.metric.rawValue, days: days)
        try Task.checkCancellation()
        let points = history.suffix(30)
        guard !points.isEmpty else { return "No recorded scores are available for this metric in that period." }
        let text = points.map { "\(DreamContextDate.string($0.date)): \($0.score)" }.joined(separator: ", ")
        return "Latest \(points.count) recorded \(arguments.metric.rawValue) scores within \(days) days (0–100, unknown scores omitted): \(text)"
    }
}

struct FetchSleepContextTool: Tool {
    let name = "fetchSleepContext"
    let description = "Read available Health sleep for one wake-up date, only when the person opted in. No data may mean missing samples or restricted access; never infer denied permission."
    @Generable struct Arguments {
        @Guide(description: "Wake-up date in local YYYY-MM-DD format") var date: String
    }
    let dreamSearcher: any DreamSearchable
    let budget: DreamToolBudget

    func call(arguments: Arguments) async throws -> String {
        try await budget.consume()
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        guard arguments.date.count == 10, let day = formatter.date(from: arguments.date),
              formatter.string(from: day) == arguments.date,
              let end = Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: day),
              let earliest = Calendar.current.date(byAdding: .day, value: -365, to: Date()),
              day >= earliest, day <= Date() else { return "Provide a valid wake-up date within the past year." }
        do {
            guard let summary = try await dreamSearcher.sleepSummary(for: min(end, Date())) else {
                return "No sleep data is available for this date. Do not infer zero sleep or a permission decision."
            }
            try Task.checkCancellation()
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            return "Available recorded sleep; partial coverage is possible. Do not diagnose or infer causation.\n" + String(decoding: try encoder.encode(summary), as: UTF8.self)
        } catch is CancellationError { throw CancellationError() }
        catch { return "Health sleep data is temporarily unavailable. Answer using the other available context." }
    }
}
