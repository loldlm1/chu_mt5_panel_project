# Changelog

All accepted updates are recorded here. Project versions use MAJOR.MINOR.PATCH, with one version per merged update. The MQL5 metadata encodes the minor and patch as three digits (e.g. v0.13.0 = 0.130). Intermediate QA commits are part of the same version.

## [0.17.0] — 2026-11-27

Story #34; PR #40; tickets #35–#39.
- Toggle manual entry drafts without changing broker orders or selected side.
- Simultaneous independently movable/applicable BE and TP projections; positive group net TP (including losing individual positions), per-ticket broker preflight, partial-result warning, preserve counterpart protection.
- Individual 1R trailing from verified original opening history, independent of later SL edits; remove fixed trailing inputs; unknown/zero opening SL excluded.
- Explicit zero-SL mode, fixed/minimum lot, no fabricated maximum risk, optional manual TP, preserved optional pending levels and verification.
- CSM170 migration from CSM140/160; removed input/preset and broker-comment limitations documented. Demo/Real hedging retained.
- QA amendment A (#41–#43): restore thick BE/TP chart overlays and live labels, nonoverlapping independent drag handles; compact TP row, read-only valid/covered counts and effective subset net P/L; broker-aware Apply states without duplicate sends. Same PR/version.
- QA footer fix: reserve space only for captions actually rendered in the panel; keep external overlays and compact fallback rows without blank gaps.
### Validation
- Owner accepted functional HEAD `8bf8f6c2ef5a50eb388ce270b8b8943bbe2825f5` on 2026-11-27 and explicitly authorized squash merge and story/ticket synchronization after the footer correction. Original PR acceptance checklist is marked complete by owner; later visual QA and readiness confirmed in chat.
- Initial integration: 32/32 focused structural checks and 59/59 translated decision scenarios across implementation revisions. QA amendment A: 29/29 structural and 23/23 translated decision scenarios, plus 7 synthetic geometry cases and 1 source assertion. Footer correction: 18/18 structural and 14/14 synthetic geometry scenarios.
- No raw MetaEditor compiler log, native RED/GREEN, independent native review, or CI check-runs supplied to this chat. Owner-reported acceptance is not independently reproduced compiler/runtime evidence. GitHub reports main unprotected, no reviews or unresolved threads, and no registered commit statuses/check-runs; detailed branch protection/rules endpoints unavailable. Owner accepted the current functional revision and authorized completion with these disclosed limitations.
- Final changelog-only closeout does not change executable code. No live-account verification, deployment or release performed.

## [0.16.0] — 2026-11-25

Story #30, PR #33; tickets #31–#32.
- Freely drag and release the BE projection without modifying broker stops; apply only through the existing Aplicar nivel button.
- Refresh estimated net closing P/L, balance percentage and retracement during dragging, using the existing UI cache and a bounded refresh.
- Keep existing broker-aware per-ticket BE application, independent trailing, pending-order behavior, saved preferences and Demo/Real hedging eligibility.
- BE selects the sole eligible side automatically (mixed sides respect selection), pins its direction independently of prepared orders, and preserves old state on migration to CSM160.
- Manual BE applies only after the executable quote strictly crosses the requested level, then retains broker-aware adaptation; otherwise preserves the existing stop. Automatic trailing unchanged.
### Validation
- Owner accepted functional HEAD `86863c14e9f07afa22ec5577195661d09c2ed99e` on 2026-11-25, marked all PR acceptance checks after reporting successful behavior and explicitly authorized squash merge and story synchronization.
- Initial revision: 23/23 focused static checks. QA amendment: 28/28 focused static checks and 24/24 deterministic scenarios using mechanically translated source functions in JavaScript with synthetic quotes/positions, not native MQL5 execution.
- No independent native reviewer, MetaEditor invocation, raw compiler log or broker verification by this chat. Owner QA is reported acceptance; development verification remains Demo/Tester only.
- Final changelog-only closeout does not alter executable code. CSM160 reads legacy CSM140 state; older versions cannot read the new state format.

## [0.15.0] — 2026-11-24

Story #22, PR #29; tickets #23–#28.
- Shared broker-aware order preparation, safe tick-grid alignment and adaptive SL/TP.
- Protected manual and quick entries with effective-stop sizing and OrderCheck; no unprotected fallback.
- Freeze-aware pending edits, per-ticket adaptive BE and monotonic trailing.
- Demo/Real hedging support, account mode in the header, fresh risk default 1% per entry, no artificial group cap.
### Validation
- Owner accepted functional HEAD `72ea954d4f9334d5f60fade6eb712089ed90e21a` on 2026-11-24, marked all PR acceptance checks and reported successful behavior in Demo and a personally conducted minimum-lot LIVE/REAL QA. The owner expressly authorized squash merge. The live test is owner-reported, not independently verified; no live trade was performed by this workflow.
- Direct source review: 39/39 static checks and 20/20 arithmetic cases using mechanically translated pure functions in JavaScript, not native MQL5 execution. No independent native agent review, MetaEditor invocation or broker test by this chat; raw compiler log not received.
- Final changelog-only closeout does not alter executable code. Broker conditions, slippage and gaps remain variable; successful QA does not guarantee all future executions.

## [0.14.0] — 2026-11-24

Story #14, PR #21; tickets #15–#20.
- Exact Pandora chart style and independent Original/Pandora panel themes.
- Movable, resizable and compact panel with persistent visual and operational state.
- Market quick BUY/SELL using shared risk sizing and configured SL/R:B; Grupo default.
- Larger quick BUY/SELL buttons (50 px base height), compact two-decimal presentation without reducing execution precision, and resize grip integrated into the status row.
- Fix stale chart object caches on timeframe changes; restore scoped visual and operational preferences.

### Validation
- Owner accepted functional HEAD `21b38179d06dc42e68ef571928e1dc1ef7e8ce9a` after reporting successful testing and checking all MetaEditor/Demo acceptance items in PR #21 on 2026-11-24. No additional bugs reported.
- Direct source review: 40/40 initial static checks and 26/26 focused amendment checks on their respective revisions. No independent native agent, MetaEditor invocation, or broker test run by this chat.
- Final changelog-only closeout does not alter executable code.

## [0.13.0] — 2026-11-24

Story [#7](https://github.com/loldlm1/chu_mt5_panel_project/issues/7), PR [#13](https://github.com/loldlm1/chu_mt5_panel_project/pull/13), tickets #8–#12.

### Added / improved
- Thick, single-click draggable order preparation levels; market orders show only SL and TP.
- Stable manual SL/TP prices and pending entry editing that preserves relative SL/TP distances.
- Broker-backed pending order modification and prevalidated Stop/Limit replacement; explicit error handling for non-atomic cancellation/recreation.
- Simple trailing per position with common activation and distance; protection never weakens automatically.
- Adjustable BE in Individual/Grupo with estimated close P/L and explicit manual SL movement in either valid direction.
- Grupo allows additional entries without a separate averaging toggle.
- Panel controls take priority over overlapping lines, with reduced redraws and UI-only fee-history caching.

### Validation
- Owner accepted functional HEAD `94091a3ac70b3bb76b97bfb2a18ac2aad32862be` following MetaEditor and Demo QA (all PR acceptance checks marked).
- The final version change is metadata/documentation only; no executable trading change.

## [0.12.0] — 2026-11-23

Historical baseline (original EA metadata `0.12`), story #1, [PR #6](https://github.com/loldlm1/chu_mt5_panel_project/pull/6).
- Modularized the original EA into six MQL5 headers without intentional trading behavior changes.
- Owner confirmed compilation and Demo startup/operation; existing Market version-format warning recorded.
- Added project conventions for Matt's workflow.

