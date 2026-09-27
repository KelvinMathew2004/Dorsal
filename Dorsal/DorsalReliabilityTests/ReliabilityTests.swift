import Testing
import Foundation
import FoundationModels
import ImagePlayground
import SwiftData
import AVFoundation
import Speech
@testable import Dorsal

@MainActor
@Suite("Recording and recovery regression tests")
struct ReliabilityTests {
    @Test func modelNotReadyDoesNotClaimADownload() {
        let availability = AnalysisAvailability(.unavailable(.modelNotReady))
        #expect(availability == .notReady)
        #expect(availability.message?.contains("still record") == true)
        #expect(availability.message?.localizedCaseInsensitiveContains("downloading") == false)
        #expect(AnalysisAvailability(.available).message == nil)
    }

    @Test(arguments: [AnalysisAvailability.disabled, .unsupported, .unknown])
    func unavailableAnalysisStillExplainsRecording(_ availability: AnalysisAvailability) {
        #expect(availability.message?.localizedCaseInsensitiveContains("record") == true)
    }

    @Test func unavailableAssetsAreNotReportedAsDownloading() {
        let context = LanguageModelSession.GenerationError.Context(debugDescription: "Test")
        let message = DreamFailure.analysisMessage(for: LanguageModelSession.GenerationError.assetsUnavailable(context))
        #expect(!message.localizedCaseInsensitiveContains("downloading"))
        #expect(message.localizedCaseInsensitiveContains("unavailable"))
    }

    @Test(arguments: [ImageCreator.Error.unavailable, .notSupported, .backgroundCreationForbidden, .creationCancelled, .unsupportedLanguage])
    func ChangingThePromptDoesNotRetryServiceFailures(_ error: ImageCreator.Error) {
        #expect(!DreamFailure.shouldRetryImageWithSimplerPrompt(error))
    }

    @Test func contentRelatedImageFailuresMayUseSimplerPrompt() {
        #expect(DreamFailure.shouldRetryImageWithSimplerPrompt(ImageCreator.Error.creationFailed))
        #expect(DreamFailure.shouldRetryImageWithSimplerPrompt(ImageCreator.Error.conceptsRequirePersonIdentity))
        #expect(DreamFailure.isCancellation(ImageCreator.Error.creationCancelled))
        #expect(DreamFailure.isCancellation(CancellationError()))
    }

    @Test func volatileSpeechIsReplacedAndFinalSpeechIsDrained() {
        var transcript = TranscriptAccumulator()
        transcript.append("I was in", isFinal: false)
        transcript.append("I was in a forest.", isFinal: true)
        transcript.append("Then", isFinal: false)
        transcript.append("Then I woke up.", isFinal: true)
        #expect(transcript.text == "I was in a forest. Then I woke up.")
        #expect(transcript.finalized == transcript.text)
    }

    @Test func failedTranscriptionPreservesLatestPartialText() {
        var transcript = TranscriptAccumulator()
        transcript.append("I was flying.", isFinal: true)
        transcript.append("Above the ocean", isFinal: false)
        #expect(transcript.text == "I was flying. Above the ocean")
    }

    @Test func recordingNamesCannotOverwriteEachOther() throws {
        let first = try RecordingFiles.makeURL()
        let second = try RecordingFiles.makeURL()
        #expect(first != second)
        #expect(first.pathExtension == "caf")
        #expect(RecordingFiles.url(for: "../outside.caf") == nil)
    }

    @Test func errorsAndAudioSurviveDatabaseReload() throws {
        let context = try makeContext()
        var dream = Dream(rawTranscript: "I was flying.")
        dream.recordingFileName = "recording.caf"
        dream.analysisError = "Analysis is not ready."
        dream.imageError = "Illustration unavailable."
        dream.transcriptionError = "Partial transcript."
        dream.needsAnalysis = true
        dream.needsTranscription = true
        try DreamPersistence.save(dream, in: context) { try context.save() }
        let saved = try #require(context.fetch(FetchDescriptor<SavedDream>()).first)
        let restored = Dream(from: saved)
        #expect(restored.rawTranscript == dream.rawTranscript)
        #expect(restored.recordingFileName == dream.recordingFileName)
        #expect(restored.analysisError == dream.analysisError)
        #expect(restored.imageError == dream.imageError)
        #expect(restored.transcriptionError == dream.transcriptionError)
        #expect(restored.needsAnalysis == true)
        #expect(restored.needsTranscription == true)
        #expect(restored.core == nil)
        #expect(restored.extras == nil)
    }

