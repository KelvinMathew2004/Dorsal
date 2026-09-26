# Upgrade branch status

`main` at `05a4c43` contains the App Review fixes, requested recording UI refinements,
permission copy, build 1.0 (3), and latest README update. `ios-27-upgrades` is rebased onto it. The original
upgrade work is preserved at `backup/ios-27-upgrades-before-rebase-20260923`.

## UI and integrations

- Primary scrolling screens explicitly use soft scroll edges on iOS 27. Existing
  layouts and glass materials remain. The `.soft` API itself dates to iOS 26;
  its use is gated to keep the previous iOS 26 scroll presentation.
  [Scroll edge style](https://developer.apple.com/documentation/swiftui/scrolledgeeffectstyle/soft).
- The journal uses adaptive image-filled tiles at regular widths, with dates and
  titles at the top left, a subtle shadow, clear glass, and bookmark controls.
  Compact widths retain the existing rows. Entries within the current day and
  preceding six calendar days show weekdays; older entries show dates without
  time. Adaptive grids work on both supported OS versions.
  [Adaptive layouts](https://developer.apple.com/videos/play/wwdc2026/8120/).
- On iOS 27, native reorder containers persist order within root and one-level
  child groups; custom drop targets still link and unlink aliases. iOS 26 retains
  the original drag/drop path, preserving the nested grouping behavior.
  [Reordering collections](https://developer.apple.com/documentation/swiftui/reordering-items-in-lists-stacks-grids-and-custom-layouts).
- The theme wheel has individual scroll targets, an initial selection in the
  middle of the repeated strip, explicit center snapping, and recentering near
  either end. Its existing glass lens and drag control are retained.
  [Scroll target alignment](https://developer.apple.com/documentation/swiftui/scrolltargetbehavior/viewaligned(limitbehavior:anchor:)).
- Place details can link to a searched Maps location, open it in Maps, change the
  link, or unlink it. Coordinates and a display address are stored in one optional
  field. Linking does not request the person's current location. Failed profile
  saves remain in memory and can be retried with the existing save-recovery control.
  [Maps search](https://developer.apple.com/documentation/mapkit/mklocalsearch).
- Seven App Intents support opening app sections, the recorder, the latest or selected dream,
  searching transcripts, opening trends, and summarizing recent recorded emotions.
  Seven App Shortcuts are registered. Background reads open the saved journal even
  before the UI loads; opening an entry waits for the UI's model context. These
  intents require local device authentication. The summary provides spoken Siri
  dialogue as well as a Shortcuts text value. Navigation uses iOS 26 foreground
  modes, and newer requests replace pending entry navigation.
  [Entity queries](https://developer.apple.com/documentation/appintents/entitystringquery).
- The recorder control is now built and embedded as a WidgetKit extension. Its
  shared OpenIntent routes to the app scene on iOS 26 and 27; the extension does
  not read journal or Health data. The control opens the recorder without starting
  the microphone; the explicit “Record a Dream” App Intent starts a recording.
  The existing onboarding and permission flow still applies.
  [Controls and target membership](https://developer.apple.com/documentation/widgetkit/creating-controls-to-perform-actions-across-the-system),
  [Scene routing](https://developer.apple.com/documentation/swiftui/view/onappintentexecution(_:perform:)).

## Models, images, and Health

- iOS 26 retains automatic ImageCreator illustrations. Apple discontinued that
  API on iOS 27, so the fallback is a prefilled Image Playground sheet, gated by
  `supportsImagePlayground`. Its button is above the summary. The sheet selects
  the animation style, matching automatic generation, with luminous, dreamlike
  art direction. A refined prompt is prepared in the background; opening the
  sheet can immediately use a styled summary. iOS 27 prompts allow generic people
  and animals. Apple's system still controls which content it can generate.
  Recording never depends on image support.
  [Apple's announcement](https://developer.apple.com/news/?id=dz9wvq0r),
  [sheet availability](https://developer.apple.com/documentation/swiftui/environmentvalues/supportsimageplayground).
- On iOS 27, a decodable profile photo seeds the sheet as `sourceImage`, with
  a concept identifying the pictured person as the dreamer. `generateNew` asks
  for a new scene; animation styling and personalization are enabled. Inputs
  are captured when the sheet opens to avoid disrupting an active generation.
  Missing or invalid photos fall back to text alone. On iOS 26, automatic
  ImageCreator generation also receives a valid profile photo as an image
  concept when the preference is enabled. The reference is visual
  guidance, not a guarantee of likeness or a mandatory depiction of the dreamer.
  iOS 26 automatic generation is unchanged.
  [Reference images and options](https://developer.apple.com/videos/play/wwdc2026/375/).
- Fresh analysis sessions are retained. On iOS 26.4+, token counting measures
  prompts, instructions, schemas, and tool transcripts with response space
  reserved. Oversized analysis context is condensed in bounded fresh sessions;
  the raw transcript and audio are unchanged. Oversized tool requests fall back
  to a fresh non-tool session. Cancellation, refusals and unavailable services
  are not blindly retried. Failure of optional token measurement does not become
  a new readiness gate. Earlier iOS 26 releases keep their existing fresh-session
  behavior. Modern iOS 27 error types receive accurate messages.
  [Context management](https://developer.apple.com/documentation/technotes/tn3193-managing-the-on-device-foundation-model-s-context-window),
  [tool calling](https://developer.apple.com/documentation/foundationmodels/expanding-generation-with-tool-calling).
- Tools share a three-call budget, bounded search excerpts and metric histories,
  and local calendar dates. Missing scores stay missing. Only ephemeral question
  answers can access the opt-in sleep tool.
- Health sleep is read-only and opt-in from Settings. Completed authorization
  does not prove read access. Missing samples do not mean zero sleep or denial.
  Samples are clipped and deduplicated; different source tracks are not added
  together. Late journal entries do not combine two nights. Sleep values stay in
  memory, outside the CloudKit journal, saved analysis, and recovery snapshots.
  [Authorization](https://developer.apple.com/documentation/healthkit/authorizing-access-to-health-data),
  [sleep samples](https://developer.apple.com/documentation/healthkit/hkcategoryvaluesleepanalysis),
  [App Review 5.1.3](https://developer.apple.com/app-store/review/guidelines/).
- Private Cloud Compute remains disabled. It requires Apple's managed entitlement,
  network and quota handling. It can offer more reasoning capacity, but quality
  needs evaluation for this feature. Neither PCC nor iOS 27-only UI APIs silently
  fall back to older APIs; the app must implement that choice. No entitlement or
  cloud upload was added while account approval is unknown.
  [PCC requirements and fallback](https://developer.apple.com/documentation/foundationmodels/adding-server-side-intelligence-with-private-cloud-compute).

The deployment target remains iOS 26.0. Supporting iOS 18 would require broader
fallbacks for Foundation Models, SpeechAnalyzer, and Liquid Glass.

## Validation

The Xcode 27 Release build succeeds with all app shaders and Core ML resources.
The reliability suite has 42 passing tests on iOS 26.5, iOS 27 iPhone, and
iPadOS 27 simulators.

Tests cover recording recovery, persisted journal migration, adding Maps data
without losing existing contact/group links, pending profile-save retries,
intent data loading and deferred navigation, sleep aggregation and time windows,
context compaction, bounded tools, local date labels, and image availability.
Rendering fixtures exercise the phone journal, iPad grid, and theme wheel.

The iOS 27 speech fixture uses supported Int16 input and retains its buffer while
reading sample memory. Production already requests a supported format with
`SpeechAnalyzer.bestAvailableAudioFormat`; its capture path was left intact.
[Audio format selection](https://developer.apple.com/documentation/speech/speechanalyzer/bestavailableaudioformat(compatiblewith:considering:)).

These checks do not establish real-device model quality, Health authorization,
live Maps/Siri behavior, image generation, iCloud synchronization, or drag gestures.
Those flows need physical-device verification before submitting this upgrade.
The build still reports pre-existing deprecation and concurrency warnings outside
these changes; the compiler currently uses Swift 5 language mode.
