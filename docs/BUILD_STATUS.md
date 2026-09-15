# Project Verify — foundation repairs

Current status is summarized in the real local media section at the end. Earlier
sections are historical checkpoints, including their former memory-only limits.

Scope: SCR-001 intake, SCR-002 guided inspection, SCR-003 advisory review,
SCR-004 demo customer preview and simulated delivery, SCR-005 demo completion.
The app is a demo prototype, not a completed service-verification product.

## Approved product direction

Chalmette pilot with one pair of Ray-Ban Meta glasses as the intended primary
recording device. Glasses-first operation is intended; the computer camera is
only a development test device and fallback. Screen controls are the prototype/fallback. Capture targeted final-verification
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
not authenticated. SCR-004 now generates an in-memory demo preview; live delivery
and secure hosting do not exist. Approval
here is a demo acknowledgment and cannot authorize a real report. There is no
manager override. Existing platform scaffolds still need device validation.

## Historical foundation validation — September 7, 2026

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

## SCR-004 customer preview and simulated delivery — September 9, 2026

### Foundation checkpoint

Before SCR-004 edits, `flutter analyze --no-pub` passed with no issues (7.6s)
and `flutter test --no-pub` passed all 48 existing tests (6s).
Foundation commit: `52be816aeb4fab02e0700d53f1237d780ba21e98`
(`Repair demo inspection foundation and concern resolution`). Push succeeded
to the existing `https://github.com/aduvio/verify-app.git` remote on
`codex/demo-foundation-repairs`. No merge, force push or remote change.
Only foundation source, tests and supporting instructions/docs were committed;
no generated build output or runtime session data was included.

### Implemented locally

- After the four manual SCR-003 acknowledgments and COMPLETE DEMO REVIEW,
  VIEW DEMO CUSTOMER REPORT opens SCR-004 using the same session.
- An immutable customer projection snapshot carries inspection ID and report
  revision, store, technician, creation time, sample customer/vehicle identity,
  documented demo checks and an intentionally customer-visible recommendation.
- The allow-list excludes internal notes, raw AI observations/confidence,
  capture attempts (including rejected/superseded), and audit details. No demo
  values enter verifiedFacts. Recommendations are separate from service facts.
- One prominent Watch My Inspection area clearly states playback is unavailable.
  It has no pretend play action. Specifications, quantity and filter number
  remain unavailable. Preview says DEMO — NOT A LIVE SERVICE REPORT.
- Separate technician controls select SMS/email using current session contacts,
  explain missing/invalid contacts, and allow explicit correction. Contact changes
  require renewed SCR-003 approval. No contact is invented by SCR-004.
- Two manual preview/recipient/privacy confirmations gate SIMULATE SEND — DEMO.
  Success explicitly says nothing was sent. A demo failure switch exercises
  failure handling. Pending operations lock conflicting controls and serialize
  at the session boundary, including across screen navigation.
- Evidence, decisions, customer recommendations, contacts and approval changes
  invalidate the snapshot and delivery review. Channel changes reset recipient
  review. Internal notes remain private without invalidating the customer report.
  Readiness is checked before preparing/sending and again after asynchronous
  completion. Stale results cannot claim successful simulation.
- Snapshot, confirmations, outcomes and attributed audit events remain in the
  existing in-memory session; returning between screens preserves that session.

### Simulated and incomplete

Delivery is a mock service interface only. There is no SMS/email transport,
upload, secure hosted link, Square call, actual media playback, or live approval.
The link is an inactive labeled placeholder, with the future no-account policy
explained. Refresh/close can lose all state. Technician identity remains a demo
identity. SCR-005 is not built. Real evidence, providers, secure hosting/delivery,
authentication and durable storage remain future work.

### Validation

- Changed Dart files formatted with installed SDK; no dependencies added.
- `flutter analyze --no-pub`: passed, no issues (6.1s).
- `flutter test --no-pub`: **58 passed** (7s), retaining all 48 foundation tests
  and adding ten SCR-004 unit/widget tests. Covers projection privacy and immutable
  identity/revision, contacts, confirmations, blockers, invalidation, overlapping
  sends, stale completion, mock failure, disposal/navigation and responsive flow.
- `flutter build web --no-pub`: passed (36.0s). Wasm dry run succeeded; this does
  not claim a Wasm runtime test. The earlier optional Chrome test-runner stall
  remains historical/unperformed; no stalled check is counted as passing.
- Browser: completed intake, required guided checks, reasoned concern dismissal,
  manual SCR-003 approval -> SCR-004. Confirmed session data and recommendation,
  unavailable playback, excluded internal/AI data, manual send gating, pending
  lock, honest success and injected failure. Selected existing session email;
  entered invalid test contact to verify explicit blocking, restored the original
  sample email, then completed renewed manual approval and fresh preview.
- Browser layouts checked at 360×800 and 1440×1000, including phone delivery
  controls; no visible overflow and no logged runtime errors. Widget flow tests
  also cover 360px and 1440px. Browser viewport override reset after checking.
- `git diff --check`: passed. SCR-004 changes remain **uncommitted** for review.
  No live services, customer sends, deployment, or SCR-005 work.

Files created: `lib/screens/customer_report_screen.dart`,
`lib/services/mock_delivery_service.dart`, `test/customer_report_test.dart`.
Files modified: `lib/models/inspection_session.dart`,
`lib/screens/ai_review_screen.dart`, `AGENTS.md`, `docs/BUILD_STATUS.md`.

