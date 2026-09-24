import Foundation

// Results returned from dream search
nonisolated struct DreamSearchResult: Sendable {
    let date: Date
    let title: String
    let summary: String
    let people: [String]
    let places: [String]
    let emotions: [String]
    let symbols: [String]
    let sentimentScore: Int?
    let anxietyLevel: Int?
    let vividnessScore: Int?
    let lucidityScore: Int?
}

// Data point for metric history
nonisolated struct MetricDataPoint: Sendable {
    let date: Date
    let score: Int
}

// Protocol for tools to query dream data
protocol DreamSearchable: Sendable {
    func sleepSummary(for date: Date) async throws -> SleepSummary?
    func searchDreams(query: String, limit: Int) async -> [DreamSearchResult]
    func fetchMetricHistory(metric: String, days: Int) async -> [MetricDataPoint]
}

extension DreamSearchable {
    func sleepSummary(for date: Date) async throws -> SleepSummary? { nil }
}
