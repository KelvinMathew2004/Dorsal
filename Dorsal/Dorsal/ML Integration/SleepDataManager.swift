import Foundation
import HealthKit

public struct SleepSummary: Sendable, Equatable {
    public let totalSleepMinutes: Int
    public let remMinutes: Int
    public let deepSleepMinutes: Int
    public let coreSleepMinutes: Int
    public let awakeMinutes: Int
    public let sleepEfficiency: Int
    public let sleepOnsetTime: Date?
    public let wakeUpTime: Date?
    
    public var hasStageData: Bool {
        return remMinutes + deepSleepMinutes + coreSleepMinutes > 0
    }
}

public actor SleepDataManager {
    public static let shared = SleepDataManager()
    
    private let healthStore = HKHealthStore()
    
    public var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }
    
    public func requestAuthorization() async throws {
        guard isAvailable else { return }
        
        let sleepType = HKCategoryType(.sleepAnalysis)
        let typesToRead: Set<HKObjectType> = [sleepType]
        
        try await healthStore.requestAuthorization(toShare: [], read: typesToRead)
    }
    
    public func fetchLastNightSleep() async throws -> SleepSummary? {
        let now = Date()
        guard let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now),
              let yesterday6PM = Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: yesterday) else {
            return nil
        }
        
        return try await fetchSleepData(from: yesterday6PM, to: now)
    }
    
    public func fetchSleepForDate(_ date: Date) async throws -> SleepSummary? {
        let calendar = Calendar.current
        guard let start = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: calendar.date(byAdding: .day, value: -1, to: date)!),
              let end = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: date) else {
            return nil
        }
        
        return try await fetchSleepData(from: start, to: end)
    }
    
    public func fetchWeeklySleep() async throws -> [SleepSummary] {
        var summaries: [SleepSummary] = []
        let calendar = Calendar.current
        let today = Date()
        
        for i in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: -i, to: today),
               let summary = try await fetchSleepForDate(date) {
                summaries.append(summary)
            }
        }
        
        return summaries.reversed() // Oldest first
    }
    
    private func fetchSleepData(from startDate: Date, to endDate: Date) async throws -> SleepSummary? {
        let sleepType = HKCategoryType(.sleepAnalysis)
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)
        
        let samples = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKCategorySample], Error>) in
            let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { _, results, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let sleepSamples = results as? [HKCategorySample] else {
                    continuation.resume(returning: [])
                    return
                }
                
                continuation.resume(returning: sleepSamples)
            }
            
            healthStore.execute(query)
        }
        
        if samples.isEmpty {
            return nil
        }
        
        var totalSleepMinutes = 0
        var remMinutes = 0
        var deepSleepMinutes = 0
        var coreSleepMinutes = 0
        var awakeMinutes = 0
        var inBedMinutes = 0
        
        var sleepOnsetTime: Date? = nil
        var wakeUpTime: Date? = nil
        
        for sample in samples {
            let duration = sample.endDate.timeIntervalSince(sample.startDate) / 60.0
            let minutes = Int(round(duration))
            
            if sleepOnsetTime == nil || sample.startDate < sleepOnsetTime! {
                sleepOnsetTime = sample.startDate
            }
            if wakeUpTime == nil || sample.endDate > wakeUpTime! {
                wakeUpTime = sample.endDate
            }
            
            guard let sleepValue = HKCategoryValueSleepAnalysis(rawValue: sample.value) else { continue }
            
            switch sleepValue {
            case .inBed:
                inBedMinutes += minutes
            case .asleepREM:
                remMinutes += minutes
                totalSleepMinutes += minutes
            case .asleepDeep:
                deepSleepMinutes += minutes
                totalSleepMinutes += minutes
            case .asleepCore:
                coreSleepMinutes += minutes
                totalSleepMinutes += minutes
            case .asleepUnspecified:
                totalSleepMinutes += minutes
            case .awake:
                awakeMinutes += minutes
            @unknown default:
                break
            }
        }
        
        var efficiency = 0
        if totalSleepMinutes > 0 {
            let totalTime = Double(totalSleepMinutes + awakeMinutes)
            efficiency = totalTime > 0 ? Int(round(Double(totalSleepMinutes) / totalTime * 100)) : 0
            if efficiency > 100 { efficiency = 100 }
        } else if inBedMinutes > 0 {
             totalSleepMinutes = inBedMinutes - awakeMinutes
             if totalSleepMinutes < 0 { totalSleepMinutes = 0 }
             efficiency = Int(round(Double(totalSleepMinutes) / Double(inBedMinutes) * 100))
             if efficiency > 100 { efficiency = 100 }
        }
        
        return SleepSummary(
            totalSleepMinutes: totalSleepMinutes,
            remMinutes: remMinutes,
            deepSleepMinutes: deepSleepMinutes,
            coreSleepMinutes: coreSleepMinutes,
            awakeMinutes: awakeMinutes,
            sleepEfficiency: efficiency,
            sleepOnsetTime: sleepOnsetTime,
            wakeUpTime: wakeUpTime
        )
    }
}