Updated loopback preview: `http://127.0.0.1:8765/?report-preview=20260909-built`.
The prepared browser tab is at SCR-004; opening the URL in a new tab starts a new
in-memory demo. Earlier browser tabs were preserved and still run their old code.
To start independently: `flutter run -d chrome --no-pub` from the project folder.

Manual checks:
1. Verify the sample identity/recommendation and unavailable video area; confirm
   internal notes and raw AI observations are absent from the customer preview.
2. Check both delivery confirmations, then SIMULATE SEND — DEMO; verify nothing
   was sent. Enable the failure switch, review again and verify honest failure.
3. Change a contact or return to SCR-003 and change the recommendation; confirm
   renewed manual approval and preview/recipient review are required.

## SCR-005 demo completion — September 9, 2026

### Approved SCR-004 checkpoint

Committed as `746d442` (Add approved demo customer report and simulated delivery)
and successfully pushed to the existing origin on `codex/demo-foundation-repairs`.
Checkpoint checks passed: analyzer no issues (7.1s), all 58 tests (8s), web build
(38.1s). No merge, force push, remote change or generated builds in the commit.

### Implemented

- A successful simulated send for the currently approved snapshot opens SCR-005.
  Failed/stale operations remain on SCR-004 and cannot create completion records.
- Immutable per-attempt records retain snapshot, inspection/revision, selected
  method, actual recipient, start/finish time and simulated outcome. Prior failed,
  stale and successful attempts survive retries and reopening.
- Inspection completion is a separate record referencing the successful attempt
  and immutable report snapshot. Its timestamp matches the recorded completion
  event; rebuilds do not create new times. No real inspection approval is issued.
- Completion shows session-derived demo identity, summary and recommendations,
  honest delivery/video/hosting status, and a collapsed staff-only section with
  separate internal notes, advisory AI scenarios, attempt history and actual
  event/time/actor details. Staff data never enters the customer projection.
- Completed sessions reject edits and duplicate sends. Completion replaces prior
  routes; ordinary Back cannot reopen the inspection. Pending send blocks Back.
- REOPEN INSPECTION requires a reason and explicit confirmation. Cancel changes
  nothing. Confirming records the technician/time/reason, creates a new editable
  revision under the same inspection ID, retains evidence and old completion
  snapshots, and clears dependent approvals. Returns to guided inspection, where
  the existing review sequence must be completed before another simulated send.
- START NEW INSPECTION retains the old record in the same in-memory repository
  and returns to a clean SCR-001 session with unique ID, same technician/store,
  and no prior intake, notes, checks, decisions, approvals or delivery state.
  Repeated requests for the same completed revision return the same new session.
- VIEW HISTORY is only an explanatory placeholder. No SCR-006 exists.

### Remaining limitations

All records and audit history remain in process memory; refresh/close can lose
them. No real recording, video playback, secure hosting, SMS/email, uploads,
Square connection, live approval, authenticated identity or durable storage.
The completion screen is a demo acknowledgment, not proof of real service or
customer delivery. SCR-005 changes remain uncommitted pending user review.

Files created: `lib/screens/inspection_complete_screen.dart`,
`test/inspection_complete_test.dart`.
Files modified: `lib/models/inspection_session.dart`,
`lib/services/inspection_repository.dart`, the four existing screen files
(`new_inspection_screen`, `guided_inspection_screen`, `ai_review_screen`,
`customer_report_screen`), `AGENTS.md`, and this document.

### Validation

- Changed Dart files formatted; no dependencies added or tools upgraded.
- `flutter analyze --no-pub`: passed, no issues (6.3s).
- `flutter test --no-pub`: **68 tests passed** (8s), all 58 previous tests retained
  unchanged plus ten completion/reopen/repository/widget regressions. Early
  off-screen test tap warnings were corrected with precise header/physical-click
  targets; final run had no such warnings. No assertions or errors suppressed.
- `flutter build web --no-pub`: passed (35.3s), with successful Wasm dry run;
  not a Wasm runtime test. Prior optional Chrome-runner stall remains historical
  and unperformed, not a claimed pass.
- Compiled browser: completed SCR-001 intake, all required SCR-002 checks,
  SCR-003 reasoned dismissal/manual approval, SCR-004 failed simulation (stayed
  on report), successful retry -> SCR-005. Checked actual customer/vehicle,
  revision 28, recipient/method and fixed completion timestamp. Staff expansion
  showed the genuine failed/successful attempts, internal note and audit events.
- Browser reopening: cancel retained the same revision/time; empty submission
  required reason and confirmation. Confirmed reopen retained identity/evidence/
  notes and reset all four approvals. Fresh review/send produced revision 33
  under the same ID. Widget/model tests verify old immutable snapshot retention,
  duplicate protection and ordinary Back safeguards.
- Browser START NEW INSPECTION returned a blank SCR-001 with a different ID and
  the same technician/store. Repository tests verify the old record remains
  available and repeated requests create only one new session.
- Browser completion layouts checked at 360×800 and 1440×1000, including phone
  summary/actions. No visible overflow or logged runtime errors. Widget tests
  also checked both widths with staff details expanded. Viewport override reset.
- `git diff --check`: passed. SCR-005 remains uncommitted; only SCR-004 was pushed.

Updated local preview: `http://127.0.0.1:8765/?completion-preview=20260909`.
The separate tested tab is now at fresh SCR-001 after testing START NEW INSPECTION;
its prior completed record remains in its in-memory repository. Earlier tabs were
preserved and still run older code. New tabs start independent demo sessions.
For an independent development preview: `flutter run -d chrome --no-pub`.

