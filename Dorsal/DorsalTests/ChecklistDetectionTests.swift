import Testing
@testable import Dorsal

@Suite("Checklist Detection Tests")
struct ChecklistDetectionTests {
    @Test("ChecklistItem Initialization and Categorization")
    func testChecklistItemCategories() throws {
        let item1 = ChecklistItem(title: "My mom was there", isCompleted: false, category: .people)
        let item2 = ChecklistItem(title: "I was at school", isCompleted: false, category: .location)
        
        #expect(item1.category == .people)
        #expect(item1.title.contains("mom"))
        
        #expect(item2.category == .location)
        #expect(item2.title.contains("school"))
    }
}
