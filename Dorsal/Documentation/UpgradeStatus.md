# Deferred iOS 27 work

`main` contains the App Review error fixes and build 1.0 (3).
`ios-27-upgrades` preserves the complete development work, including HealthKit,
Foundation Models tool calling, Shortcuts/control code, onboarding changes, and
compatibility work. It also includes `main` in its history.

## Automatic illustrations remain a requirement

On iOS 26, Dorsal continues to create illustrations automatically with ImageCreator.
The additional dream-detail Image Playground button is restricted to iOS 27 and
later on this branch; it does not change the iOS 26 flow.

On iOS 27, the current sheet is only a provisional interactive alternative.
It does **not** fulfill the requested automatic generation experience. Do not
consider that migration complete or ship it as the final replacement.

Apple discontinued ImageCreator on iOS 27 and recommends either its interactive
Image Playground sheet or another image-generation service:
https://developer.apple.com/news/?id=dz9wvq0r

A future change must evaluate an automatic replacement, its on-device/cloud
requirements, latency, and privacy, while letting the user continue reading the
dream as the image is generated. No new provider or network upload is implemented
in this branch split.