Manual checks:
1. On SCR-004, simulate failure and confirm it stays there. Disable failure,
   confirm both review boxes and send again; SCR-005 should show the exact
   recipient and honest simulated delivery/video/hosting status.
2. On SCR-005, cancel REOPEN INSPECTION, then reopen with a reason and explicit
   confirmation. Review retained evidence, complete fresh manual approvals and
   send again; inspect staff attempt history for both revisions.
3. START NEW INSPECTION should show a new ID with blank customer/vehicle and
   no old notes or approval state. Back must not expose the previous completion.

## Local inspection persistence — September 9, 2026 (current)

User acceptance on September 10: refresh/reopen retention, completed-inspection
reopening safeguards, and concurrent-edit conflicts all passed manual checks.
Storage behavior is approved. Checkpoint validation repeated September 10:
analyzer clean (6.4s), all 81 tests passed (10s), web build passed (37.7s).

### Approved SCR-005 checkpoint

Committed as `4b30b41` (`Add approved demo completion and explicit inspection
reopening`) and successfully pushed to the existing origin on
`codex/demo-foundation-repairs`. Before the checkpoint, analyzer passed with no
issues (6.8s), all 68 tests passed (8s), and web build passed (35.6s). No merge,
force push, remote change, generated output or runtime records were included.
The new persistence work described below remains uncommitted for user review.

### What is implemented

- Real browser-local IndexedDB, accessed through an isolated `InspectionStore`
  adapter and the existing shared-session repository boundary. Database
  `project_verify_local_v1`, object store `inspections`, database/schema version 1.
  Each inspection is one structured aggregate keyed by its unique ID, with an
  independent storage version. History is not a single preference value.
- Full session serialization: identity/revision/timestamps, technician/location,
  intake and demo provenance, workflow/checks, all simulated capture metadata,
  AI observations, decisions/reasons/corrections/rechecks, authored internal and
  customer notes, revision-bound approvals, immutable snapshots, delivery attempts
  with their actual selected recipients, completion history and audit events.
- Autosave with a 300ms debounce and serialized writes. Navigation, manual approval,
  simulated delivery/completion, reopening and starting another session flush
  required edits before proceeding. A complete aggregate is committed in one
  transaction. Saving/Saved/Failed status reflects actual datastore confirmation;
  failure retains the last committed record and current unsaved edits. Retry
  controls do not pretend a failed completion save succeeded.
- Atomic compare-and-write rejects a stale storage version. A conflicting tab
  becomes read-only and explains that its unsaved edits remain only in that tab.
  Keep it open and open the same address in another tab to review the latest saved
  record. No automatic merge, overwrite or blanket override is provided.
- Startup loads before creating anything. The minimal Saved Inspections chooser
  supports RESUME, VIEW completed records, and START NEW INSPECTION. Completed
  records retain the existing read-only/reason-required reopening behavior.
- Restoration validates structure, ownership, demo provenance, snapshot privacy,
  revision/audit-bound approvals, minimum clip duration and dipstick order.
  Interrupted or unaccepted captures require retry; interrupted delivery becomes
  stale and cannot resend itself. Recipient/preview confirmations require fresh
  review after reload. Inconsistent completed records are not shown as completed.
- Unavailable storage shows a retry explanation, without a web memory fallback.
  Failed writes show retry required. Malformed/unknown-schema records are retained
  untouched with recovery messages; valid records can still be opened. Version 1
  initializes only missing stores; no destructive migrations/reset exist. Future
  schema migrations must be explicit and preserve the source data.
- Internal notes, audit history and raw AI observations stay outside the
  allow-listed customer projection after restoration. Sample facts remain sample;
  `verifiedFacts` stays empty. No runtime records or databases are written to Git.

### Dependency and compatibility

