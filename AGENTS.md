# Project Verify

- Preserve this existing Flutter app and its approved screen arrangement. Pilot: Chalmette, never Gulfport.
- Begin with one pair of glasses. Glasses-first is the intended interface; screen controls are the prototype/fallback.
- Capture targeted final-verification clips, not the entire oil change. Drain-plug and oil-filter clips require at least five seconds, including top-mounted filters.
- Under vehicle: drain plug, oil filter if accessible there, differential/axle area, engine underside, residual-oil cleanup confirmation.
- Under hood: top-mounted filter if applicable, oil-level/dipstick capture, separate dipstick reinsertion, cap/component touch sequence, engine-bay sweep, tire-pressure confirmation, oil-change-reminder reset. Never move dipstick capture after the touch sequence.
- Tire pressure is a technician statement, not an AI-verified measurement. AI observations are advisory, not verified service facts. Unresolved critical problems block approval.
- All employees may add notes; internal notes and customer-visible recommendations must remain separate.
- Future oil provider: AMSOIL. Future filter provider: ShowMeTheParts restricted to Service Champ. Never invent specifications or part numbers.
- Square remains the POS; integration is not implemented. Future customer report: simple page, one main video button, secure link, no customer account.
- Never claim camera, glasses, AI, storage, Square, or delivery are live when mocked. Explicit demo completion must remain separate from real inspection approval.
- Prefer existing dependencies. The current persistence assignment authorizes the minimum maintained open-source persistence dependency; idb_shim is selected. Ask before unrelated additions. Do not install/upgrade global tools or delete/reset unrelated work. Commit/push only explicitly approved checkpoints.
- Current scope: real browser-local IndexedDB storage preserving SCR-001 through SCR-005. Leave persistence changes uncommitted for review. No SCR-006, live delivery or cloud integrations.
- Save whole session aggregates atomically, await confirmed writes at navigation/completion boundaries, and reject concurrent stale writes. Never reset damaged/unsupported records or claim memory fallback is persistent. Demo media remains metadata only.
- Stable test origin: http://127.0.0.1:8765/ in the same normal browser profile. Local storage is not backup/sync; clearing site data may remove it. Use fictional data only. Staff authentication, production encryption/key management, access controls and backup remain future work. Keep BUILD_STATUS current; format, analyze, test and build web.
