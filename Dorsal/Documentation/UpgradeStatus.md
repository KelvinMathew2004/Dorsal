# iOS 27 upgrades

`main` at `7b17cae` contains the App Review fixes, requested recording UI refinements,
permission copy, and build 1.0 (3). `ios-27-upgrades` is rebased onto it. The original
upgrade work is preserved at `backup/ios-27-upgrades-before-rebase-20260923`.

## Compatibility and API decisions

- Explicit soft scroll edges on iOS 27 preserve the existing layouts and glass
  materials. The `.soft` API itself dates to iOS 26; the modifier is gated here
  to retain the previous iOS 26 presentation.
  [Scroll edge style](https://developer.apple.com/documentation/swiftui/scrolledgeeffectstyle/soft).
- Profile uses native iOS 27 reorder containers, with the existing grouping labels
  and local saved order. Drops on a root group add a child; moving a child to the
  root unlinks it. Invalid nested groups and mixed types are rejected. iOS 26
  retains the existing drop delegates.
  [Reordering collections](https://developer.apple.com/documentation/swiftui/reordering-items-in-lists-stacks-grids-and-custom-layouts),
  [custom transfer types](https://developer.apple.com/documentation/uniformtypeidentifiers/defining-file-and-data-types-for-your-app).
- Foundation Models tools share a three-call budget. Search excerpts and metric
  histories are bounded, dates use the local calendar day, and missing scores
  remain missing. Compatibility/context failures can fall back to the original
  fresh session; cancellation, refusals and unavailable services are not blindly
  retried. Only ephemeral question answers can access the sleep tool.
  [Tool calling](https://developer.apple.com/documentation/foundationmodels/expanding-generation-with-tool-calling).
- Health sleep is read-only and opt-in from Settings. A completed authorization
  sheet does not prove read access was granted. Missing data does not mean zero
  sleep or denied permission. Overlapping samples are clipped and deduplicated;
  tracks from different sources are not added together. Sleep values stay in
  memory and are excluded from the CloudKit journal, generated saved analysis,
  and recovery snapshots.
  [Authorization](https://developer.apple.com/documentation/healthkit/authorizing-access-to-health-data),
  [sleep samples](https://developer.apple.com/documentation/healthkit/hkcategoryvaluesleepanalysis),
  [App Review 5.1.3](https://developer.apple.com/app-store/review/guidelines/).
- iOS 26 retains automatic ImageCreator illustrations. Apple discontinued that
  API on iOS 27, so the supported fallback is an interactive, prefilled Image
  Playground sheet. Accepting an image animates it into the existing dream view.
  No external generation service or silent image upload has been added.
  [Apple's announcement](https://developer.apple.com/news/?id=dz9wvq0r).

## Validation of the initial upgrade pass

With Xcode 27.0, all **28 regression tests passed on both iOS 26.5 and iOS 27.0**
(iPhone 17 Pro Max simulators). The unsigned generic iOS Release build succeeded.
The native profile hierarchy also rendered with grouped entities on iOS 27 and
was visually inspected. Tests cover reorder/group/unlink persistence, sleep
aggregation, bounded tools, local dates, image availability, recording recovery,
and the existing on-disk journal migration.

The iOS 27 speech fixture needed Int16 input and explicit buffer lifetime while
reading its sample pointer. Production already requests a supported format using
`SpeechAnalyzer.bestAvailableAudioFormat`; its capture path was left intact.
[Audio format selection](https://developer.apple.com/documentation/speech/speechanalyzer/bestavailableaudioformat(compatiblewith:considering:)).

These checks do not establish real-device model generation, Health authorization,
iCloud synchronization, or native drag gesture behavior. Those flows still need
physical-device verification before the upgrade branch is submitted. Existing
compiler warnings outside the changed features remain; builds are not warning-free.
