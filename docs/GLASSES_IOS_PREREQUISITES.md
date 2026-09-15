# Glasses-to-iPhone prerequisites — September 15, 2026

Research and project inspection only. No SDK installed, dependency changed,
account created, device activated or integration implemented.

## Actual test status

User reports successful Ray-Ban Meta native video recording with audible
narration, import to the paired iPhone, and playback there. Record as PASSED
(user-reported) glasses-native capture/playback. Project Verify did not receive
or control that recording: integration remains UNTESTED/UNIMPLEMENTED.
Computer video/save/reload worked previously; computer audio is UNRESOLVED and
further physical webcam testing is PAUSED. Synthetic results remain separate.

## Compatibility and missing information

Meta identifies Ray-Ban Meta Gen 1 and Gen 2 as supported families. That does
not identify this pair or establish its firmware compatibility. Full toolkit
access also depends on supported country availability. [Meta FAQ](https://developers.meta.com/wearables/faq/)

The latest release listed in the official repository is DAT 0.9.0, August 3,
2026. Its minimum iOS deployment target is 17.2, and its app model (DAM) is
mandatory. Older generic repository guidance saying iOS 16/Xcode 15 must not
override version-specific requirements. [Meta changelog](https://github.com/facebook/meta-wearables-dat-ios/blob/main/CHANGELOG.md)

Current CameraAccess sample prerequisites are iOS 17.2+, Xcode 26.4+, Swift 6.3+.
It exposes connection, session/preview controls, photos and optional sound in
recorded video. [Official sample](https://github.com/facebook/meta-wearables-dat-ios/tree/main/samples/CameraAccess)

The official firmware/Meta AI compatibility matrix returned a login page during
research. Exact minimum Meta AI and glasses firmware versions therefore remain
UNCONFIRMED here; do not use third-party version claims as requirements. Need
access to [version dependencies](https://wearables.developer.meta.com/docs/develop/dat/version-dependencies)
and compare the selected SDK release with the actual devices before installation.

Missing: exact glasses model/generation, firmware version, Meta AI app version,
iPhone model and iOS version, country/account availability, and whether Meta AI
offers Developer Mode. No serial number, password or account token is needed
in chat. Native playback success alone does not answer these compatibility checks.

## Video, narration and control

| Requirement | Confirmed path / remaining work |
| --- | --- |
| App-controlled start/stop | DAT starts/stops the camera stream/session. The iPhone application separately controls file recording/finalization. This is not remote control of an already recorded on-glasses file. |
| Still photo | DAT photo capture while streaming is documented. Capture/reinsertion ordering remains Project Verify's responsibility. |
| Narration from glasses | Separate system Bluetooth microphone path; it is not automatically part of DAT camera frames. Must verify the actual glasses input route and measured samples. |
| Spoken prompts to wearer | Separate iOS speech synthesis or prerecorded audio plus verified glasses output routing. Not a built-in Project Verify/DAT workflow. |
| Spoken start/stop commands | Separate recognition/command implementation; custom Hey Meta invocation or hardware-button interception is not confirmed. Do not promise it. |

Camera/session controls and photo delivery are described in [Meta's API guidance](https://github.com/facebook/meta-wearables-dat-ios/blob/main/AGENTS.md).
Microphone/speaker access uses OS Bluetooth profiles according to the [Meta FAQ](https://developers.meta.com/wearables/faq/).
Apple supports synthesizing prompts with the app audio session; routing and
speech-command recognition are additional work. [Apple speech session guidance](https://developer.apple.com/videos/play/wwdc2020/10022/)

Meta's sample AudioInputHandler uses AVAudioSession playAndRecord with
allowBluetoothHFP, then an AVAudioEngine input tap. It checks whether the route
is HFP but does not force a particular glasses input; it can continue without
usable audio. We must not copy that fallback into a narration-required gate.
[Official audio-input source](https://github.com/facebook/meta-wearables-dat-ios/blob/main/samples/CameraAccess/CameraAccess/Media/AudioInputHandler.swift)

Select the glasses port from availableInputs, request it with setPreferredInput,
and verify currentRoute after activation and every route change. Selection is a
request, not proof it took effect. Measure samples from that input before video.
[Apple input-routing contract](https://developer.apple.com/documentation/avfaudio/avaudiosession/setpreferredinput(_:))

The sample writes separate audio and video inputs into one local MOV using
AVAssetWriter; sound is optional and its comments describe phone-mic audio.
Thus the sample's sound toggle is not proof of glasses narration. Project Verify
needs synchronized timestamps, checked finalization and actual audible replay.
[Official recorder source](https://github.com/facebook/meta-wearables-dat-ios/blob/main/samples/CameraAccess/CameraAccess/Media/VideoRecorder.swift)

An open report describes photo problems during HFP audio on the glasses. Treat
concurrent audio/video/photo reliability as a physical-test risk, not a confirmed
failure of this user's pair. The authenticated microphone guide was unavailable;
verify its audio-before-camera sequencing before implementation. Do not promise
native-recording audio quality through the Bluetooth route.
[Meta repository issue 260](https://github.com/facebook/meta-wearables-dat-ios/issues/260),
[microphone guide](https://wearables.developer.meta.com/docs/develop/dat/microphones-and-speakers).

## What the existing project needs

Inspected ios/Runner, project.pbxproj, pubspec.yaml, main.dart and media/store
adapters. The iOS scaffold exists; do not recreate the app. Its deployment target
is 15.0, bundle identifier com.example.verifyApp, Swift language setting 5.0,
and no signing team was found. No Meta SDK dependency or native glasses adapter
exists. Swift language mode and the installed compiler version are different
settings; compatibility needs an actual Mac build, not a guessed setting change.

Native iOS currently selects null camera/store stubs; its media-player stub says
playback requires Chrome. Consequently browser media code is not native support:
web/local_media.js, package:web/JS interop, HtmlElementView, browser IndexedDB
and blob URLs cannot run unchanged in a native iPhone app. Browser records stay
in their original Chrome profile and do not migrate automatically to iPhone.

Retain session/codec, steps, duration gates, notes/privacy, audit, retakes and
approval logic. Implement a Swift DAT/AVFoundation adapter behind CameraService,
native durable storage behind InspectionStore/MediaStore, native playback and
platform selection in main.dart. Preserve atomic save semantics and file history.
MOV from the sample is not accepted unchanged by the current LocalMedia MIME
allow-list (video/webm or video/mp4); choose validated native MP4 output or an
explicitly tested format extension later. Do not silently rename a MOV as MP4.
Flutter supports a Swift bridge through [platform channels](https://docs.flutter.dev/platform-integration/platform-channels).

## Development access and permissions

- A Mac with compatible macOS/Xcode, iOS platform support, Flutter and required
  native dependency tooling is needed; this Windows workspace cannot build/run
  native iOS. No Mac access is established. For example, Apple's table lists
  Xcode 26.4.1 with Swift 6.3 on macOS Tahoe 26.2–26.x; choose the toolchain that
  also supports the user's actual iOS, rather than assuming an upgrade.
  [Apple compatibility table](https://developer.apple.com/xcode/system-requirements),
  [Flutter iOS setup](https://docs.flutter.dev/platform-integration/ios/setup).
- Physical iPhone, Mac trust pairing, iPhone Developer Mode, unique app bundle
  ID and signing team/provisioning. A free Apple Personal Team supports limited
  personal-device tests with seven-day provisioning; paid distribution is not
  needed merely to begin, but required capabilities must be checked for that
  team before promising it suffices. No paid enrollment authorized.
  [Apple account requirements](https://developer.apple.com/help/account/basics/about-your-developer-account).
- Meta AI pairing, supported software and Developer Mode for local SDK testing;
  user-approved registration and camera permission through Meta AI. Registration
  requires internet, even if footage stays local. Broader tester distribution
  needs a Meta developer organization/project/release channel and matching app
  identity. Developer Mode setup and version-specific DAM requirements need
  confirmation in the accessible official docs before coding.
  [Meta setup guidance](https://github.com/facebook/meta-wearables-dat-ios/blob/main/AGENTS.md),
  [Meta developer overview](https://github.com/facebook/meta-wearables-dat-ios).
- The current sample declares callback URL scheme, MWDAT app configuration,
  Bluetooth and local-network descriptions, Bonjour services and microphone
  usage. Its non-Developer-Mode configuration includes MetaAppID, ClientToken,
  TeamID. Review against the pinned SDK; do not copy old accessory/background
  recipes blindly. Phone-camera permission in the sample is for its mock phone
  feed; Photos permission is for exporting. Neither is automatically necessary
  for glasses-only capture into our private app storage. All capture remains
  foreground/user-controlled despite sample background declarations.
  [Official sample configuration](https://github.com/facebook/meta-wearables-dat-ios/blob/main/samples/CameraAccess/CameraAccess/Info.plist).
- Review SDK terms and set documented analytics/crash opt-outs before any later
  integration test. This research accepted no terms or accounts and sent no media.
  [Meta privacy controls](https://github.com/facebook/meta-wearables-dat-ios#opting-out-of-data-collection).

## Smallest real connection test (future, requires approval to implement)

Use this existing app's native iOS target with a minimal glasses adapter: connect
through Meta AI, identify this pair, obtain camera permission, and display one
live glasses frame in Project Verify. Select/verify the glasses HFP microphone
and show a measured voice level. Stop here if compatibility or audio route fails.
This establishes connection, not recording completion.

Then, only with user authorization, capture one six-second targeted demo clip
from glasses video plus glasses microphone, stop/release both, save locally,
listen, explicitly Keep, close/reopen the same iPhone app and replay that same
file. Require audible narration and picture before and after reopen. Do not
substitute a manual import or the phone microphone. Test a single photo and a
spoken prompt afterward as separate capability checks, not assumed successes.

Blockers to run: device/app versions, compatible Mac/Xcode access, Apple signing
access, Meta Developer Mode or project access, authoritative firmware matrix,
and authorization for the missing native adapters. Research-only change: no
Flutter tests/build rerun, no source/dependency changes or physical tests.

## Windows + Codemagic + TestFlight assessment — September 15, 2026

User confirms NO Mac ownership or access. This section supersedes the local-Mac,
USB pairing and free Personal Team route above for the proposed test. Windows
remains the development workstation; the iPhone and glasses remain the devices.
A personal Mac purchase is not required for the proposed hosted build route.

### Three distinct checkpoints

| Checkpoint | What it establishes | What it does not establish |
| --- | --- | --- |
| Hosted unsigned compile | Flutter/Swift and pinned DAT link on a macOS runner | Not an installable TestFlight app; no real glasses or microphone validation |
| Signed build through TestFlight | Distribution-signed IPA uploads to Apple, processes, and installs/launches on the iPhone | Does not prove Meta registration, camera frames or glasses narration |
| Physical glasses connection | Project Verify on that iPhone receives a real frame and measured audio from the identified glasses microphone | Does not yet prove complete recording/save/reopen or service verification |

Codemagic provides M2/M4 hosted macOS with Xcode 26.4.1, meeting the current Meta
sample's stated Xcode 26.4+/Swift 6.3+ baseline. Pin a compatible image/Flutter/DAT
combination later; don't rely on a moving 'latest'. No cloud build has run.
[Codemagic machine specification](https://docs.codemagic.io/specs-macos/xcode-26-4/)

### Accounts, costs and practical limits (checked today)

- Codemagic personal account: 500 free macOS M2 minutes/month, reset on the first,
  available for a proof of concept. No collaborators; Teams do not receive those
  free minutes. With billing enabled, M2 usage beyond the allowance is $0.095/min;
  M4 is $0.114/min. Do not enable billing now. Account eligibility/allowance is not
  established until the user checks their account. [Official pricing](https://docs.codemagic.io/billing/pricing/)
- TestFlight route requires Apple Developer Program membership: USD $99/year,
  region-dependent local pricing and possible qualifying fee waivers. A free
  Personal Team is not a substitute for TestFlight distribution. Individual
  enrollment requires identity/account verification; organization enrollment has
  additional legal-entity verification requirements. No membership purchased.
  [Apple enrollment](https://developer.apple.com/programs/enroll/)
- TestFlight is included in the developer distribution route, with up to 100
  eligible internal App Store Connect users or 10,000 external testers. Builds
  expire after 90 days. Start with the owner as an internal tester; external
  distribution introduces beta-review requirements. Apple processing/export-
  compliance responses and app metadata are still needed; installation is not
  immediate merely because compilation passed.
  [TestFlight](https://developer.apple.com/testflight/),
  [internal testing](https://developer.apple.com/help/app-store-connect/test-a-beta-version/add-internal-testers).
- Meta: public DAT developer preview is available; no separate toolkit subscription
  price was identified in the official material reviewed. This is not a guarantee
  of permanent free access or all-country/account eligibility. Meta AI account,
  supported country/device/software, SDK terms and app registration are separate
  from Apple approval. For testers without Meta Developer Mode, plan the Meta
  organization/project/release-channel path with matching MetaAppID, ClientToken,
  Apple TeamID and callback configuration. Confirm current requirements in the
  developer center before paying for Apple enrollment. [Meta overview](https://github.com/facebook/meta-wearables-dat-ios),
  [Meta FAQ](https://developers.meta.com/wearables/faq/).

For an unsigned compile, the build service would need authorized access to an
approved source snapshot but not physical recordings or Apple distribution keys.
Uncommitted local changes are NOT included in the currently pushed checkpoint.
Do not build an old remote checkpoint and call it the current media implementation.
Any future source transfer/checkpoint needs separate authorization; no upload now.

For installation, use a unique bundle ID/app record in App Store Connect, Apple
Distribution signing certificate/private key and app-store provisioning profile.
Codemagic can manage signing via Apple integration; its publishing documentation
uses a dedicated App Store Connect API key with App Manager access, issuer ID
and key ID. These are sensitive credentials for later approved configuration,
not something to paste into chat or commit. [Signing](https://docs.codemagic.io/yaml-code-signing/signing-ios/),
[publishing](https://docs.codemagic.io/yaml-publishing/app-store-connect/).

TestFlight installation does NOT require iPhone Developer Mode or plugging the
phone into a personally owned Mac. Meta AI/glasses Developer Mode is a different
setting and may still be needed for the chosen Meta registration route.
[Apple explanation](https://developer.apple.com/videos/play/wwdc2022/110344/)

### Unchanged technical blockers, rechecked

DAT 0.9 requires iOS 17.2+, but our Runner targets 15.0. Existing native camera
and store factories return null, and native playback is a Chrome-only placeholder.
Browser getUserMedia/MediaRecorder, DOM player and IndexedDB need native adapters;
the web demo does not become a working iPhone capture app merely by cloud-building
it. Keep session, audit, duration, acceptance and privacy rules; add native
capture/AVFoundation storage/playback behind the existing interfaces only in a
later authorized implementation batch. Native storage is distinct from Chrome's
existing records; preserve both. See prior source inspection and references above.

Official Meta guidance still separates camera data from OS Bluetooth microphone
and speaker access. Native recording audio success does not establish the DAT
path. The minimum test must verify actual glasses HFP input and measured samples
alongside camera frames; no silent substitution of the iPhone microphone. Hosted
runners cannot physically connect to the user's glasses and do not replace this
test. Windows also lacks local Xcode device debugging, so a later native test
build needs useful on-device status/error feedback.

Still missing: glasses model/generation, firmware, Meta AI app version, iPhone
model/iOS, supported account/country access, Meta Developer Mode or release-channel
eligibility, Apple membership status and Codemagic account status. The official
[firmware/app matrix](https://wearables.developer.meta.com/docs/develop/dat/version-dependencies)
still returned a login page; exact firmware/Meta AI minimums remain unverified.

Recommendation: Codemagic + internal TestFlight is a viable proposed build/install
route, not yet a verified glasses integration. No purchase is recommended before
hardware/software and Meta access checks. Smallest later test remains one real
frame plus glasses-microphone level in Project Verify; then a separately approved
short recording with explicit Keep and same-file playback after reopening.

Next single user action: iPhone Settings > General > About; report Model Name and
iOS Version only. Do not send serial number, IMEI or account credentials. This
checks the known iOS floor without purchasing or creating anything.

Assessment changed documentation only. No source/dependency edits, uploads,
accounts, billing, SDK install, build, commit or push. Existing recordings and
uncommitted work preserved. Webcam audio remains unresolved and paused.
