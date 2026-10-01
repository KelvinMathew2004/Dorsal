# Dorsal

Dorsal is a voice-first dream journal for capturing dreams soon after waking, exploring recurring themes, and reviewing changes over time. It combines on-device Apple frameworks with an optional iCloud-backed journal and optional Apple Health sleep context.

## Features

### Record and keep dream entries

- Record, pause, resume, and save spoken dreams.
- Review the transcript, listen to the recording, and export audio.
- Keep a journal of dream entries with dates, titles, summaries, bookmarks, and generated images.
- Search dream transcripts and organize people and places mentioned in entries.
- Retry transcription when a recording was saved but speech recognition could not finish.

### Explore analysis and patterns

- Analyze dream narratives with Apple’s on-device Foundation Models when available.
- Review summaries, interpretations, emotions, recurring people and places, symbols, and reflective advice.
- Track sentiment, anxiety, lucidity, vividness, coherence, nightmares, vocal fatigue, and other journal metrics over time.
- Compare anxiety and sentiment as separate chart lines, with weekly and longer-term views.
- Generate weekly summaries of themes and trends.
- Treat these as reflective journaling signals, not medical assessments or diagnoses.

### Create dream images

- Generate images from an analyzed dream or create one from its detail screen.
- On iOS 27, choose a prompt style: Dreamlike, Animation, Lofi, Comic, Anime, Watercolor, Gaming, Sci-Fi, Realistic, or Noir. iOS 26 keeps the Dreamlike default.
- On iOS 27, open a prefilled Image Playground sheet and choose whether the scene should include people.
- When a profile subject is available for a people-focused scene, Dorsal can extract the person from the profile photo and place the cutout on a square transparent canvas before passing it to Image Playground.
- iOS 26 uses the supported automatic Image Playground generation path; iOS 27 uses the system creation sheet.

### Review sleep and voice trends

- Optionally read sleep data from Apple Health and show sleep stages alongside a dream.
- Use available sleep context in sleep-related questions without adding it to saved dream analysis.
- Estimate vocal fatigue from the recording with the included Core ML model; when audio analysis is unavailable, Dorsal can estimate from the transcript.
- Explore the recording screen’s audio-reactive aurora visualizer, with a mirrored aurora reflection and water texture.

### Use system integrations

- Use Siri and Shortcuts to record a dream, open the latest or a selected dream, search entries, open app sections, check trends, or get a recent dream summary.
- Use the recorder control to open Dorsal’s recording screen.
- Sync journal data and preferences through Apple’s iCloud services when available.

## Privacy and data

- Dream recording, transcription, and analysis use Apple platform frameworks and on-device models where supported.
- Journal persistence uses SwiftData with CloudKit synchronization when the user’s iCloud account and app configuration permit it. Dorsal does not require a separate Dorsal account.
- Apple Health access is optional and read-only. Sleep information is fetched only when the user enables the feature; it is not included in saved dream analysis or synced journal records.
- Image Playground is provided by Apple’s system framework. Generated images and likeness are subject to Apple’s generation behavior and restrictions.

## Requirements

- iOS 26.0 or later; the iOS 27-specific scene controls and Image Playground sheet require iOS 27.
- A device that supports Apple Intelligence and the relevant on-device models for AI analysis and image generation.
- Optional Apple Health access for sleep data.
- Xcode and an Apple development account to build and run the project.

## Build

Open `Dorsal/Dorsal.xcodeproj` in Xcode, select the Dorsal app scheme, choose a compatible iPhone or simulator, and build. Some device capabilities, including HealthKit data, on-device model availability, Image Playground, and iCloud synchronization, depend on the selected device, OS version, account, and project signing configuration.

## Project notes

- `Documentation/RecordingReliability.md` describes recording, transcription, and recovery behavior.
- `Documentation/UpgradeStatus.md` documents iOS 26 and iOS 27 integrations and compatibility details.
