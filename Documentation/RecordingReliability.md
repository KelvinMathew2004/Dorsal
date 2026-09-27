# Recording and recovery audit

The App Review alert came from the Record view's check of
`SystemLanguageModel.default.availability`, specifically `.modelNotReady`.
It did not represent the completion status of `prewarm()`.

## API decisions and sources

- Foundation Models availability gates **analysis**, never microphone capture.
  `.modelNotReady` and `.assetsUnavailable` do not prove an active download.
  Prewarming is an optimization; it is not a prerequisite or a download API.
  [Model availability](https://developer.apple.com/documentation/foundationmodels/generating-content-and-performing-tasks-with-foundation-models)
  and [prewarming](https://developer.apple.com/documentation/foundationmodels/languagemodelsession/prewarm(promptprefix:)).
- Speech models and Apple Intelligence are independent. The recorder checks device,
  locale, and installed speech assets; it can record audio when those assets are
  absent. Downloads use AssetInventory and never replace an active analyzer.
  [SpeechTranscriber](https://developer.apple.com/documentation/speech/speechtranscriber),
  [AssetInventory](https://developer.apple.com/documentation/speech/assetinventory).
- `SpeechAnalyzer.start(inputSequence:)` returns after starting autonomous analysis.
  Finishing an AsyncStream alone does not finalize transcription. Stop capture,
  finish the stream, await `finalizeAndFinishThroughEndOfInput()`, then await the
  results consumer before reading the final transcript. Buffers sent to the
  asynchronous analyzer must not be buffers that the audio engine will reuse.
  [SpeechAnalyzer](https://developer.apple.com/documentation/speech/speechanalyzer),
  [finalization](https://developer.apple.com/documentation/speech/speechanalyzer/finalizeandfinishthroughendofinput()).
- SpeechAnalyzer's modules process audio on device. They do not require the
  additional SFSpeechRecognizer server-recognition permission. The microphone
  permission still applies. No extra speech authorization prompt was added.
  [Apple's permission guidance](https://developer.apple.com/documentation/speech/asking-permission-to-use-speech-recognition).
- Image generation cancellation, unavailable services, and background restrictions
  are not prompt problems. Only content-related failures use a simpler prompt.
  Failure of an illustration never hides the transcript or successful analysis.
  [ImageCreator errors](https://developer.apple.com/documentation/imageplayground/imagecreator/error).
- Apple discontinued ImageCreator in iOS 27. Automatic illustrations remain on
  iOS 26; the supported Image Playground sheet is available from the dream menu.
  [Apple's deprecation announcement](https://developer.apple.com/news/?id=dz9wvq0r).

Signatures were also checked against the installed Xcode 27 SDK interfaces.
The application's minimum OS remains iOS 26.0.

## Recovery behavior

- Recording failures are shown only after a real microphone/session/file/engine
  failure. Starting/stopping state prevents overlapping operations.
- Each recording has a unique PCM `.caf` file. Speech failure or empty results
  still creates a journal entry with playback, export, and transcription retry.
- Audio files are local to the device. A synced entry can retain its transcript
  and analysis on another device without the original local audio.
- Analysis and illustration messages are separate inline notices. Existing
  content stays accessible during generation and after failures.
- Save errors are checked. A local atomic recovery snapshot is written before
  the database commit and imported on the next launch if the commit failed.
  If both disk writes fail, the app tells the user to keep it open and retry.
- Additional SwiftData fields are optional. Existing records retain their
  content. New incomplete records distinguish absent metrics from actual zeroes.

## Automated validation

Verified on September 23, 2026 with Xcode 27.0:

- `DorsalReliability`: **16 tests passed** on an iPhone 17 Pro Max simulator,
  iOS 26.5, including real local-file audio writes and an on-disk schema migration.
- Normal main-screen launch on the same simulator: successful; the Record screen
  rendered with its microphone control and existing visual design intact.
- `Dorsal`, Release, generic iOS device: **build succeeded**, signing disabled.
  This is a compilation/link/resource check, not an archive/upload or device run.
- The simulator build included Metal shaders and asset catalogs. Xcode's missing
  Metal toolchain was installed before successful verification.

Run the shared `DorsalReliability` scheme, which uses `DorsalReliabilityTests`.
The older loose `DorsalTests` files are not part of that scheme and reference
obsolete models; they have not been counted as passing tests.

Coverage includes availability/error classifications, speech buffer ownership,
final/partial transcript assembly, audio capture without speech, unique filenames,
audio-only entries, failed save/retry, persisted recovery state, image errors
preserving analysis, unavailable-model regeneration preserving prior content,
and migration from the previous on-disk SavedDream schema.

## Physical-device checks before resubmission

The simulator cannot establish real Apple Intelligence readiness or reproduce
Apple's device-managed downloads. Test on an actual supported iPhone/iPad:

1. Fresh install with Apple Intelligence off: record, stop, read the entry, play
   audio, relaunch, and confirm the entry remains. No Feature Unavailable alert.
2. Apple Intelligence/model assets not ready: repeat the same flow, then retry
   analysis after the system reports availability. Do not promise a download ETA.
3. Speech assets unavailable/offline: recording remains usable; the audio-only
   entry survives relaunch and a later transcription retry.
4. Say a final sentence immediately before Stop; verify it survives finalization.
5. Deny/re-enable microphone access; test repeated fast taps and pause/resume.
6. Interrupt with a call/audio route change; check paused state, recovery, and save.
7. Background during image creation: transcript and analysis stay accessible;
   return and retry. Cancel Image Playground without creating an error notice.
8. Retry unavailable analysis on an existing fully analyzed dream: old text/image
   remain. Test a long transcript and a model refusal without losing source text.
9. Upgrade over the previous installed build with real journal/iCloud data.
10. Verify storage failure/retry on a controlled test device, then confirm deletion
    removes the local recording as well as the journal entry.

App Review's screenshot alone cannot establish why their model was unavailable.
These changes handle that state; they do not force Apple's models to download
or guarantee approval.
