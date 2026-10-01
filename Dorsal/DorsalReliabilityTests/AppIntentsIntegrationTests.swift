import AppIntentsTesting
import XCTest

/// These tests run the installed app's App Intents out of process, as Siri and
/// Shortcuts do. They require an iOS 27 runtime and the Dorsal app installed.
@available(iOS 27.0, *)
final class AppIntentsIntegrationTests: XCTestCase {
    private let definitions = IntentDefinitions(bundleIdentifier: "com.kelvinmathew.dorsal")

    func testDreamSummaryIntentReturnsSpokenSummary() async throws {
        let result = try await definitions.intents["DreamSummaryIntent"]
            .makeIntent()
            .run()

        let summary: String = try result.value
        XCTAssertFalse(summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        XCTAssertTrue(summary.localizedCaseInsensitiveContains("dream"))
    }

    func testDreamEntityQueryResolvesSuggestedEntitiesByIdentifier() async throws {
        let entityDefinition = definitions.entities["DreamEntryEntity"]
        let suggested = try await entityDefinition.suggestedEntities()

        // A new installation can have no entries. When entries exist, verify
        // both the suggestion path and the identifier resolution path.
        guard let first = suggested.first else { return }
        let identifier = first.identifier.instanceIdentifier
        let resolved = try await entityDefinition.entities(identifiers: [identifier])

        XCTAssertEqual(resolved.count, 1)
        XCTAssertEqual(resolved[0].identifier.instanceIdentifier, identifier)
        XCTAssertFalse(try resolved[0].title.isEmpty)
    }

    func testDreamEntityStringQueryReturnsResolvableMatches() async throws {
        let entityDefinition = definitions.entities["DreamEntryEntity"]
        let suggested = try await entityDefinition.suggestedEntities()
        guard let first = suggested.first else { return }

        let title: String = try first.title
        let matches = try await entityDefinition.entities(matching: title)

        XCTAssertTrue(matches.contains { $0.identifier.instanceIdentifier == first.identifier.instanceIdentifier })
    }
}
