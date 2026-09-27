import Foundation

/// Corrects transcription variants against contacts the user has explicitly linked.
/// Historical dream names are intentionally excluded — the model already receives
/// them as spelling hints in the prompt; re-applying them as post-processing caused
/// names from unrelated past dreams to bleed into the current dream's people list.
nonisolated enum DreamEntityCanonicalizer {
    static func canonicalize(_ detected: [String], linkedNames: [String], historicalNames: [String]) -> [String] {
        var result: [String] = []
        for raw in detected {
            let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { continue }
            // Only canonicalize against explicitly linked contacts (high threshold + token matching).
            // historicalNames are intentionally ignored to prevent cross-dream contamination.
            let match = uniqueMatch(for: name, in: linkedNames, threshold: 0.78, allowContainingToken: true)
            let canonical = match ?? name
            if !result.contains(where: { normalized($0) == normalized(canonical) }) { result.append(canonical) }
        }
        return result
    }

    private static func uniqueMatch(for query: String, in candidates: [String], threshold: Double, allowContainingToken: Bool) -> String? {
        let unique = Array(Dictionary(candidates.map { (normalized($0), $0) }, uniquingKeysWith: { first, _ in first }).values)
        let matches = unique.map { ($0, score(query, $0, allowContainingToken: allowContainingToken)) }
            .filter { $0.1 >= threshold }.sorted { $0.1 > $1.1 }
        guard let best = matches.first else { return nil }
        if matches.count > 1, best.1 - matches[1].1 < 0.08 { return nil }
        return best.0
    }

    private static func score(_ query: String, _ candidate: String, allowContainingToken: Bool) -> Double {
        let lhs = normalized(query), rhs = normalized(candidate)
        guard !lhs.isEmpty, !rhs.isEmpty else { return 0 }
        if lhs == rhs { return 1 }
        let leftWords = lhs.split(separator: " ").map(String.init)
        let rightWords = rhs.split(separator: " ").map(String.init)
        let matches = leftWords.map { word in rightWords.map { similarity(word, $0) }.max() ?? 0 }
        if matches.allSatisfy({ $0 >= 0.78 }), allowContainingToken || leftWords.count > 1 {
            return 0.85 + (matches.reduce(0, +) / Double(max(1, matches.count))) * 0.1
        }
        if leftWords.count == 1, rightWords.count > 1,
           let match = matches.first, match >= 0.78 {
            return 0.82 + match * 0.08
        }
        return similarity(lhs, rhs)
    }

    private static func similarity(_ lhs: String, _ rhs: String) -> Double {
        let a = Array(lhs), b = Array(rhs)
        guard !a.isEmpty || !b.isEmpty else { return 1 }
        var previous = Array(0...b.count)
        for (i, left) in a.enumerated() {
            var current = [i + 1] + Array(repeating: 0, count: b.count)
            for (j, right) in b.enumerated() {
                current[j + 1] = min(current[j] + 1, previous[j + 1] + 1, previous[j] + (left == right ? 0 : 1))
            }
            previous = current
        }
        return 1 - Double(previous[b.count]) / Double(max(a.count, b.count))
    }

    private static func normalized(_ text: String) -> String {
        String(String.UnicodeScalarView(text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) || CharacterSet.whitespaces.contains($0) }))
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}