    @Test func imageFailureDoesNotEraseAnalysis() throws {
        let context = try makeContext()
        var dream = Dream(rawTranscript: "I visited a garden.", core: DreamCoreAnalysis(title: "Garden", summary: "A peaceful garden."))
        dream.imageError = "Image creation is temporarily unavailable."
        try DreamPersistence.save(dream, in: context) { try context.save() }
        let restored = Dream(from: try #require(context.fetch(FetchDescriptor<SavedDream>()).first))
        #expect(restored.core?.summary == "A peaceful garden.")
        #expect(restored.analysisError == nil)
        #expect(restored.imageError != nil)
    }

    @Test func visualPromptSurvivesPersistenceAndFeedsImageAnalysis() throws {
        let context = try makeContext()
        let prompt = "The dreamer walks beside their grandmother through a sunlit garden."
        let dream = Dream(
            rawTranscript: "I was walking with my grandmother through a garden.",
            core: DreamCoreAnalysis(title: "Garden Walk", summary: "A walk through a garden."),
            imagePrompt: prompt
        )

        try DreamPersistence.save(dream, in: context) { try context.save() }
        let saved = try #require(context.fetch(FetchDescriptor<SavedDream>()).first)
        let restored = Dream(from: saved)

        #expect(saved.imagePrompt == prompt)
        #expect(restored.imagePrompt == prompt)
        #expect(restored.core?.imagePrompt == prompt)
        #expect(restored.analysis.imagePrompt == prompt)
    }

    @Test func audioOnlyDreamCanBeSavedAndRetried() throws {
        let context = try makeContext()
        var dream = Dream(rawTranscript: "")
        dream.recordingFileName = "audio.caf"
        dream.needsTranscription = true
        try DreamPersistence.save(dream, in: context) { try context.save() }
        dream.rawTranscript = "Recovered speech."
        dream.needsTranscription = false
        try DreamPersistence.save(dream, in: context) { try context.save() }
        let all = try context.fetch(FetchDescriptor<SavedDream>())
        #expect(all.count == 1)
        #expect(all.first?.rawText == "Recovered speech.")
        #expect(all.first?.recordingFileName == "audio.caf")
    }

    @Test func failedCommitThrowsAndRecoverySurvivesRetry() throws {
        let context = try makeContext()
        let recovery = DreamRecoveryStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        defer { try? FileManager.default.removeItem(at: recovery.directory) }
        var dream = Dream(rawTranscript: "Keep this dream.")
        dream.recordingFileName = "keep.caf"
        dream.needsAnalysis = true
        try recovery.write(dream)
        #expect(throws: TestFailure.self) {
            try DreamPersistence.save(dream, in: context) { throw TestFailure.diskFull }
        }
        let recovered = try #require(recovery.load().first)
        #expect(recovered == dream)
        try DreamPersistence.save(recovered, in: context) { try context.save() }
        try recovery.remove(dream.id)
        #expect(try recovery.load().isEmpty)
        #expect(try context.fetchCount(FetchDescriptor<SavedDream>()) == 1)
    }

    @Test func failedRegenerationKeepsExistingAnalysisAndPicture() async throws {
        let context = try makeContext()
        let store = DreamStore(prepareServices: false, availabilityProvider: { .notReady })
        store.modelContext = context
        let dream = Dream(rawTranscript: "A garden.", core: DreamCoreAnalysis(title: "Garden", summary: "A garden."), generatedImageData: Data([1, 2, 3]))
        store.dreams = [dream]
        store.regenerateDream(dream)
        for _ in 0..<100 where store.isProcessing { await Task.yield() }
        #expect(!store.isProcessing)
        let retained = try #require(store.dreams.first)
        #expect(retained.core == dream.core)
        #expect(retained.generatedImageData == dream.generatedImageData)
        #expect(retained.rawTranscript == dream.rawTranscript)
        #expect(retained.analysisError != nil)
        #expect(retained.needsAnalysis == true)
    }

