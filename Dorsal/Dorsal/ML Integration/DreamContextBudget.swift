import Foundation

nonisolated enum DreamContextBudget {
    // The original journal text is never replaced by this working context.
    static func compact(_ text: String, limit: Int,
                        count: @Sendable (String) async throws -> Int,
                        summarize: @Sendable (String) async throws -> String) async throws -> String {
        guard limit > 0 else { throw DreamError.tooLong }
        var current = text
        var previousCount = try await count(current)
        if previousCount <= limit { return text }
        for _ in 0..<3 {
            try Task.checkCancellation()
            let characters = Array(current)
            var offset = 0
            var summaries: [String] = []
            while offset < characters.count {
                guard summaries.count < 24 else { throw DreamError.tooLong }
                var lower = 1, upper = characters.count - offset, fitting = 0
                while lower <= upper {
                    try Task.checkCancellation()
                    let middle = (lower + upper) / 2
                    let candidate = String(characters[offset..<(offset + middle)])
                    if try await count(candidate) <= limit { fitting = middle; lower = middle + 1 }
                    else { upper = middle - 1 }
                }
                guard fitting > 0 else { throw DreamError.tooLong }
                let chunk = String(characters[offset..<(offset + fitting)])
                let summary = try await summarize(chunk).trimmingCharacters(in: .whitespacesAndNewlines)
                guard !summary.isEmpty else { throw DreamError.formatError }
                summaries.append(summary)
                offset += fitting
            }
            current = summaries.joined(separator: "\n")
            let newCount = try await count(current)
            if newCount <= limit { return current }
            guard newCount < previousCount else { throw DreamError.tooLong }
            previousCount = newCount
        }
        throw DreamError.tooLong
    }
}
