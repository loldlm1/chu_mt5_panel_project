# Changelog

All accepted updates are recorded here. Project versions use MAJOR.MINOR.PATCH, with one version per merged update. The MQL5 metadata encodes the minor and patch as three digits (e.g. v0.13.0 = 0.130). Intermediate QA commits are part of the same version.

## [0.14.0] — pending acceptance

Story #14, PR #21; tickets #15–#20.
- Exact Pandora chart style and independent Original/Pandora panel themes.
- Movable, resizable and compact panel with persistent visual and operational state.
- Market quick BUY/SELL using shared risk sizing and configured SL/R:B; Grupo default.
- Pending MetaEditor compilation and Demo QA.

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

