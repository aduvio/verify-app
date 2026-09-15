# Native iOS connection test — September 15, 2026

## Scope and current evidence

Browser checkpoint `51d5f3f856871da106386e1b01128d14daf4c978` was committed and
pushed to `codex/demo-foundation-repairs` before this work. User-reported browser
video, local saving/reload and five-screen demo tests passed. Webcam microphone
audio remains unresolved; further physical webcam testing is paused.

User supplied: iPhone 15 Plus, iOS 26.6.2; Ray-Ban Meta Wayfarer 00MJ;
glasses release 128.0.0.203.324; Meta AI 289.0.0.21.157; Developer Mode on;
DAT app installed, glasses showing DAT SDK 0.9.0.26.0. Glasses-native narrated
video and paired-iPhone playback passed (user report). This is not a Project
Verify integration result. Runtime compatibility still needs the physical test;
the login-protected version matrix could not be independently inspected.

This branch adds connection-test source, not a complete glasses recording
adapter. No recording, narration, inspection persistence, acceptance, merge,
report generation or delivery is added to the native test. SCR-001–005 remain
unchanged. Browser footage/site storage is never read or migrated by this test.

## Exact dependency and startup

SPM remote: https://github.com/facebook/meta-wearables-dat-ios
Exact version **0.9.0**, linked products **MWDATCore** and **MWDATCamera** only.
No MockDevice, Display or new Dart dependencies. This is **developer preview**.
The tag's published arm64 Swift interfaces were inspected before writing the
bridge: iOS 17.2 target, compiler Swift 6.3.3; the project minimum is now 17.2.
Swift language mode remains 5.0; Codemagic's pinned Xcode 26.6 supplies the
compiler. Native package resolution/Swift compilation cannot run on Windows.

AppDelegate calls guarded `Wearables.configure()` once before Flutter startup.
The bridge is registered through `didInitializeImplicitFlutterEngine`, retaining
GeneratedPluginRegistrant and the current Flutter scene lifecycle. Registration
callbacks require our `projectverify` scheme and `metaWearablesAction` query;
SceneDelegate handles warm and cold scene callbacks, AppDelegate the legacy URL
path. Callback errors surface on the test page. Flutter's automatic deep-link
routing is disabled so Meta callbacks do not become Flutter navigation routes.

Info.plist uses Meta's documented `AppLinkURLScheme = projectverify://`,
`MetaAppID = 0` for Developer Mode, `fb-viewapp` query scheme and
`com.meta.ar.wearable` accessory protocol. Current sample Bluetooth/local-network
descriptions and `_bonjour._tcp` declaration are included. Both Analytics.OptOut
and CrashReporting.OptOut are true. No production app ID, client token or signing
team is invented. Bluetooth/accessory transport background declarations do not
authorize capture: entering the background stops the session and invalidates
pending camera work. There is no automatic capture resume.

No phone-camera, microphone or Photos-library permission is requested: this
test uses DAT's explicit glasses-camera permission and holds a received photo
in memory. The sample's audio/processing background modes and phone-camera mock
permissions are intentionally omitted because those operations are not present.
Physical behavior of these transport/permission settings is still unvalidated.

## Bridge and developer page

Flutter `WearablesService` isolates platform code. iOS uses MethodChannel
`project_verify/wearables` and EventChannel `project_verify/wearables/events`;
other platforms report unavailable without invoking hardware.

| Flutter operation | Verified DAT 0.9 API / behavior |
| --- | --- |
| status | registrationState, devices, device link/compatibility and current session/camera/stream states |
| register | startRegistration; completion comes through handleUrl/state events |
| startSession | createSession(AutoDeviceSelector), DeviceSession.start; observes state/error streams |
| stopSession | Stream.stop, Camera.stop, DeviceSession.stop; drops in-memory photo; cancels listeners and stale operations |
| requestCamera | check/requestPermission(.camera), then DeviceSession.addCamera after started |
| startStream / stopStream | Camera.stream.start/stop; raw low-resolution 24 fps requested |
| capturePhoto | stream.capturePhoto(.jpeg); photoDataPublisher delivers in-memory image; rejection/15-second timeout shown |

The page reports actual frame counts, not a simulated video preview. Received
test photos display locally but are not saved to inspection storage. Buttons
do not claim that starting a stream records a file or audio. Explicit controls,
pending locks and session generation checks prevent automatic/late starts.
Refresh status reads current device link/compatibility if no device-list event
has arrived. SDK availability means configured, not physical compatibility.

Enable only in a non-release build with `--dart-define=WEARABLES_TEST=true`.
It replaces the initial page only for this developer build; normal builds keep
their existing home screen. The default web build does not expose this page.

## Audio: established versus still unknown

1. **No embedded narration in DAT camera frames:** 0.9 Camera exposes video
   frames, photo data and state/error publishers, with no microphone-data
   publisher. Frame receipt cannot establish that speech was captured.
