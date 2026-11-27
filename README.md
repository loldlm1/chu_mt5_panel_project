# Chu Sniper Manager (MQL5)

Expert Advisor for MetaTrader 5. The source-of-truth entry point is `Experts/Chu_Sniper_Manager.mq5`.

## Baseline

The initial `main` commit imports original v0.12 logic from the supplied UTF-16 LE source, as GitHub-readable UTF-8 with the original characters/behavior preserved.

## Current version — v0.17.0

See [CHANGELOG.md](CHANGELOG.md) for the history of accepted updates and versioning conventions. The EA metadata is `#property version "0.170"`; the project version is v0.17.0. Track new work in [GitHub Issues](https://github.com/loldlm1/chu_mt5_panel_project/issues).

## Build (MetaEditor)

Place the `Experts/` tree under the MetaTrader 5 data folder's `MQL5/Experts/`, keeping the relative header paths unchanged. Open `Chu_Sniper_Manager.mq5` in MetaEditor and press **F7**.

The equivalent command-line call in a configured Windows/MetaEditor environment is:

```text
MetaEditor64.exe /compile:"<full path>/Chu_Sniper_Manager.mq5" /log
```

Review the resulting compiler log. Only a real compiler invocation with 0 errors qualifies as compile-pass evidence. Use a demo hedging account or MT5 Strategy Tester for runtime checks; no live trading.

## Workflow

The project reads `AGENTS.md`, `docs/agents/` and `GLOSSARY.md`. Matt Pocock's workflow in Codex CLI is the native reference; GitHub-only sessions may reproduce its issue/PR convention but cannot claim to run Codex CLI skills or delegates.

## Panel preferences

`PanelTheme` selects the original or Pandora panel palette. Chart style always follows Pandora. Drag the header or resize corner; minimize to quick market buttons. Per-chart state is stored in the terminal's MQL5 Files sandbox and keyed by a hidden chart-profile identity, account, symbol and magic. Keep the chart/profile to restore state; deleting it or the state file starts fresh. Tester runs do not restore saved state. Quick BUY/SELL uses configured SL points, R:B and current risk; it does not send the prepared manual order. Demo and Real hedging are supported; netting and contest accounts are view-only. Fresh panels default to 1% of balance per new entry, and existing preferences are restored. Grupo imposes no artificial group risk or position ceiling; broker volume and margin limits still apply.

## Broker protection

At preparation/edit and explicit confirmation, new entry levels are validated against current Bid/Ask, stops level and tick size. A changed manual projection requires confirmation again; quick market entries adapt automatically and send once, after OrderCheck. Money/percent sizing is recalculated using the effective stop. Fixed lots are preserved or rejected. Existing pending modifications and BE/trailing respect freeze constraints; automatic adaptations never weaken existing protection. No unprotected fallback from a positive SL or automatic order retry. Explicit SL=0 is an intentional exception to protected entry, not a risk-limited order. Actual fills and losses can differ from estimates; accepted requests are not proof of a fill. All development/QA remains Demo/Tester only.

## Interactive BE preview

Break-even displays an estimated closing level for the selected side/scope. Drag the BE line freely and inspect the projected net P/L, balance percentage and retracement while moving it. Releasing or canceling a drag does not apply any BE-related broker modification. Only a separate deliberate click on `Aplicar BE` applies the current projection through the existing per-ticket broker-aware BE logic. The estimate is not a realized result or a guarantee that every position can accept the level. Automatic trailing, when enabled, continues independently and may change actual stops during preview. Demo and Real hedging compatibility is a continuing requirement; development verification remains Demo/Tester only.

On BE activation, a sole eligible direction is selected automatically; if both BUY and SELL are open, use the selected side. A prepared order keeps its own direction and prices; the BE side is labeled and persisted separately. CSM140 and CSM160 state is read and upgraded to CSM170 on save. At explicit Apply, each position requires its fresh executable quote to have strictly crossed the requested BE (Bid > BE for BUY, Ask < BE for SELL). Otherwise no stop modification is sent. After crossing, exact or existing broker-aware improving adaptation is allowed; frozen/rejected/no-improvement tickets retain their protection. No deferred execution. Automatic trailing does not use this crossing requirement.

## v0.17.0 — Drafts, independent TP, and initial-risk trailing

- **Draft controls:** click Comprar/Vender to prepare, click the same active button again to cancel only the draft. The selected side remains marked (*); an active draft shows X. Quick entries leave the draft untouched. Broker orders are never canceled by this toggle.
- **Management TP:** Activate TP independently of BE and the entry draft. The initial line starts at the scoped estimated BE, independent of existing targets. Drag either chart line or its own fixed summary row (also disambiguates coincident lines). Only `Aplicar TP` modifies executed positions' TP; it preserves each SL. Pending orders are untouched. Individual requires positive projected net P/L; Grupo requires a positive aggregate including individual losses and zeros. The projection includes all scoped positions and known costs, not just executable tickets. Before each send, revalidate the profitable executable subset and verified targets. Targets already reached are rejected; a still-ahead but too-close target may be adapted outward. Frozen, rejected or uncertain positions may cause partial application. Panel reports coverage/frozen/other counts, Experts log gives details; there is no atomic guarantee, rollback, automatic retry or compensating SL/close. BE remains independently available. All estimates exclude unknown future costs/slippage.
- **Trailing 1R:** Activation and distance equal the original effective opening SL gap for each position, derived from actual weighted opening fills and historical entry DEAL_SL tied to POSITION_IDENTIFIER. The terminal opening order and matching volumes are verified. Unknown/conflicting history and born-without-SL positions are skipped; never derive risk from today's SL. Partial closes and manual BE do not reset initial risk. Turning trailing off/on resets favorable quote tracking, not opening risk; restart reconstructs initial risk from history. A missing history record can disable trailing until reliable history becomes available. Existing monotonic broker-aware trailing and cooldown retained. ActivationPoints, TrailPoints and obsolete StepPoints inputs are removed; old presets cannot configure these distances.
- **Explicit no SL:** Stop (puntos)=0 means no initial SL. Fixed lot uses the specified valid lot; %/money uses broker minimum only if allowed, with no SL-based loss estimate. Quick and R:B draft entries have no initial TP; switching to manual TP creates a draggable valid target. Zero-SL pending draft starts at placement gap plus one tick. Positive stops retain protected sizing. No silent fallback. Pending edits retain optional levels only when original explicit no-SL marker (Chu Sniper NS0/NS1) confirms their intended absence; a broker that strips that marker may prevent editing such a pending order. Always inspect accepted protection verification. No-SL positions are never eligible for 1R trailing, even after adding a BE. Minimum lot is not a loss limit.
- **Persistence:** CSM170 retains independent BE/TP sides/prices, optional draft levels and existing favorable quote history. CSM140/160 readers migrate; older EA versions cannot read CSM170. No execution intent is persisted and no action on restore. Demo/Real hedging compatibility retained; development and QA Demo/Tester only.
