import Foundation
import FoundationModels

// Tool 1: Search past dreams for patterns and context
struct QueryPastDreamsTool: Tool {
    let name = "queryPastDreams"
    let description = """
        Search the user's past dream journal for recurring people, places, 
        symbols, emotions, or themes. Use this to identify patterns across 
        multiple dreams or to provide context when answering questions.
        """
    
    @Generable struct Arguments {
        @Guide(description: "Search query — a person name, place, symbol, emotion, or theme to look up")
        var query: String
        @Guide(description: "Maximum number of matching dreams to return", .range(1...10))
        var limit: Int
    }
    
    let dreamSearcher: any DreamSearchable
    
    func call(arguments: Arguments) async throws -> String {
        let matches = await dreamSearcher.searchDreams(
            query: arguments.query, 
            limit: arguments.limit
        )
        if matches.isEmpty {
            return "No matching dreams found."
        }
        let formatted = matches.map { match in
            var line = "[\(match.date.formatted(.dateTime.month().day()))]: \(match.title)"
            line += " — \(match.summary)"
            if !match.emotions.isEmpty {
                line += " (Emotions: \(match.emotions.joined(separator: ", ")))"
            }
            return line
        }.joined(separator: "\n")
        return formatted
    }
}

// Tool 2: Fetch historical metric scores for trend analysis
struct FetchMetricHistoryTool: Tool {
    let name = "fetchMetricHistory"
    let description = """
        Fetch the user's historical scores for a specific dream metric 
        (anxiety, sentiment, lucidity, vividness, fatigue, or coherence) 
        over a time range. Use this to understand trends and give 
        personalized coaching advice.
        """
    
    @Generable struct Arguments {
        @Guide(description: "The metric to fetch: anxiety, sentiment, lucidity, vividness, fatigue, or coherence")
        var metric: String
        @Guide(description: "Number of days to look back", .range(7...365))
        var daysBack: Int
    }
    
    let dreamSearcher: any DreamSearchable
    
    func call(arguments: Arguments) async throws -> String {
        let history = await dreamSearcher.fetchMetricHistory(
            metric: arguments.metric, 
            days: arguments.daysBack
        )
        if history.isEmpty {
            return ("No data available for '\(arguments.metric)' in the last \(arguments.daysBack) days.")
        }
        let formatted = history.map { 
            "\($0.date.formatted(.dateTime.month().day())): \($0.score)"
        }.joined(separator: ", ")
        return ("\(arguments.metric) scores — \(formatted)")
    }
}
