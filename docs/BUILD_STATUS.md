# Project Verify — foundation repairs

Current status is summarized in the local persistence section at the end. Earlier
sections are historical checkpoints, including their former memory-only limits.

Scope: SCR-001 intake, SCR-002 guided inspection, SCR-003 advisory review,
SCR-004 demo customer preview and simulated delivery, SCR-005 demo completion.
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
