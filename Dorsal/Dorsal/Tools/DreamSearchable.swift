import Foundation

// Results returned from dream search
struct DreamSearchResult: Sendable {
    let date: Date
    let title: String
    let summary: String
    let people: [String]
    let places: [String]
    let emotions: [String]
    let symbols: [String]
    let sentimentScore: Int
    let anxietyLevel: Int
    let vividnessScore: Int
    let lucidityScore: Int
}

// Data point for metric history
struct MetricDataPoint: Sendable {
    let date: Date
    let score: Int
}

// Protocol for tools to query dream data
protocol DreamSearchable: Sendable {
    func searchDreams(query: String, limit: Int) async -> [DreamSearchResult]
    func fetchMetricHistory(metric: String, days: Int) async -> [MetricDataPoint]
}