Added the specifically authorized persistence dependency
[`idb_shim` 2.9.8](https://pub.dev/packages/idb_shim), pinned, BSD 2-Clause.
Its IndexedDB API supplies the browser adapter and a memory implementation used
only by deterministic adapter tests. Its Dart requirement (3.12+) is compatible
with the installed Dart 3.13.2 / Flutter 3.47.2 SDK. The lockfile adds its required
transitives `sembast` 3.8.9+1, `synchronized` 3.4.1+2 and `web` 1.1.1; unrelated
locked versions and global software were not upgraded. Browser-specific imports
are conditionally isolated, so a native adapter can be added later. Non-web demo
execution still uses memory; native persistence is not implemented.

### Validation and browser evidence

- Changed Dart files formatted with the installed SDK.
- `flutter analyze --no-pub`: passed, no issues (4.9s).
- `flutter test --no-pub`: **81 tests passed** (11s).
- `flutter build web --no-pub`: passed (42.3s), output `build/web`. Wasm dry
  run succeeded; no Wasm runtime test is claimed.
- `node --check tools/serve-local.cjs` and `git diff --check`: passed.

The existing 68 tests are retained unchanged. `test/local_storage_test.dart` adds
13 unit/widget tests covering complete round trips and reopened snapshots,
privacy/provenance, missing/short/wrong-order evidence, unresolved/stale approval,
top filters and superseded attempts, interrupted capture/review/delivery,
separate records, atomic version conflicts, write failure/retry/latest-edit
serialization, corruption retention, failed prerequisite/completion saves, honest
save status, chooser layouts and read-only conflict feedback at 360×800 and
1440×1000. The adapter's memory-backed test is not counted as browser persistence.

Real IndexedDB was exercised through the compiled app in the embedded browser
at exactly `http://127.0.0.1:8765/`: created a fictional inspection, waited for
Saved, reloaded during a simulated recording, resumed the same ID/intake with the
interrupted attempt requiring retry and no running timer. Continued all required
checks, added distinct internal/customer notes and a further-inspection reason,
waited for Saved and reloaded again. The same customer, vehicle, capture metadata,
authored notes, timestamp and blocking decision were restored on SCR-003; approval
remained unchecked/blocked. Restored note contents were checked visually.

**Unperformed browser checks:** tab close/reopen, normal-browser restart,
browser two-tab conflict interaction, and final browser completion-restoration
and phone-layout checks. The embedded browser was initially usable, but after
reconnecting its tool failed repeatedly with `failed to write kernel assets:
The system cannot find the path specified. (os error 3)`. Native browser automation
also failed with that runtime error; Chrome was not connected (`Browser is not
available: chrome`). Therefore no normal-profile retention or browser-restart
pass is claimed. The embedded profile may differ from a normal retained profile.
Automated completion/conflict/phone-layout coverage is separate from these missing
browser checks. A normal-profile manual acceptance pass is still required.

### Stable local launch and retention checks

Use PowerShell in `C:\Users\Armand\verify-app`:

```powershell
& 'C:\src\flutter_windows_3.47.2-stable\flutter\bin\flutter.bat' build web --no-pub
node tools/serve-local.cjs
```

Open **http://127.0.0.1:8765/** in a normal, non-private Chrome or Edge profile.
The currently running loopback helper already serves that address and updated
`build/web` files. Reuse it if present; the checked-in launcher reports an occupied
port instead of switching ports. To relaunch, stop your existing helper first.
This is a local preview, not a deployment. `localhost`, another port, another
browser/profile and embedded previews each have separate storage. A changing
`flutter run` development port is unsuitable for this retention test.

1. Create a fictional demo, enter both note types and a further-inspection reason.
   Wait for Saved, reload, then close/reopen the tab and normal browser at the exact
   address/profile. RESUME must retain data and keep the concern blocking.
2. Complete the simulated workflow, wait for Saved, reload and VIEW its read-only
   completion. Reopen with a reason: old snapshots/attempts/notes should remain,
   with fresh approvals required. Start a new inspection; both IDs must remain.
3. Open the same saved inspection in two tabs before editing. Save a note in one,
   then edit the other. The second must show a conflict, preserve its unsaved text
   in that tab and never overwrite the first tab's saved record.

### Limits and future work

Files added: `lib/models/inspection_session_codec.dart`,
`lib/services/inspection_store.dart`, `indexed_db_inspection_store.dart`,
`local_inspection_repository.dart`, `browser_store.dart`, `browser_store_web.dart`,
`browser_store_stub.dart` (all under `lib/services`),
`lib/screens/saved_inspections_screen.dart`,
`lib/widgets/session_save_boundary.dart`, `test/local_storage_test.dart`,
and `tools/serve-local.cjs`. Modified: app startup, shared session, the five
existing screens, session banner, dependency manifest/lockfile, AGENTS and this
status document. Existing tests were not deleted or modified.

Local storage is not cloud backup or cross-device sync. Clearing site/browser
data, browser eviction or losing a profile can remove records. Private/temporary
profiles are unsuitable for retention tests. Wait for Saved before closing;
unsaved/conflicting edits exist only in the open tab. Recovery currently preserves
damaged data and reports the problem; no repair/export/merge utility is built.

Only fictional demo data is appropriate. Staff authentication, production
encryption and key management, access controls and cloud backups remain required
before real customer use. The demo technician name is not an authenticated user.
Saving locally while offline is not a fully offline-installable application.

Camera/glasses, actual media files or durable video archiving, AI, specifications,
provider lookups, Square, SMS/email, secure report links and cloud hosting remain
mocked or unavailable. Completion is simulated, never real service approval.
No SCR-006, production services, live sends, deployment or persistence commit.

## Real local media — September 10, 2026 (current)

### Approved storage checkpoint

Storage checkpoint **23a36ed** (`Add approved browser-local inspection persistence`)
was committed and successfully pushed to the existing origin/feature branch
`codex/demo-foundation-repairs`. Checkpoint validation: analyzer clean (6.4s),
81 tests passed (10s), web build passed (37.7s). User confirmed all three storage
manual checks passed. No merge, force push, remote changes or generated/runtime
data in that commit. All media work below remains uncommitted for review.

### Implemented capture, storage and playback

- Separate real-camera buttons in the existing guided steps; explicit simulation
  remains available. A dialog provides preview, optional microphone narration,
  explicit ENABLE CAMERA permission action, TAKE ACTUAL PHOTO or START ACTUAL VIDEO,
  and STOP AND VALIDATE CLIP. No device access on app startup, automatic recording,
  upload, or fallback to an unlabeled simulation. Errors explain denied permission,
  missing/busy devices, unsupported format, interruption and decode failure.
- Browser getUserMedia/MediaRecorder adapter behind CameraService; independent
  RealCaptureController serializes operations, rejects stale callbacks and releases
  devices on cancel/disposal. Browser visibility/page-exit handlers stop capture
  when hidden. An unanswered permission request never becomes consent; late streams
  are stopped after cancellation. Preview indicates camera/microphone activity.
- JPEG photos and browser-supported WebM/MP4 recording. A finalized video is decoded
  through its media timeline to the ended event before duration is accepted; the
  UI timer and MediaRecorder timeslice interval are not used as duration evidence.
  Infinite/unavailable container duration is resolved from the playable media
  timeline; unknown, empty or unplayable output fails. Drain and either filter
  require at least 5000ms. Validation is muted and bounded by a timeout.
- Save before Keep, actual photo/video review, and explicit Keep/Record Again.
  Nothing automatically accepts an inspection check. Drain precedes the under-car
  filter; adaptive filter location remains; dipstick capture/reinsertion precedes
  caps. A capture proves a file was captured, not safe service or correct oil level.
- IndexedDB database version 2 adds a `media` object store without deleting or
  replacing the existing `inspections` store. Domain schema 2 reads schema 1 records
  non-destructively. Media bytes and the associated aggregate are written in one
  atomic transaction with the existing expected-version guard. Immutable media keys
  include inspection and attempt IDs; new files never replace an earlier file.
- Metadata includes inspection/attempt/step/stage, report revision, technician/time,
  source, actual MIME format, measured duration, byte count and corruption checksum.
  Attempt status remains in the session aggregate. The checksum detects accidental
  corruption; it is not a cryptographic signature or authenticity guarantee.
- Save failure retains pending bytes in the open session and the last committed
  database state. Keep is disabled until media commit succeeds. Retakes preserve
  old files and attempt history. Required checks cannot recover as complete with
  missing/corrupt media. Metadata-only simulated captures remain distinctly labeled.
- SCR-003 groups actual accepted media by under-vehicle/under-hood stage and offers
  a separate staff-only earlier/rejected section. SCR-004 and completed SCR-005 use
  immutable accepted media references from their report snapshot. Internal notes,
  raw AI and rejected/superseded captures never enter a new customer projection.
  Reopening/replacing evidence leaves earlier report references unchanged.
- Playback reconstructs temporary URLs from saved bytes and revokes them on disposal;
  URLs are not the stored evidence. Native video controls appear only after the file
  can play. Missing/corrupt/unsupported files show an explanation. Saving, save
  failure, and saved-local states remain distinct. Old open tabs blocking migration
  produce a save/close/retry message; never clear site data to fix that condition.

### Dependencies and sources

No new package version was downloaded for media. Existing `web` **1.1.1** was
promoted from transitive to pinned direct dependency (BSD 3-Clause, Dart project).
Existing `idb_shim` **2.9.8** remains the binary IndexedDB adapter dependency.
No unrelated version or global software upgrades. Browser APIs live in
`web/local_media.js` and conditional Dart adapters; native/glasses adapters remain
future work. Native Flutter builds do not have this camera/playback implementation.

Implementation references: [Dart package:web](https://dart.dev/interop/js-interop/package-web),
[Flutter HtmlElementView](https://api.flutter.dev/flutter/widgets/HtmlElementView-class.html),
[getUserMedia permissions/errors](https://developer.mozilla.org/en-US/docs/Web/API/MediaDevices/getUserMedia),
[MediaRecorder final data](https://developer.mozilla.org/en-US/docs/Web/API/MediaRecorder/dataavailable_event),
and [media duration semantics](https://developer.mozilla.org/en-US/docs/Web/API/HTMLMediaElement/duration).

### Validation

- Changed Dart files formatted; JavaScript syntax checks passed.
- `flutter analyze --no-pub`: passed, no issues (6.3s).
- `flutter test --no-pub`: **100 passed, 1 explicitly skipped** (11s). The skip
  is the new browser-only adapter test on the default VM platform; see separate
  Chrome validation and the optional test-runner stall below.
- `flutter build web --no-pub`: passed (43.0s), output `build/web`. Wasm dry run
  succeeded; no Wasm runtime test is claimed.

- Nineteen new deterministic unit/widget tests in `test/real_media_test.dart` cover
  bytes and ownership, no inspection mixing, cross-runtime checksum stability,
  4999/5000ms rules for all three drain/filter variants, invalid recordings, save
  failures, retakes and snapshots, missing/corrupt files, migration/atomic conflict,
  device errors, overlapping/stale operations, unanswered permissions, and actual
  dialog button interactions at 360×800 and 1440×1000. Contract fixture byte arrays
  do not pretend to be physical or browser-decoded recordings.
- Existing tests retained. Two filter test setups now complete the newly enforced
  preceding drain step; their minimum-duration/relocation assertions remain intact.
  Completion's empty-video text assertion now accurately says no real recording was
  included, since capture is now available. No tests or assertions were weakened.
- Browser **synthetic canvas**: actual JPEG and video encoding through the production
  browser adapter, finalized duration validation, native playback readiness, byte
  retention and decoding after document reload passed. Latest fixture clip: 5481ms,
  94363 video bytes and 2049 photo bytes. Tracks were released. This is not a
  physical-camera test.
- Browser **physical camera/microphone**, after the user's explicit permission:
  getUserMedia with audio succeeded; actual photo and video capture, final video
  decoding, local byte storage and decoding after reload passed. Clip: 5487ms,
  1801899 video bytes; photo: 78527 bytes. No upload occurred. The test requested a
  microphone track; intelligibility of spoken narration was not listened to or
  assessed by the agent and remains a user check.
- The physical and synthetic checks used a separate headless Chrome test profile,
  not the user's normal retention profile. This verifies actual hardware/browser
  media APIs, not normal-profile browser-restart acceptance. Browser restart with
  actual media in the normal profile remains a manual check.
- Compiled-Dart **actual IndexedDB adapter** fixture passed binary round trip,
  cross-inspection isolation, atomic stale-write rejection, blocked-upgrade feedback
  and non-destructive migration, in real Chrome. The memory adapter intentionally
  does not implement browser version-change events; browser lifecycle coverage is
  supplied by this actual Chrome check rather than suppressing its error in tests.
- Optional `flutter test --platform chrome test/browser_store_test.dart` stayed at
  loading and was cancelled without a result: **unperformed**. That browser-only
  test is explicitly skipped on VM. The standalone compiled-Dart Chrome adapter
  check above did complete; it is distinct from the stalled test-runner invocation.
- Embedded interactive browser automation remained unavailable (`failed to write
  kernel assets ... The system cannot find the path specified. (os error 3)`).
  Full end-to-end clicking through all five screens with physical media and normal
  browser restart was not performed. Widget tests cover UI controls and layouts;
  headless Chrome covers production browser capture/storage/playback functions.

### Local viewing and repeatable checks

The unchanged app address is **http://127.0.0.1:8765/**. Use the same normal Chrome
profile; do not alternate localhost/127.0.0.1 or ports. Save and close old tabs if
they block the new database version. The existing helper serves the updated build.
To launch again from the project directory:

```powershell
& 'C:\src\flutter_windows_3.47.2-stable\flutter\bin\flutter.bat' build web --no-pub
node tools/serve-local.cjs
```

For developer synthetic verification, copy `test/browser_media_fixture.html` to
`build/web/`, compile `tools/check_indexed_db.dart` with `dart compile js` to
`build/web/check_indexed_db.js`, then run `node tools/check-media-browser.cjs` while
the fixed local server is running. It uses only synthetic canvas media by default.
Automated physical testing is now disabled in that helper: it refuses the former
`VERIFY_PHYSICAL=authorized` mode and no longer grants browser permissions.
Use the visible app for physical testing, with user-approved browser permission,
device-name confirmation and separate preview/start actions. QA profiles, output
files and earlier test recordings remain in ignored `build/`; none were deleted.

Three manual checks:
1. USE REAL CAMERA, optionally enable narration, request permission, record at least
   six seconds, STOP AND VALIDATE, RETURN TO INSPECTION, review and KEEP REAL MEDIA.
   Also stop a drain/filter early: it must remain incomplete. Listen to narration.
2. Capture a real dipstick photo, Keep, then confirm reinsertion before caps. Wait
   for Saved, reload/reopen the normal browser, and verify photo/video playback in
   SCR-003 and accepted-only report preview; internal/rejected content stays private.
3. Complete the demo, reopen with a reason, and replace a clip. Confirm old footage
   remains staff-only, the earlier completed report keeps its original reference,
   and fresh manual approvals are required. Do not clear browser/site data.

### Remaining limits and changed files

Service data, specifications, AI, Square and delivery remain mocked/unavailable.
No AI image interpretation, smart-glasses control, combined/merged customer video,
secure hosted report, real messaging, cloud backup or production verification.
Local browser storage can be cleared/evicted and is not backup or evidence-grade
archiving. No automatic footage deletion/retention policy or quota management UI.
Large recordings require memory during finalization/loading; use short targeted
segments. Failed/unsaved bytes can be lost if the tab is closed before retry.
Authentication, access controls, encryption/key management, secure backup and
production evidence policy remain necessary before real customer use.

Added: local-media model; camera interface/browser adapters/controller; media-store
interface; real-capture dialog, media player and evidence-gallery widgets;
`web/local_media.js`; media/adapter/fixture tests and developer Chrome test tools.
Modified: session/codec, IndexedDB/repository/browser-store adapters, guided/review/
report/completion and saved chooser screens, session banner, web bootstrap,
dependency manifest/lockfile, two existing test files, AGENTS and this document.
No additional product screen, deployment, live integration or media commit.

### Device clarification and next physical test — September 10

**Ray-Ban Meta glasses:** one pair is the intended primary recording device.
This build does not connect to or claim support for Ray-Ban Meta. Glasses testing
is **unperformed**. Exact model/generation, paired phone/OS, SDK compatibility,
camera/microphone access, recording control, media transfer and other required
capabilities need verification. No SDK compatibility assumption or integration
has been added. CameraService isolates browser capture from reusable inspection,
storage, retake, revision and review logic for a future compatible adapter.

**Computer-camera development/fallback testing:** the earlier physical test above
was a computer-device test only, not a glasses test. Its results do not establish
glasses compatibility. A read-only Windows device inventory now lists I940 and
Microphone (I940); these are proposed test devices, not proof of Chrome's current
selection. Chrome also has other audio endpoints, so its selected microphone must
be confirmed rather than assumed. No devices were activated for that inventory.

Before another physical test, identify the camera/microphone, allow time to aim at
a non-sensitive object and ensure no private conversation is present. The user
must approve the browser permission themselves. The preview now shows the actual
stream device labels after permission and before the separate capture action.
If the names are unavailable or different from the proposed devices, cancel and
confirm Chrome settings before recording. No automatic permission grant, upload,
AI transfer or background recording is permitted. Close/cancel stops both devices.

The requested new prepared-scene test is **pending user readiness and browser
permission**, not counted as completed. Use a short sub-five-second drain/filter
clip to verify rejection, then a six-second clip to verify finalized duration,
save/Keep, normal-profile reopening and playback; verify microphone narration by
listening locally. Preserve earlier footage and all existing safety gates.

Clarification validation: analyzer passed with no issues (6.4s), 100 default tests
passed with the existing browser-only VM skip (11s), and web build passed (38.5s).
Synthetic Chrome regression also passed: device-name feedback appears before
capture, microphone-off status is explicit, the Ray-Ban Meta limitation is shown,
and a 5480ms fixture clip saved/reloaded/decoded successfully. Actual IndexedDB
adapter/migration checks passed again. No physical camera or microphone was
activated during this clarification work. No glasses testing was performed.

### Audio and explicit acceptance diagnosis — September 14, 2026

Physical computer test (user report): actual video recorded and played after
reload. Audible narration FAILED/UNCONFIRMED: the user heard no sound. This is
not a completed physical media test. Ray-Ban Meta testing remains unperformed.

Established by code inspection: Include microphone narration defaults OFF.
When enabled, getUserMedia requests audio along with video; permission errors
are surfaced without a camera-only fallback. Device labels appear after the
explicit permission action. The recorder receives that stream. Preview and
validation playback are intentionally muted; the separate recorded player was
not explicitly muted or set to zero volume. The earlier clip has no persisted
narration-request, device, track or audibility diagnostics. Its actual setting,
permission grant, selected microphone and encoded audio remain UNKNOWN. Track
presence alone cannot establish audible narration. Browser tooling exposed no
normal Chrome tabs, so the user's existing recording could not be examined.

Focused corrections: requested narration now requires a live, enabled, unmuted
audio track at open/start/stop, with actionable Chrome permission/input guidance
on failure; audio-requested recording excludes the explicit video-only codec
fallback. Recorded playback explicitly starts unmuted at volume 1, provides a
Sound On/Off button plus native controls, and asks the listener to confirm audio.
This does not measure audibility or claim that narration was recorded.

Saving was already separate from acceptance. Keep/Record Again were on the
Guided Inspection screen behind Return to Inspection. The capture dialog now
also presents saved-awaiting-review status, playback and explicit KEEP —
RECORDING IS SUFFICIENT / RECORD AGAIN controls after a successful save. Restored
review attempts retain those controls on Guided Inspection. Accepted clips have
an expandable PLAY ACCEPTED LOCAL RECORDING section on their inspection step.
Rejected short attempts remain blocking/staff-only; retakes retain superseded
metadata/files and audit history. No schema change, storage reset, file deletion,
new dependency, upload, physical device access, commit or push was performed.

Validation: flutter analyze passed (no issues); flutter test passed 101 tests
with one existing browser-only VM skip; flutter build web passed (40.5s).
Regression widget tests exercise narration opt-in and explicit dialog Keep at
360px/1440px, plus saved-awaiting-review restoration, manual acceptance, retained
bytes/audit and accepted status after another reload. Synthetic Chrome checks
passed missing requested audio rejection, playback mute/unmute controls, and
local retention/reload of a 5472ms / 111980-byte generated clip. Actual IndexedDB
adapter/migration synthetic checks passed. These are NOT physical audio results.

Next user test: reload http://127.0.0.1:8765/ in the same normal Chrome profile,
resume the inspection, use real camera/video, enable microphone narration BEFORE
requesting permission, approve Chrome's permission and confirm displayed device
names. Proposed computer fallback devices remain I940 and Microphone (I940),
not verified current Chrome selections. Prepare a non-sensitive scene, explicitly
Start Actual Video, say "Project Verify microphone test", and stop after eight
seconds. Wait for Saved locally, awaiting review; play with Sound On and confirm
picture/audio, then explicitly Keep. Wait for the session save indicator before
reloading. Resume and expand Play Accepted Local Recording to listen again.
Physical audio stays PENDING until the user confirms it is audible after reload.

### Independent microphone selection and measured input — September 14, 2026

Confirmed defect in diagnostic/control coverage: capture used audio:true, leaving
microphone selection to Chrome's default. There was no independent input selector
or measured signal display. This does NOT establish that the prior physical
recording used I940, that the intended microphone was defective, or where its
sound was lost. Actual previous microphone, permission state, input level,
encoded audio, tab mute and output device remain unknown. Normal Chrome was not
exposed to browser automation (only the Codex in-app browser was available).

The browser adapter now enumerates microphones after explicit permission, offers
Refresh Microphones and Use Selected Microphone, requests the chosen current ID
with audio.deviceId.exact and video:false, and replaces only the old audio track.
The actual returned track label is shown. No hardcoded names/IDs, no fallback on
selection errors. Failed selection retains and identifies the old actual input.
Switching is locked during recording; pending switches are ignored/released after
exit. Existing camera service boundary, storage schema, files and audit remain.

Start / Resume Microphone Meter is a separate explicit user button. It resumes
AudioContext and measures RMS samples from the same track included in the
recorder stream; no connection to speaker output is made. It shows actual input,
track readyState, enabled/muted state, analyzer state, numeric RMS and sound
activity. An inactive analyzer is distinguished from no detected activity.
Activity threshold is diagnostic (RMS > 0.001), not speech recognition or proof
of audible narration. Meter/context stop on release, device switch and exit.
The preview stays muted; that does not change audio-track enabled state.

Recorder review: exact current stream is passed to MediaRecorder, with live audio
checks; formats use isTypeSupported. Final dataavailable chunks are assembled
after the stop event and before device release. This matches current recording
API ordering. No confirmed recorder/storage defect was found. Existing stored
media is loaded with its original MIME type and checksum-checked bytes; recorded
player is unmuted/volume 1 by default with user sound controls. Physical file and
OS/tab output diagnosis still requires observable results in the normal profile.

Validation: analyzer passed (6.7s); default Flutter tests 101 passed, one existing
browser-only skip; web build passed (41.4s). New isolated synthetic browser tests
passed: exact independent device ID, actual returned label, stopped old track,
inactive-before-click analyzer, measured nonzero samples, same meter/recorder
track, recording-time selection lock, nonzero decoded audio in finalized bytes,
identical stored bytes/MIME and decoded stored audio, track release, plus existing
media/save/reload checks (5466ms video). A first 250ms fixture produced an empty
clip; extending the fixture to 1500ms passed all unchanged audio assertions.
These tests establish diagnostic wiring only, NOT physical microphone success.

Modified this batch: web/local_media.js, test/browser_media_fixture.html and this
document. No physical activation, upload, AI transfer, browser data reset, commit
or push. No changes to minimum duration, Keep/retry, privacy or approval rules.

Next physical checkpoint is ONLY microphone selection and live meter response,
through the user's permission and explicit testing click. Do not request another
full recording until the user reports the meter responds to their voice. Physical
audio remains PENDING until audible saved narration is confirmed after reload.

Browser references consulted:
- https://developer.mozilla.org/en-US/docs/Web/API/MediaDevices/getUserMedia
- https://developer.mozilla.org/en-US/docs/Web/API/MediaDevices/enumerateDevices
- https://www.w3.org/TR/webaudio/
- https://www.w3.org/TR/mediastream-recording/

### Glasses-native hardware result and iPhone prerequisites — September 15, 2026

PASSED (user-reported): Ray-Ban Meta glasses recorded video with audible
narration; the user imported and played it on the paired iPhone. This is a
GLASSES-NATIVE recording/playback test, not Project Verify integration.
Project Verify glasses connection, capture/control, narration and native iPhone
storage/playback remain UNIMPLEMENTED/UNTESTED. Manual import is not the final
product design. Computer-camera audio remains UNRESOLVED; further physical webcam
testing is PAUSED by user request. These statements supersede prior next-webcam-
test instructions and the earlier statement that all glasses testing was unperformed.

Read-only project inspection and current official Meta/Apple/Flutter research are
recorded in [GLASSES_IOS_PREREQUISITES.md](GLASSES_IOS_PREREQUISITES.md), including
source links, capability distinctions, version blockers and the smallest real
connection test. DAT 0.9.0 requires iOS 17.2+; the current Meta sample lists Xcode
26.4+/Swift 6.3+. This project's native target is iOS 15.0 and its native camera,
store and player remain stubs. No dependency/platform change was made.

Main integration risk: video frames and microphone narration use different
paths. The official sample does not guarantee glasses microphone selection;
actual HFP input routing and measured samples must be checked. Simultaneous
video/audio/photo reliability and usable quality remain physical-test questions.
Exact glasses generation, firmware, Meta AI version, iPhone/iOS, Mac/toolchain
access and signing/Meta developer access are missing. The official firmware/app
compatibility matrix was login-gated; no numeric firmware/app minimum is asserted.

Changed only documentation: AGENTS.md, this file and the new prerequisites note.
No installed tools, accounts, SDK code, dependency edits, footage transfer, device
activation, commits or pushes. Existing source changes, browser records and files
were preserved. Flutter analyze/test/build were not rerun for this documentation-
only assessment; previous validation results remain historical, not an iOS build.

### Windows-only development / hosted iOS build route — September 15, 2026

User has no Mac access. Assessed Codemagic hosted macOS + TestFlight while keeping
Windows development and the paired iPhone. Details/citations/costs are appended
to GLASSES_IOS_PREREQUISITES.md. A personal Mac purchase is not required by this
route. Codemagic lists a compatible Xcode 26.4.1 image and a personal allowance
of 500 M2 minutes/month; paid M2 overage is $0.095/min when billing is enabled.
TestFlight requires paid Apple Developer membership (normally USD $99/year),
proper distribution signing and App Store Connect, not a free Personal Team.
TestFlight does not require iPhone Developer Mode/USB Mac pairing; Meta glasses
Developer Mode and release-channel authorization are independent.

No unsigned compile, signed TestFlight build or physical Project Verify glasses
test has run. These are three separate checkpoints. Native media/store/player
adapters remain absent. Exact device/app versions and Meta eligibility are still
unknown; the official compatibility matrix requires login. Do not buy membership
or enable cloud billing before those checks. Next single action is iPhone Settings
> General > About to obtain Model Name and iOS Version. No serial/IMEI needed.

Glasses-native audio/video playback remains user-reported passed; Project Verify
integration unimplemented; webcam audio unresolved and physical webcam testing
paused. Documentation only; no tests/builds rerun, code/dependencies changed,
accounts created, source/media uploaded, SDKs installed, commits or pushes.

### Authorized browser checkpoint before native work — September 15, 2026

User authorized committing/pushing this browser-media checkpoint on the existing
repair branch, then creating codex/ios-meta-integration. Browser video, local
save/reload and the five-screen workflow passed user manual tests. Webcam audio
is still UNRESOLVED and physical webcam testing PAUSED. New microphone selection
and meter diagnostics passed synthetic tests, not physical narration validation.
Fresh Windows validation: analyzer clean (7.5s), 101 tests passed / one existing
browser-only skip (12s), web build passed (40.9s). No real recordings are included
in git; browser storage and ignored build/test profiles remain local.

User supplied: iPhone 15 Plus / iOS 26.6.2; Ray-Ban Meta Wayfarer 00MJ;
glasses release 128.0.0.203.324; Meta AI 289.0.0.21.157; Developer Mode ON;
DAT app installed on glasses, displaying SDK 0.9.0.26.0. Native glasses recording
with audio works per user. These are user-reported versions, not proof of DAT
compatibility or Project Verify integration. Codemagic is connected to GitHub.
Next work is an unsigned iOS connection-test compile; no signing, billing,
TestFlight publishing, external AI or physical capture is authorized here.
