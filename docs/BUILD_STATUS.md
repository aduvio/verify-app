# Project Verify — foundation repairs

Scope: SCR-001 intake, SCR-002 guided inspection, SCR-003 advisory review.
The app is a demo prototype, not a completed service-verification product.

## Approved product direction

Chalmette pilot with one pair of glasses. Glasses-first operation is intended;
screen controls are the prototype/fallback. Capture targeted final-verification
clips, not the whole oil change. Drain plug and either filter location require
five seconds. Under vehicle: drain plug, accessible filter, differential/axle,
engine underside, residual-oil cleanup. Under hood: top-mounted filter if
applicable, dipstick photo then reinsertion, cap/component touch sequence,
engine-bay sweep, tire-pressure statement, reminder reset. Tire pressure is not
an AI measurement. AI is advisory; unresolved critical concerns block approval.
All employees may add notes; internal and customer-visible text stay separate.

Future oil source: AMSOIL. Future filter source: ShowMeTheParts restricted to
Service Champ. Do not invent specifications or filter part numbers. Square
remains the POS, with no current integration. Future report: simple page, one
main video button, secure link, no customer account.

## Implemented locally

- Shared session and in-memory repository boundary; unique ID, timestamps,
  technician/location, intake, checks, capture metadata, observations, decisions,
  separate authored notes, demo approval, and audit history.
- Explicit demo readiness, separate provenance and verification status; no
  real-service readiness or approval can be issued.
- Required-check gating, filter relocation with five-second minimum, simulated
  dipstick photo with separate reinsertion before touch sequence.
- Serialized capture operations with cancellation and stale-result guards;
  attempt histories retain rejected, failed, cancelled and superseded metadata.
- Required AI concerns stay blocking when pending, further inspection, or
  confirmed without documented correction and recheck. Reasoned dismissals have
  technician/time attribution. An accidental assessment can be corrected by a
  reasoned dismissal with explicit acknowledgment that it is not an actual
  concern; earlier decisions remain in the audit. Actual confirmed concerns need
  correction and successful recheck; separate failed checks still block approval.
- Manual demo acknowledgments; relevant changes invalidate them.
- Customer-data projection allow-list excludes internal notes, audit history,
  raw AI observations, synthetic specifications and evidence.

## Simulated behavior

Customer lookup, VIN decoding, oil/filter placeholders, Square linking, photo
and video capture, and advisory AI scenarios. No actual video or photo exists.
No camera, glasses, speech, external AI, provider lookup, POS link, delivery,
or durable storage is connected. Unsupported intake actions explain this.

## Known limitations

Everything is held in process memory. Closing/reloading can lose sessions;
retake metadata is not durable archiving. Technician identity is a demo identity,
not authenticated. SCR-004/report generation and delivery do not exist. Approval
here is a demo acknowledgment and cannot authorize a real report. There is no
manager override. Existing platform scaffolds still need device validation.

## Validation — September 7, 2026

- Changed Dart files formatted with the installed SDK formatter.
- `flutter analyze --no-pub`: passed, no issues (8.9 seconds).
- `flutter test --no-pub`: **42 passed**, including unit and widget tests (6 seconds).
- `flutter build web --no-pub`: passed (43 seconds), output in `build/web`.
  The compiler's Wasm dry run also succeeded; this is not a Wasm runtime test.
- Populated SCR-001, SCR-002 (both stages), SCR-003 and review-dialog widget
  layouts checked at 360×800 and 1440×1000; no overflow exceptions.
- Compiled browser preview checked at phone and desktop widths: startup,
  explicit demo intake, simulated readiness, shared-session navigation and
  recording controls. Browser verification caught and fixed a JavaScript-only
  session-ID bit-shift error that VM tests and a successful build did not reveal.
- An extra targeted `flutter test --no-pub --platform chrome
  test/inspection_session_test.dart --plain-name "unique sessions and repository
  preserve identity and timestamps"` stayed at `loading ...` without a diagnostic
  or test result and was cancelled. This optional browser-platform runner check
  is **unperformed**, not passed. The required default suite passed, and the
  compiled JavaScript startup was verified directly in the browser after the fix.
- No dependency changes, global tool installations, commits, pushes, deployments,
  live service connections, or customer sends. Repair branch:
  `codex/demo-foundation-repairs`.

Tests cover provenance, demo progression, critical flags and separate failed
checks, reason/identity/time attribution, explicit approval and successful
recheck, invalidation, both filter locations and five-second boundaries,
dipstick ordering, shared-session navigation and notes, customer projection,
rapid taps, pending-operation exit, service failures, stale results and retained
retakes. Controlled services and clocks make recording tests deterministic.

## Files in this repair batch

Created:
- `AGENTS.md`, `docs/BUILD_STATUS.md`.
- `lib/models/inspection_session.dart`, `lib/models/provenance.dart`.
- `lib/services/inspection_repository.dart`, `lib/services/capture_controller.dart`.
- `lib/widgets/session_banner.dart`, `lib/widgets/reason_dialog.dart`.
- `test/inspection_session_test.dart`, `test/capture_controller_test.dart`,
  `test/screens_test.dart`, `test/support.dart`.

Modified:
- `lib/screens/new_inspection_screen.dart`, `lib/screens/guided_inspection_screen.dart`,
  `lib/screens/ai_review_screen.dart`.
