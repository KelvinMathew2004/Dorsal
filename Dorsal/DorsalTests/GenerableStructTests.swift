import Testing
import FoundationModels
@testable import Dorsal

@Suite("Generable Struct Tests")
struct GenerableStructTests {
    @Test("DreamCoreAnalysis Initialization")
    func testDreamCoreAnalysis() throws {
        let analysis = DreamCoreAnalysis(
            primaryEmotion: "Fear",
            themes: ["Running", "Falling"],
            lucidityLevel: 2
        )
        #expect(analysis.primaryEmotion == "Fear")
        #expect(analysis.themes.count == 2)
        #expect(analysis.lucidityLevel == 2)
    }

    @Test("RepairSentiment Initialization")
    func testRepairSentiment() throws {
        let sentiment = RepairSentiment(
            overallScore: 8,
            keyPositiveFactors: ["Family", "Success"],
            keyNegativeFactors: []
        )
        #expect(sentiment.overallScore == 8)
        #expect(sentiment.keyPositiveFactors.contains("Family"))
    }

    @Test("RepairAnxiety Initialization")
    func testRepairAnxiety() throws {
        let anxiety = RepairAnxiety(
            anxietyLevel: 5,
            triggers: ["School", "Exams"]
        )
        #expect(anxiety.anxietyLevel == 5)
        #expect(anxiety.triggers.contains("Exams"))
    }
}
