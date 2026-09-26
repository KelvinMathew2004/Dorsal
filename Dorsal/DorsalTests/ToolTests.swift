import Testing
import FoundationModels
@testable import Dorsal

@Suite("Tool Arguments Tests")
struct ToolTests {
    @Test("QueryPastDreamsTool Arguments")
    func testQueryPastDreamsToolArguments() throws {
        let args = QueryPastDreamsTool.Arguments(query: "mom", limit: 5)
        #expect(args.query == "mom")
        #expect(args.limit == 5)
    }

    @Test("FetchMetricHistoryTool Arguments")
    func testFetchMetricHistoryToolArguments() throws {
        let args = FetchMetricHistoryTool.Arguments(metric: "anxiety", daysBack: 14)
        #expect(args.metric == "anxiety")
        #expect(args.daysBack == 14)
    }
}