    @Test(arguments: [false, true])
    func audioSinkClosesFileAndDrainsOwnedSpeechBuffers(convertCapture: Bool) async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("caf")
        defer { try? FileManager.default.removeItem(at: url) }
        // The recorder asks SpeechAnalyzer for a supported format. iOS 27 rejects
        // Float32 AnalyzerInput, so use valid Int16 speech data in this fixture.
        let speechFormat = try #require(AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 16000, channels: 1, interleaved: false))
        let format = convertCapture ? try #require(AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1)) : speechFormat
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 160))
        buffer.frameLength = 160
        for frame in 0..<160 {
            if convertCapture { buffer.floatChannelData![0][frame] = 0.25 }
            else { buffer.int16ChannelData![0][frame] = 8192 }
        }
        let stream = AsyncStream<AnalyzerInput>.makeStream()
        let sink = AudioCaptureSink(file: try AVAudioFile(forWriting: url, settings: format.settings,
                                                        commonFormat: format.commonFormat, interleaved: format.isInterleaved),
                                    format: speechFormat, continuation: stream.continuation,
                                    onFailure: { _ in Issue.record("Unexpected audio write/conversion failure") }, onLevel: { _ in })
        sink.consume(buffer)
        // Simulate the engine reusing its input storage before speech consumes it.
        for frame in 0..<160 {
            if convertCapture { buffer.floatChannelData![0][frame] = 0 }
            else { buffer.int16ChannelData![0][frame] = 0 }
        }
        #expect(!sink.finish())
        sink.consume(buffer) // A late tap callback after close must not append or reopen the file.
        var received = 0
        for await input in stream.stream {
            received += 1
            // On iOS 27 this getter creates an AVAudioPCMBuffer view. Keep it
            // alive while reading its raw channel pointer.
            let receivedBuffer = input.buffer
            let firstSample = withExtendedLifetime(receivedBuffer) { receivedBuffer.int16ChannelData?[0][0] }
            let sample = try #require(firstSample)
            #expect(abs(Int(sample) - 8192) <= 1)
        }
        #expect(received == 1)
        let saved = try AVAudioFile(forReading: url)
        #expect(saved.length == 160)
    }

    @Test func audioSinkRecordsWithoutAnySpeechModule() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("caf")
        defer { try? FileManager.default.removeItem(at: url) }
        let format = try #require(AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1))
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 320))
        buffer.frameLength = 320
        let sink = AudioCaptureSink(file: try AVAudioFile(forWriting: url, settings: format.settings),
                                    format: nil, continuation: nil,
                                    onFailure: { _ in Issue.record("Unexpected recording failure") }, onLevel: { _ in })
        sink.consume(buffer)
        #expect(!sink.finish())
        #expect(try AVAudioFile(forReading: url).length == 320)
    }

    @Test func existingJournalMigratesWithoutLosingDreams() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("journal.store")
        let id = UUID()
        do {
            let configuration = ModelConfiguration(url: url, cloudKitDatabase: .none)
            let original = try ModelContainer(for: LegacyDreamSchema.SavedDream.self, configurations: configuration)
            let context = ModelContext(original)
            context.insert(LegacyDreamSchema.SavedDream(id: id, rawText: "Original dream", title: "Original title", summary: "Original summary", isBookmarked: true))
            try context.save()
        }
        let configuration = ModelConfiguration(url: url, cloudKitDatabase: .none)
        let updated = try ModelContainer(for: SavedDream.self, configurations: configuration)
        let restored = try #require(ModelContext(updated).fetch(FetchDescriptor<SavedDream>()).first)
        #expect(restored.id == id)
        #expect(restored.rawText == "Original dream")
        #expect(restored.title == "Original title")
        #expect(restored.isBookmarked)
        #expect(restored.recordingFileName == nil)
        #expect(restored.analysisError == nil)
    }

    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: SavedDream.self, configurations: config)
        return ModelContext(container)
    }

    private enum TestFailure: Error { case diskFull }
}