- `lib/models/ai_observation.dart`, `lib/models/verification_item.dart`.
- `lib/services/mock_ai_review_service.dart`, `lib/services/mock_recording_service.dart`,
  `lib/services/mock_verification_service.dart`.
- `lib/widgets/readiness_row.dart`, `lib/widgets/verification_row.dart`.

The existing Material theme, card sections and screen navigation remain;
controls wrap for phones and synthetic media tiles are replaced by actual
session attempt metadata. No SCR-004 implementation was added.

## Viewing the app

A temporary loopback-only preview is served at `http://127.0.0.1:8765` while its
local helper is running. The helper lives in ignored `build/verify-preview.cjs`;
it is not a deployment or application dependency. To start a fresh development
session from the project directory, run `flutter run -d chrome --no-pub`.

Manual acceptance checks:
1. Stop a drain-plug/filter simulation before five seconds, then capture at least
   five seconds and keep/retry. Confirm earlier attempts remain metadata only.
2. Keep a simulated dipstick photo, separately confirm reinsertion, and then
   capture the touch sequence. Retaking the photo requires reinsertion again.
3. Confirm a critical concern or choose further inspection; demo approval must
   remain blocked. Document correction plus successful recheck, manually check
   acknowledgments, then change evidence/decision and verify they reset. Navigate
   back/forward and confirm the same customer, vehicle, notes and decisions remain.

## Future work (requires approved scope)

Durable repository, authenticated employee identity, real glasses/camera evidence,
provider integrations, real-service verification policy, AI integration and
secure customer report/delivery. Do not treat these as implemented.

## SCR-003 concern-resolution repair — September 9, 2026

Reproduced the reported running-browser state: `Needs Further Inspection` with
reason `mechanic needed`, blocked approvals, and no correction action. Saving
`Confirm Concern` revealed the old conditional action. The screen did not explain
that prerequisite, used raw enum labels, and did not identify individual approval
blockers. The previous sticky `concernEstablished` state also prevented legitimate
correction of an accidental confirmation via dismissal.

Focused changes:
- Readable assessment labels and explicit next-step instructions. The prominent
  `RECORD SIMULATED CORRECTION + RECHECK` action is always shown for a required
  observation and enabled after confirming the concern.
- Required correction/recheck descriptions and explicit successful-recheck
  acknowledgment to clear a confirmed concern. `SAVE FAILED / INCOMPLETE RECHECK`
  records an unsuccessful result and keeps approval blocked.
- Dismissal requires a reason plus explicit determination that this is not an
  actual concern. This can correct an accidental earlier assessment. It never
  completes independent failed or missing required checks.
- Assessment audit entries retain previous/new decisions, reason, technician,
  time, and the explicit dismissal determination. Correction/recheck audit entries
  retain both descriptions and outcome. Earlier audit entries and notes survive;
  dependent approvals still reset on decisions/evidence changes.
- SCR-003 lists the actual outstanding concerns/checks and the remaining manual
  acknowledgments. It never selects approval boxes automatically.

Files touched in this focused follow-up: `lib/models/ai_observation.dart`,
`lib/models/inspection_session.dart`, `lib/screens/ai_review_screen.dart`,
`lib/widgets/reason_dialog.dart`, `test/inspection_session_test.dart`,
`test/screens_test.dart`, and this document. Added `test/concern_workflow_test.dart`.
The earlier sticky-confirmation regression was updated to the newly approved
reassessment behavior, with assertions for explicit dismissal determination,
retained history, and independent blockers; no errors were suppressed.

Validation:
- Changed Dart files formatted.
- `flutter analyze --no-pub`: passed, no issues (6.0 seconds).
- `flutter test --no-pub`: **48 tests passed** (6 seconds), including six new
  button-driven workflow regressions and the existing phone/desktop layout checks.
- `flutter build web --no-pub`: passed (35.7 seconds).
- Verified the actual rebuilt browser app through intake and required guided
  checks, then further inspection (`mechanic needed`) -> confirmation -> empty
  form validation -> failed/incomplete recheck (still blocked) -> successful
  correction/recheck -> four manual acknowledgments -> demo completion.
- Also verified reassessment resets approval, further inspection -> reasoned
  dismissal with explicit acknowledgment -> manual approval -> demo completion.
  The internal browser-test note survived; no browser runtime errors were logged.
  Model/widget tests verify the retained audit history and missing-evidence gates.
- Used a separate updated preview tab to avoid refreshing away the original
  running demo session. Preview: `http://127.0.0.1:8765/?review-fix=20260909`.
  Existing loaded tabs keep their older code until refreshed; refresh loses
  in-memory session data. The original tab was used for the requested reproduction
  and now has a new reasoned confirmation audit entry.

To complete the simulated correction scenario: `CONFIRM CONCERN` -> enter reason
-> `SAVE` -> `RECORD SIMULATED CORRECTION + RECHECK` -> describe correction and
recheck -> check the successful-recheck acknowledgment -> `SAVE` -> manually
select the four approval checkboxes -> `COMPLETE DEMO REVIEW`. Any remaining
required inspection checks must also be completed. All actions remain simulated;
no real evidence, durable storage, customer report, or delivery was added.

Continued on `codex/demo-foundation-repairs`, preserving earlier uncommitted work.
No dependency additions, commits, pushes, deployments, overrides, or SCR-004 work.