2. **Separate OS route:** Meta documents microphone/speaker use through OS
   Bluetooth profiles. Its current AudioInputHandler configures AVAudioSession
   playAndRecord with allowBluetoothHFP and reads AVAudioEngine input samples.
   Audio and camera video are separate inputs to the sample's file writer.
3. **No first-class DAT microphone API implemented here.** iOS audio is a future
   separate implementation, not an unsupported guess or a claim that glasses
   cannot supply audio. It must select the actual glasses input, verify the
   returned route and measured speech, synchronize file inputs, then demonstrate
   audible Project Verify playback. Phone-microphone fallback must not silently
   satisfy a glasses-narration requirement.

Native glasses playback success does not validate this third-party Bluetooth
route. No physical audio success is claimed and no speculative audio code added.
Spoken prompts/commands and inspection media storage remain future work. Browser
getUserMedia/MediaRecorder, IndexedDB and HTML playback cannot be reused unchanged
on iOS; the session/retake/review rules can be reused behind native adapters.

## Manual unsigned cloud compile

File: `codemagic.yaml`; workflow **ios-meta-unsigned-debug**
(display name **iOS Meta unsigned debug compile**).
Branch: **codex/ios-meta-integration**.
Runner: **mac_mini_m2**, Flutter **3.47.2**, Xcode **26.6**, timeout 45 minutes.

It resolves the existing pub lockfile, analyzes/tests Flutter, generates iOS
configuration, resolves SPM dependencies with xcodebuild, then runs
`flutter build ios --debug --no-codesign --no-pub --dart-define=WEARABLES_TEST=true`.
Runner.app and the resolved package file are compile artifacts, not a signed
IPA/TestFlight installation. Exact package version is committed; Package.resolved
will be generated by the first macOS resolution, not fabricated on Windows.
No triggers, publishing, signing credentials, paid services or integrations are
configured. The workflow has **not been started**.

No Apple account/signing or attached phone is needed for this unsigned compile.
Codemagic needs the pushed branch, access to its M2 image and public package
downloads, and available build quota. Actual Xcode/SPM/Swift errors remain possible
until the first run; Flutter checks do not validate native Swift or permissions.
App identity/signing and a separately authorized physical installation route are
required later. Do not confuse unsigned debug compilation with TestFlight.

After a compiled, signed test is separately authorized and installed: open the
developer page, register with Meta AI, start a glasses session, explicitly grant
camera access, start streaming and see a nonzero frame count. Capture one test
photo, view it, stop/release. A Meta permission round trip may end the current
session when backgrounded; start it again explicitly after permission returns.
That is the smallest camera connection test. It does not test narration or
recording persistence. This batch stops before triggering the cloud build.

## Official references inspected

- [Version 0.9.0 package](https://github.com/facebook/meta-wearables-dat-ios/blob/0.9.0/Package.swift)
  and [Core Swift interface](https://github.com/facebook/meta-wearables-dat-ios/blob/0.9.0/MWDATCore.xcframework/ios-arm64/MWDATCore.framework/Modules/MWDATCore.swiftmodule/arm64-apple-ios.swiftinterface),
  [Camera Swift interface](https://github.com/facebook/meta-wearables-dat-ios/blob/0.9.0/MWDATCamera.xcframework/ios-arm64/MWDATCamera.framework/Modules/MWDATCamera.swiftmodule/arm64-apple-ios.swiftinterface).
- [Meta 0.9 README and telemetry opt-outs](https://github.com/facebook/meta-wearables-dat-ios/blob/0.9.0/README.md).
- [Current setup guidance](https://github.com/facebook/meta-wearables-dat-ios/blob/main/.cursor/rules/getting-started.mdc)
  and [sample Info.plist](https://github.com/facebook/meta-wearables-dat-ios/blob/main/samples/CameraAccess/CameraAccess/Info.plist).
  Generic guidance has older OS prerequisites; the actual 0.9 binary minimum
  takes precedence. The sample adds current local-network declarations.
- [Current audio sample](https://github.com/facebook/meta-wearables-dat-ios/blob/main/samples/CameraAccess/CameraAccess/Media/AudioInputHandler.swift),
  [Meta FAQ](https://developers.meta.com/wearables/faq/),
  [Apple preferred-input API](https://developer.apple.com/documentation/avfaudio/avaudiosession/setpreferredinput(_:)).
- [Flutter iOS setup](https://docs.flutter.dev/platform-integration/ios/setup),
  [Flutter platform channels](https://docs.flutter.dev/platform-integration/platform-channels),
  plus installed Flutter 3.47.2 startup template and iOS config-only build source.
- [Codemagic Xcode 26.6 image](https://docs.codemagic.io/specs-macos/xcode-26-6/),
  [Codemagic YAML](https://docs.codemagic.io/yaml-basic-configuration/yaml-getting-started/).
