import Foundation
import HealthKit

nonisolated struct SleepSummary: Sendable, Equatable, Codable {
    let totalSleepMinutes: Int
    let remMinutes: Int
    let deepSleepMinutes: Int
    let coreSleepMinutes: Int
    let awakeMinutes: Int
    let sleepEfficiency: Int?
    let sleepOnsetTime: Date
    let wakeUpTime: Date

    var hasStageData: Bool { remMinutes + deepSleepMinutes + coreSleepMinutes > 0 }
    var unspecifiedMinutes: Int { max(0, totalSleepMinutes - remMinutes - deepSleepMinutes - coreSleepMinutes) }
}

// A source-neutral representation makes overlap handling testable without Health access.
nonisolated struct SleepSegment: Sendable {
    enum Stage: Int, Sendable { case inBed, unspecified, core, deep, rem, awake }
    let start: Date
    let end: Date
    let stage: Stage
    let source: String
}

nonisolated enum SleepAggregation {
    static func summarize(_ segments: [SleepSegment], from start: Date, to end: Date) -> SleepSummary? {
        let clipped = segments.compactMap { segment -> SleepSegment? in
            let lower = max(start, segment.start), upper = min(end, segment.end)
            guard lower < upper else { return nil }
            return SleepSegment(start: lower, end: upper, stage: segment.stage, source: segment.source)
        }
        // Never add overlapping tracks from a Watch, an iPhone, and third-party apps.
        // Prefer the source with the most staged coverage, then measured sleep coverage.
        let summaries = Dictionary(grouping: clipped, by: \.source).compactMap { source, samples -> (String, SleepSummary)? in
            guard let summary = summarizeSource(samples) else { return nil }
            return (source, summary)
        }
        return summaries.sorted {
            let left = $0.1, right = $1.1
            let leftStages = left.remMinutes + left.deepSleepMinutes + left.coreSleepMinutes
            let rightStages = right.remMinutes + right.deepSleepMinutes + right.coreSleepMinutes
            if leftStages != rightStages { return leftStages > rightStages }
            if left.totalSleepMinutes != right.totalSleepMinutes { return left.totalSleepMinutes > right.totalSleepMinutes }
            return $0.0 < $1.0
        }.first?.1
    }

    private static func summarizeSource(_ samples: [SleepSegment]) -> SleepSummary? {
        let boundaries = Array(Set(samples.flatMap { [$0.start, $0.end] })).sorted()
        guard boundaries.count > 1 else { return nil }
        var seconds: [SleepSegment.Stage: TimeInterval] = [:]
        var inBed: TimeInterval = 0
        var onset: Date?, wake: Date?
        for (start, end) in zip(boundaries, boundaries.dropFirst()) {
            let active = samples.filter { $0.start < end && $0.end > start }
            let duration = end.timeIntervalSince(start)
            if active.contains(where: { $0.stage == .inBed }) { inBed += duration }
            // Detailed stages replace unspecified sleep; duplicate samples count once.
            guard let stage = active.map(\.stage).filter({ $0 != .inBed }).max(by: { $0.rawValue < $1.rawValue }) else { continue }
            seconds[stage, default: 0] += duration
            if stage != .awake { onset = onset ?? start; wake = end }
        }
        guard let onset, let wake else { return nil } // In-bed time is not measured sleep.
        func minutes(_ stage: SleepSegment.Stage) -> Int { Int(((seconds[stage] ?? 0) / 60).rounded()) }
        let rem = minutes(.rem), deep = minutes(.deep), core = minutes(.core)
        let total = rem + deep + core + minutes(.unspecified)
        guard total > 0 else { return nil }
        let awake = minutes(.awake)
        let measuredSeconds = seconds.values.reduce(0, +)
        let asleepSeconds = measuredSeconds - (seconds[.awake] ?? 0)
        let denominator = max(inBed, measuredSeconds)
        let efficiency = (inBed > 0 || awake > 0) && denominator > 0
            ? min(100, Int((asleepSeconds / denominator * 100).rounded())) : nil
        return SleepSummary(totalSleepMinutes: total, remMinutes: rem, deepSleepMinutes: deep,
                            coreSleepMinutes: core, awakeMinutes: awake, sleepEfficiency: efficiency,
                            sleepOnsetTime: onset, wakeUpTime: wake)
    }
}

actor SleepDataManager {
    static let shared = SleepDataManager()
    private var existingStore: HKHealthStore?
    private var healthStore: HKHealthStore {
        if let existingStore { return existingStore }
        let store = HKHealthStore()
        existingStore = store
        return store
    }
    nonisolated var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    func requestAuthorization() async throws {
        guard isAvailable else { throw HKError(.errorHealthDataUnavailable) }
        try await healthStore.requestAuthorization(toShare: [], read: [HKCategoryType(.sleepAnalysis)])
    }

    func fetchSleepForDate(_ date: Date) async throws -> SleepSummary? {
        guard isAvailable else { return nil }
        try Task.checkCancellation()
        guard let interval = Self.queryWindow(endingAt: date) else { return nil }
        let start = interval.start, end = interval.end
        // Include overlapping samples, then clip them to the requested interval.
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: HKCategoryType(.sleepAnalysis), predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate)]
        )
        let samples = try await descriptor.result(for: healthStore)
        try Task.checkCancellation()
        let segments = samples.compactMap { sample -> SleepSegment? in
            let stage: SleepSegment.Stage
            switch HKCategoryValueSleepAnalysis(rawValue: sample.value) {
            case .inBed: stage = .inBed
            case .asleepUnspecified: stage = .unspecified
            case .asleepCore: stage = .core
            case .asleepDeep: stage = .deep
            case .asleepREM: stage = .rem
            case .awake: stage = .awake
            default: return nil
            }
            let source = sample.sourceRevision.source.bundleIdentifier + ":" + (sample.device?.localIdentifier ?? "")
            return SleepSegment(start: sample.startDate, end: sample.endDate, stage: stage, source: source)
        }
        return SleepAggregation.summarize(segments, from: start, to: end)
    }

    nonisolated static func queryWindow(endingAt date: Date, now: Date = Date(), calendar: Calendar = .current) -> DateInterval? {
        guard let previousDay = calendar.date(byAdding: .day, value: -1, to: date),
              let start = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: previousDay),
              let evening = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: date) else { return nil }
        // A late journal entry must not combine the previous night with the
        // beginning of a second night's sleep.
        let end = min(min(date, now), evening)
        return start < end ? DateInterval(start: start, end: end) : nil
    }
}
